import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/models/story_page.dart';
import 'package:kouvention/features/story/models/story_view_model.dart';
import 'package:kouvention/features/story/services/story_firestore_service.dart';

class StoryRepository {
  StoryRepository({
    required StoryFirestoreService remote,
    required MessageDatabase db,
  }) : _remote = remote,
       _db = db;

  final StoryFirestoreService _remote;
  final MessageDatabase _db;

  Stream<List<StoryModel>> watchActiveStories({
    required String currentUid,
    required DateTime now,
    int limit = 50,
  }) => _db
      .watchActiveStories(
        currentUid: currentUid,
        nowMs: now.millisecondsSinceEpoch,
        limit: limit,
      )
      .map((rows) => rows.map(StoryModel.fromDrift).toList());

  Future<List<StoryModel>> fetchStoriesByAuthor({
    required String authorUid,
    required DateTime now,
    int limit = 20,
    DateTime? beforeCreatedAt,
  }) async {
    final rows = await _db.fetchStoriesByAuthor(
      authorUid: authorUid,
      nowMs: now.millisecondsSinceEpoch,
      limit: limit,
      beforeCreatedAt: beforeCreatedAt?.millisecondsSinceEpoch,
    );

    return rows.map(StoryModel.fromDrift).toList();
  }

  Future<StoryPage> fetchFeedPage({
    required String currentUid,
    required DateTime cutoff,
    int limit = 50,
    StoryCursor? cursor,
  }) async {
    final page = await _remote.fetchFeedPage(
      currentUid: currentUid,
      cutoff: cutoff,
      limit: limit,
      cursor: cursor,
    );

    await _persistRemoteStories(page.stories);
    return page;
  }

  Stream<void> syncLatestFeed({
    required String currentUid,
    required DateTime cutoff,
    int limit = 50,
  }) async* {
    await for (final stories in _remote.streamLatestFeed(
      currentUid: currentUid,
      cutoff: cutoff,
      limit: limit,
    )) {
      await _persistRemoteStories(stories);
      yield null;
    }
  }

  Future<void> publishStory(StoryModel story) async {
    final existing = await _db.getStoryById(story.id);
    final retryCount = existing?.retryCount ?? story.retryCount;

    await _db.upsertStory(
      story.toCompanion().copyWith(
        syncStatus: const Value(StorySyncStatus.pending),
        retryCount: Value(retryCount),
      ),
    );

    try {
      await _remote.createStory(story);
      await _db.updateStorySyncStatus(
        storyId: story.id,
        status: StorySyncStatus.synced,
        retryCount: 0,
      );
    } catch (_) {
      await _db.updateStorySyncStatus(
        storyId: story.id,
        status: StorySyncStatus.failed,
        retryCount: retryCount + 1,
      );
      rethrow;
    }
  }

  Future<void> deleteStory({
    required String storyId,
    required DateTime deletedAt,
  }) async {
    await _db.markStoryDeletedLocally(
      storyId: storyId,
      deletedAt: deletedAt.millisecondsSinceEpoch,
    );

    final localStory = await _db.getStoryById(storyId);
    if (localStory == null) {
      throw StateError('Cannot delete missing local story: $storyId');
    }

    try {
      await _remote.softDeleteStory(
        story: StoryModel.fromDrift(localStory),
        deletedAt: deletedAt,
      );
      await _db.updateStorySyncStatus(
        storyId: storyId,
        status: StorySyncStatus.synced,
        retryCount: 0,
      );
    } catch (_) {
      await _db.updateStorySyncStatus(
        storyId: storyId,
        status: StorySyncStatus.failed,
        retryCount: localStory.retryCount + 1,
      );
      rethrow;
    }
  }

