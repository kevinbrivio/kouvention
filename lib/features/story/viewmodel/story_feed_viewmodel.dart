import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/repositories/story_repository.dart';

const int storyFeedLimit = 50;

/// Firestore listener used only while the story feed screen is mounted.
/// Emissions are persisted to Drift by StoryRepository.
final storyRemoteFeedSyncProvider = StreamProvider.autoDispose
    .family<void, String>((ref, currentUid) {
      final repository = ref.watch(storyRepositoryProvider);
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));

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
    const Duration(minutes: 1),
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
