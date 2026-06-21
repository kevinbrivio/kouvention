import 'package:kouvention/features/story/models/story_model.dart';

typedef StoryCursor = ({DateTime createdAt, String storyId});

class StoryPage {
  final List<StoryModel> stories;
  final bool hasMore;
  final StoryCursor? nextCursor;

  const StoryPage({
    required this.stories,
    required this.hasMore,
    required this.nextCursor,
  });
}
