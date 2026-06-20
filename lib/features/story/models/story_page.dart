import 'package:kouvention/features/story/models/story_model.dart';

class StoryPage {
  final List<StoryModel> stories;
  final bool hasMore;
  final DateTime? nextCursor;

  const StoryPage({
    required this.stories,
    required this.hasMore,
    required this.nextCursor,
  });
}