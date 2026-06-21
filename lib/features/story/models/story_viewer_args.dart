import 'package:kouvention/features/story/models/story_feed_item.dart';

class StoryViewerArgs {
  final StoryFeedItem feedItem;
  final int initialIndex;

  const StoryViewerArgs({required this.feedItem, this.initialIndex = 0});
}
