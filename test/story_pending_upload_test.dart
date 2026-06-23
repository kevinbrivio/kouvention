import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/services/media/cloud_media_service.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/models/story_page.dart';
import 'package:kouvention/features/story/models/story_view_model.dart';
import 'package:kouvention/features/story/repositories/story_repository.dart';
import 'package:kouvention/features/story/services/story_firestore_service.dart';

void main() {
  group('pending story media upload', () {
    late MessageDatabase db;
    late _FakeStoryRemote remote;
    late _FakeCloudMedia media;
    late List<double?> progress;
    late StoryRepository repository;

    setUp(() {
      db = MessageDatabase.forExecutor(NativeDatabase.memory());
      remote = _FakeStoryRemote();
      media = _FakeCloudMedia(
        result: const UploadResultModel(
          url: 'https://cdn.example.com/story.jpg',
          fileName: 'story.jpg',
          fileSizeBytes: 42,
          mimeType: 'image/jpeg',
          messageType: MessageType.image,
        ),
      );
      progress = [];
      repository = StoryRepository(
        remote: remote,
        db: db,
        media: media,
        setUploadProgress: (_, value) => progress.add(value),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('uploads local media before creating the remote story', () async {
      await db.upsertStory(_story(mediaUrl: null).toCompanion());

      await repository.flushPendingStories();

      final row = await db.getStoryById('story-1');
      expect(row, isNotNull);
      expect(row!.mediaUrl, 'https://cdn.example.com/story.jpg');
      expect(row.syncStatus, StorySyncStatus.synced);
      expect(remote.created, hasLength(1));
      expect(
        remote.created.single.mediaUrl,
        'https://cdn.example.com/story.jpg',
      );
      expect(progress, containsAllInOrder([0, 0.5, 1.0, null]));
    });

    test('does not create remote story when media upload fails', () async {
      media.result = null;
      await db.upsertStory(_story(mediaUrl: null).toCompanion());

      await repository.flushPendingStories();

      final row = await db.getStoryById('story-1');
      expect(row, isNotNull);
      expect(row!.mediaUrl, isNull);
      expect(row.syncStatus, StorySyncStatus.failed);
      expect(row.retryCount, 1);
      expect(remote.created, isEmpty);
    });
  });
}

StoryModel _story({String? mediaUrl}) {
  final createdAt = DateTime.utc(2026, 6, 22, 12);

  return StoryModel(
    id: 'story-1',
    authorUid: 'me',
    authorName: 'Me',
    type: StoryType.image,
    mediaUrl: mediaUrl,
    localPath: '/tmp/local-story.jpg',
    visibleTo: const ['me', 'alice'],
    createdAt: createdAt,
    expiresAt: createdAt.add(const Duration(hours: 24)),
    syncStatus: StorySyncStatus.pending,
  );
}

class _FakeCloudMedia implements CloudMediaService {
  _FakeCloudMedia({required this.result});

  UploadResultModel? result;

  @override
  Future<UploadResultModel?> uploadFile({
    required File file,
    required MessageType mediaType,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    onSendProgress?.call(1, 2);
    onSendProgress?.call(2, 2);
    return result;
  }
}

class _FakeStoryRemote implements StoryFirestoreService {
  final List<StoryModel> created = [];

  @override
  Future<void> createStory(StoryModel story) async {
    created.add(story);
  }

  @override
  Future<StoryPage> fetchFeedPage({
    required String currentUid,
    required DateTime cutoff,
    int limit = StoryFirestoreService.maxFeedPageSize,
    StoryCursor? cursor,
  }) async => const StoryPage(stories: [], hasMore: false, nextCursor: null);

  @override
  Future<void> markViewed(StoryViewModel view) async {}

  @override
  Future<void> softDeleteStory({
    required StoryModel story,
    required DateTime deletedAt,
  }) async {}

  @override
  Stream<List<StoryModel>> streamLatestFeed({
    required String currentUid,
    required DateTime cutoff,
    int limit = StoryFirestoreService.maxFeedPageSize,
  }) => const Stream.empty();
}
