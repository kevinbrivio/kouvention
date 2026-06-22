import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/story/models/story_composer_args.dart';
import 'package:kouvention/features/story/models/story_feed_item.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/repositories/story_repository.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

const int storyFeedLimit = 50;

class StoryFeedVM extends BaseNotifier {
  StoryFeedVM(super.ref)
    : currentUid = ref.read(authServiceProvider).currentUser?.uid;

  final String? currentUid;

  @override
  FutureOr<void> init() {}
}

final storyFeedVM = ChangeNotifierProvider.autoDispose<StoryFeedVM>(
  StoryFeedVM.new,
);

final storyCurrentUserProfileProvider = StreamProvider.autoDispose
    .family<UserModel?, String>(
      (ref, currentUid) =>
          ref.watch(userServiceProvider).streamUser(currentUid),
    );

/// Firestore listener used only while the story feed screen is mounted.
/// Emissions are persisted to Drift by StoryRepository.
final storyRemoteFeedSyncProvider = StreamProvider.autoDispose
    .family<void, String>((ref, currentUid) {
      final repository = ref.watch(storyRepositoryProvider);
      final cutoff = DateTime.now().subtract(storyLifetime);

      return repository.syncLatestFeed(
        currentUid: currentUid,
        cutoff: cutoff,
        limit: storyFeedLimit,
      );
    });

/// Trigger local query to remove expired stories
/// without restarting Firestore listener
final storyExpiryClockProvider = StreamProvider.autoDispose<DateTime>((
  ref,
) async* {
  yield DateTime.now();

  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 5),
    (_) => DateTime.now(),
  );
});

final activeStoriesProvider = StreamProvider.autoDispose
    .family<List<StoryModel>, String>((ref, currentUid) {
      ref.watch(storyRemoteFeedSyncProvider(currentUid));

      final now =
          ref.watch(storyExpiryClockProvider).valueOrNull ?? DateTime.now();
      final repository = ref.watch(storyRepositoryProvider);

      return repository.watchActiveStories(
        currentUid: currentUid,
        now: now,
        limit: storyFeedLimit,
      );
    });

final viewedStoryIdsProvider = StreamProvider.autoDispose
    .family<Set<String>, String>((ref, currentUid) {
      final now =
          ref.watch(storyExpiryClockProvider).valueOrNull ?? DateTime.now();

      return ref
          .watch(storyRepositoryProvider)
          .watchActiveViewedStoryIds(viewerUid: currentUid, now: now);
    });

final storyFeedItemsProvider = Provider.autoDispose
    .family<AsyncValue<List<StoryFeedItem>>, String>((ref, currentUid) {
      final storiesAsync = ref.watch(activeStoriesProvider(currentUid));
      final viewedIdsAsync = ref.watch(viewedStoryIdsProvider(currentUid));

      return storiesAsync.when(
        loading: () => const AsyncLoading(),
        error: AsyncError.new,
        data: (stories) => viewedIdsAsync.when(
          loading: () => const AsyncLoading(),
          error: AsyncError.new,
          data: (viewedIds) {
            final grouped = <String, List<StoryModel>>{};

            for (final story in stories) {
              grouped.putIfAbsent(story.authorUid, () => []).add(story);
            }

            final items = grouped.entries.map((entry) {
              final authorStories = entry.value
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

              final latest = authorStories.last;

              return StoryFeedItem(
                authorUid: entry.key,
                authorName: latest.authorName,
                authorPhotoUrl: latest.authorPhotoUrl,
                stories: List.unmodifiable(authorStories),
                unseenCount: authorStories
                    .where((story) => !viewedIds.contains(story.id))
                    .length,
                isOwnStory: entry.key == currentUid,
              );
            }).toList();

            items.sort((a, b) {
              if (a.isOwnStory != b.isOwnStory) {
                return a.isOwnStory ? -1 : 1;
              }

              if (a.hasUnseen != b.hasUnseen) {
                return a.hasUnseen ? -1 : 1;
              }

              return b.latestCreatedAt.compareTo(a.latestCreatedAt);
            });

            return AsyncData(items);
          },
        ),
      );
    });

List<StoryFeedItem> searchStoryFeedItemsByAuthor(
  List<StoryFeedItem> items,
  String query,
) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return items;

  return items
      .where(
        (item) =>
            !item.isOwnStory &&
            item.authorName.toLowerCase().contains(normalizedQuery),
      )
      .toList();
}

StoryFeedItem? activeStoryFeedItemAt(StoryFeedItem item, DateTime now) {
  final activeStories =
      item.stories
          .where(
            (story) => story.deletedAt == null && story.expiresAt.isAfter(now),
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  if (activeStories.isEmpty) return null;

  final latest = activeStories.last;
  final unseenCount = item.unseenCount > activeStories.length
      ? activeStories.length
      : item.unseenCount;

  return StoryFeedItem(
    authorUid: item.authorUid,
    authorName: latest.authorName,
    authorPhotoUrl: latest.authorPhotoUrl,
    stories: List.unmodifiable(activeStories),
    unseenCount: unseenCount,
    isOwnStory: item.isOwnStory,
  );
}

List<StoryFeedItem> activeStoryFeedItemsAt(
  List<StoryFeedItem> items,
  DateTime now,
) {
  final activeItems = <StoryFeedItem>[];
  for (final item in items) {
    final activeItem = activeStoryFeedItemAt(item, now);
    if (activeItem != null) activeItems.add(activeItem);
  }
  return activeItems;
}
