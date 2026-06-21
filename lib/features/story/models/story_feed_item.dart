import 'package:kouvention/features/story/models/story_model.dart';

class StoryFeedItem {
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;
  final List<StoryModel> stories;
  final int unseenCount;
  final bool isOwnStory;

  const StoryFeedItem({
    required this.authorUid,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.stories,
    required this.unseenCount,
    required this.isOwnStory,
  });

  StoryModel get latestStory => stories.first;

  DateTime get latestCreatedAt => latestStory.createdAt;

  int get totalStories => stories.length;

  bool get hasUnseen => unseenCount > 0;

  String? get coverUrl => switch (latestStory.type) {
    StoryType.image => latestStory.thumbnailUrl ?? latestStory.mediaUrl,
    StoryType.video ||
    StoryType.audio ||
    StoryType.text => latestStory.thumbnailUrl,
  };
}
