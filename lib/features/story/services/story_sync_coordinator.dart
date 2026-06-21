import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/story/repositories/story_repository.dart';

class StorySyncCoordinator {
  StorySyncCoordinator(this._repository);

  final StoryRepository _repository;
  bool _isFlushing = false;

  Future<void> flushPending() async {
    if (_isFlushing) return;
    _isFlushing = true;

    try {
      await _repository.flushPendingStories();
      await _repository.flushPendingViews();
    } finally {
      _isFlushing = false;
    }
  }
}

final storySyncCoordinatorProvider = Provider<StorySyncCoordinator>(
  (ref) => StorySyncCoordinator(ref.watch(storyRepositoryProvider)),
);
