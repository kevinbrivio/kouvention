import 'package:kouvention/features/story/models/story_feed_item.dart';

enum StoryViewerTraversal { isolated, feed }

class StoryViewerArgs {
  StoryViewerArgs({required StoryFeedItem feedItem, this.initialIndex = 0})
    : feedItems = List.unmodifiable([feedItem]),
      initialFeedIndex = 0,
      viewedStoryIds = const {},
      traversal = StoryViewerTraversal.isolated;

  StoryViewerArgs.feed({
    required List<StoryFeedItem> feedItems,
    required this.initialFeedIndex,
    required Set<String> viewedStoryIds,
  }) : assert(feedItems.isNotEmpty),
       assert(initialFeedIndex >= 0),
       assert(initialFeedIndex < feedItems.length),
       feedItems = List.unmodifiable(feedItems),
       viewedStoryIds = Set.unmodifiable(viewedStoryIds),
       initialIndex = 0,
       traversal = StoryViewerTraversal.feed;

  final List<StoryFeedItem> feedItems;
  final int initialFeedIndex;
  final int initialIndex;
  final Set<String> viewedStoryIds;
  final StoryViewerTraversal traversal;

  StoryFeedItem get feedItem => feedItems[initialFeedIndex];

  int storyIndexFor(StoryFeedItem item) {
    if (traversal == StoryViewerTraversal.isolated) {
      return initialIndex.clamp(0, item.stories.length - 1);
    }

    final firstUnseen = item.stories.indexWhere(
      (story) => !viewedStoryIds.contains(story.id),
    );
    return firstUnseen < 0 ? 0 : firstUnseen;
  }
}