  Future<void> markViewed(StoryViewModel view) async {
    final existing = await _db.getStoryView(
      storyId: view.storyId,
      currentUid: view.viewerUid,
    );

    if (existing?.syncStatus == SyncStatus.sent) return;

    final pendingView = StoryViewModel(
      storyId: view.storyId,
      viewerUid: view.viewerUid,
      viewedAt: existing == null
          ? view.viewedAt
          : DateTime.fromMillisecondsSinceEpoch(existing.viewedAt),
      syncStatus: SyncStatus.pending,
      retryCount: existing?.retryCount ?? view.retryCount,
    );

    await _db.upsertStoryView(pendingView.toCompanion());

    try {
      await _remote.markViewed(pendingView);
      await _db.updateStoryViewStatus(
        storyId: view.storyId,
        viewerUid: view.viewerUid,
        status: SyncStatus.sent,
        retryCount: 0,
      );
    } catch (_) {
      await _db.updateStoryViewStatus(
        storyId: view.storyId,
        viewerUid: view.viewerUid,
        status: SyncStatus.failed,
        retryCount: pendingView.retryCount + 1,
      );
    }
  }

  Future<void> flushPendingViews({int limit = 50}) async {
    final pending = await _db.getPendingStoryViews(limit: limit);

    for (final row in pending) {
      final view = StoryViewModel.fromDrift(row);

      try {
        await _remote.markViewed(view);
        await _db.updateStoryViewStatus(
          storyId: row.storyId,
          viewerUid: row.viewerUid,
          status: SyncStatus.sent,
          retryCount: 0,
        );
      } catch (_) {
        await _db.updateStoryViewStatus(
          storyId: row.storyId,
          viewerUid: row.viewerUid,
          status: SyncStatus.failed,
          retryCount: row.retryCount + 1,
        );
      }
    }
  }

  Future<void> flushPendingStories({int limit = 20}) async {
    final pending = await _db.getPendingStories(limit: limit);

    for (final row in pending) {
      try {
        if (row.deletedAt != null) {
          await _remote.softDeleteStory(
            story: StoryModel.fromDrift(row),
            deletedAt: DateTime.fromMillisecondsSinceEpoch(row.deletedAt!),
          );
        } else {
          await _remote.createStory(StoryModel.fromDrift(row));
        }

        await _db.updateStorySyncStatus(
          storyId: row.id,
          status: StorySyncStatus.synced,
          retryCount: 0,
        );
      } catch (_) {
        await _db.updateStorySyncStatus(
          storyId: row.id,
          status: StorySyncStatus.failed,
          retryCount: row.retryCount + 1,
        );
      }
    }
  }

  Future<void> _persistRemoteStories(List<StoryModel> stories) async {
    if (stories.isEmpty) return;

    final localStories = await _db.getStoriesByIds(
      stories.map((story) => story.id).toList(),
    );

    await _db.upsertStories(
      stories.map((story) {
        final local = localStories[story.id];
        if (local == null) return story.toCompanion();

        final hasUnresolvedLocalState =
            local.syncStatus != StorySyncStatus.synced;
        final hasUnresolvedLocalDeletion =
            local.deletedAt != null &&
            (local.syncStatus == StorySyncStatus.deleting ||
                local.syncStatus == StorySyncStatus.failed);

        return story.toCompanion().copyWith(
          localPath: Value(local.localPath),
          deletedAt: hasUnresolvedLocalDeletion
              ? Value(local.deletedAt)
              : Value(story.deletedAt?.millisecondsSinceEpoch),
          syncStatus: hasUnresolvedLocalState
              ? Value(local.syncStatus)
              : const Value(StorySyncStatus.synced),
          retryCount: Value(hasUnresolvedLocalState ? local.retryCount : 0),
        );
      }).toList(),
    );
  }

  Stream<Set<String>> watchActiveViewedStoryIds({
    required String viewerUid,
    required DateTime now,
  }) =>
  _db.watchActiveViewedStoryIds(
    viewerUid: viewerUid,
    nowMs: now.millisecondsSinceEpoch,
  );
}

final storyRepositoryProvider = Provider<StoryRepository>(
  (ref) => StoryRepository(
    remote: ref.watch(storyFirestoreServiceProvider),
    db: ref.watch(messageDatabaseProvider),
  ),
);
