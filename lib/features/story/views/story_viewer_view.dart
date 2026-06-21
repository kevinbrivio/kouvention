import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/viewmodel/audio_manager.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/models/story_view_model.dart';
import 'package:kouvention/features/story/models/story_viewer_args.dart';
import 'package:kouvention/features/story/repositories/story_repository.dart';
import 'package:kouvention/features/story/viewmodel/story_feed_viewmodel.dart';
import 'package:kouvention/features/story/widgets/story_author_avatar.dart';
import 'package:kouvention/features/story/widgets/story_presenter_mapper.dart';

class StoryViewerView extends ConsumerStatefulWidget {
  const StoryViewerView({super.key, required this.args});

  final StoryViewerArgs args;

  @override
  ConsumerState<StoryViewerView> createState() => _StoryViewerViewState();
}

class _StoryViewerViewState extends ConsumerState<StoryViewerView> {
  late final FlutterStoryController _controller;
  Timer? _viewTimer;
  int _currentIndex = 0;
  double _dragDistance = 0;

  List<StoryModel> get _stories => widget.args.feedItem.stories;

  @override
  void initState() {
    super.initState();
    _controller = FlutterStoryController();
    _currentIndex = widget.args.initialIndex.clamp(0, _stories.length - 1);
    unawaited(AudioManager.instance.stop());
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    // FlutterStoryPresenter owns and disposes the controller it receives.
    super.dispose();
  }

  void _onStoryChanged(int index) {
    _viewTimer?.cancel();
    if (mounted && _currentIndex != index) {
      setState(() => _currentIndex = index);
    }

    final currentUid = ref.read(authServiceProvider).currentUser?.uid;
    final story = _stories[index];
    if (currentUid == null || story.authorUid == currentUid) return;

    _viewTimer = Timer(const Duration(seconds: 1), () {
      ref
          .read(storyRepositoryProvider)
          .markViewed(
            StoryViewModel(
              storyId: story.id,
              viewerUid: currentUid,
              viewedAt: DateTime.now(),
              syncStatus: SyncStatus.pending,
              retryCount: 0,
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_currentIndex];
    final currentUid = ref.watch(authServiceProvider).currentUser?.uid;
    final currentProfile = currentUid == story.authorUid
        ? ref.watch(storyCurrentUserProfileProvider(currentUid!)).valueOrNull
        : null;
    final presenterItems = _stories
        .map((item) => StoryPresenterMapper.map(context, item))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.black,
      body: FlutterStoryPresenter(
        flutterStoryController: _controller,
        items: presenterItems,
        initialIndex: _currentIndex,
        restartOnCompleted: false,
        onStoryChanged: _onStoryChanged,
        onCompleted: () async {
          if (mounted) context.pop();
        },
        onSlideStart: (_) => _dragDistance = 0,
        onSlideDown: (details) {
          _dragDistance += details.delta.dy;
          if (_dragDistance > 100 && mounted) {
            context.pop();
          }
        },
        storyViewIndicatorConfig: const StoryViewIndicatorConfig(
          activeColor: Colors.white,
          backgroundCompletedColor: Colors.white,
          backgroundDisabledColor: Colors.white38,
          margin: EdgeInsets.fromLTRB(12, 10, 12, 0),
        ),
        headerWidget: _StoryViewerHeader(
          story: story,
          authorName: currentProfile?.displayName ?? story.authorName,
          authorPhotoUrl: currentProfile?.photoUrl ?? story.authorPhotoUrl,
          onClose: context.pop,
        ),
      ),
    );
  }
}

class _StoryViewerHeader extends StatelessWidget {
  const _StoryViewerHeader({
    required this.story,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.onClose,
  });

  final StoryModel story;
  final String authorName;
  final String? authorPhotoUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 30, 8, 8),
    child: Row(
      children: [
        StoryAuthorAvatar(
          authorUid: story.authorUid,
          authorName: authorName,
          photoUrl: authorPhotoUrl,
          diameter: 36,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _relativeTime(story.createdAt),
                style: context.text.labelMedium.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    ),
  );

  String _relativeTime(DateTime createdAt) {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inMinutes < 1) return 'Now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
    return '${elapsed.inHours}h';
  }
}
