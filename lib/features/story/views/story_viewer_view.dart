import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/repositories/chat_repository.dart';
import 'package:kouvention/features/chat/repositories/message_repository.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/viewmodel/audio_manager.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/models/story_view_model.dart';
import 'package:kouvention/features/story/models/story_viewer_args.dart';
import 'package:kouvention/features/story/repositories/story_repository.dart';
import 'package:kouvention/features/story/viewmodel/story_feed_viewmodel.dart';
import 'package:kouvention/features/story/widgets/story_author_avatar.dart';
import 'package:kouvention/features/story/widgets/story_presenter_mapper.dart';
import 'package:kouvention/features/user/services/user_service.dart';
import 'package:oktoast/oktoast.dart';

class StoryViewerView extends ConsumerStatefulWidget {
  const StoryViewerView({super.key, required this.args});

  final StoryViewerArgs args;

  @override
  ConsumerState<StoryViewerView> createState() => _StoryViewerViewState();
}

class _StoryViewerViewState extends ConsumerState<StoryViewerView> {
  late final FlutterStoryController _controller;
  final _replyController = TextEditingController();
  Timer? _viewTimer;
  int _currentIndex = 0;
  double _dragDistance = 0;
  double _dragOffset = 0;
  bool _isReplyPanelVisible = false;
  bool _isSendingReply = false;
  bool _isDismissing = false;

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
    _replyController.dispose();
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
    final canReply = currentUid != null && currentUid != story.authorUid;
    final scale = (1 - (_dragOffset.abs() / 1200)).clamp(0.86, 1.0).toDouble();
    final opacity = (1 - (_dragOffset.abs() / 320)).clamp(0.35, 1.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerUp: (_) => _resetDragOffset(),
        onPointerCancel: (_) => _resetDragOffset(),
        child: Stack(
          children: [
            AnimatedSlide(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              offset: Offset(
                0,
                _dragOffset / MediaQuery.sizeOf(context).height,
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                scale: scale,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOut,
                  opacity: opacity,
                  child: FlutterStoryPresenter(
                    flutterStoryController: _controller,
                    items: presenterItems,
                    initialIndex: _currentIndex,
                    restartOnCompleted: false,
                    onStoryChanged: _onStoryChanged,
                    onCompleted: () async {
                      if (mounted) context.pop();
                    },
                    onSlideStart: (_) {
                      _dragDistance = 0;
                      _dragOffset = 0;
                    },
                    onSlideDown: (details) {
                      _dragDistance += details.delta.dy;
                      _handleVerticalDrag(canReply);
                    },
                    storyViewIndicatorConfig: const StoryViewIndicatorConfig(
                      activeColor: Colors.white,
                      backgroundCompletedColor: Colors.white,
                      backgroundDisabledColor: Colors.white38,
                      margin: EdgeInsets.fromLTRB(12, 10, 12, 0),
                    ),
                    headerWidget: _StoryViewerHeader(
                      story: story,
                      authorName:
                          currentProfile?.displayName ?? story.authorName,
                      authorPhotoUrl:
                          currentProfile?.photoUrl ?? story.authorPhotoUrl,
                      onClose: context.pop,
                    ),
                  ),
                ),
              ),
            ),
            _StoryCaptionOverlay(
              caption: story.type == StoryType.audio ? null : story.caption,
              bottomOffset: _isReplyPanelVisible ? 154 : 28,
            ),
            _StoryReplyPanel(
              controller: _replyController,
              isVisible: _isReplyPanelVisible && canReply,
              isSending: _isSendingReply,
              onClose: () => setState(() => _isReplyPanelVisible = false),
              onEmoji: _sendStoryReply,
              onSend: () => _sendStoryReply(_replyController.text),
            ),
          ],
        ),
      ),
    );
  }

  void _handleVerticalDrag(bool canReply) {
    if (_isDismissing) return;

    if (_dragDistance > 0) {
      setState(() {
        _dragOffset = _dragDistance.clamp(0, 220).toDouble();
        _isReplyPanelVisible = false;
      });

      if (_dragDistance > 120) {
        unawaited(_dismissStory());
      }
      return;
    }

    if (canReply && _dragDistance < -48) {
      setState(() {
        _dragOffset = 0;
        _isReplyPanelVisible = true;
      });
    }
  }

  void _resetDragOffset() {
    if (!_isDismissing && _dragOffset != 0 && mounted) {
      setState(() => _dragOffset = 0);
    }
  }

  Future<void> _dismissStory() async {
    if (_isDismissing) return;
    setState(() {
      _isDismissing = true;
      _dragOffset = 260;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) context.pop();
  }

  Future<void> _sendStoryReply(String value) async {
    final text = value.trim();
    if (text.isEmpty || _isSendingReply) return;

    final story = _stories[_currentIndex];
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null || currentUser.uid == story.authorUid) return;

    setState(() => _isSendingReply = true);
    try {
      final currentProfile = ref
          .read(storyCurrentUserProfileProvider(currentUser.uid))
          .valueOrNull;
      final recipient = await ref
          .read(userServiceProvider)
          .getUser(story.authorUid);
      final senderName =
          currentProfile?.displayName ?? currentUser.displayName ?? 'Unknown';
      final chat = await ref
          .read(chatRepositoryProvider)
          .getOrCreateDirectChat(
            currentUid: currentUser.uid,
            otherUid: story.authorUid,
            memberInfo: {
              currentUser.uid: MemberInfo(
                displayName: senderName,
                photoUrl: currentProfile?.photoUrl ?? currentUser.photoURL,
              ),
              story.authorUid: MemberInfo(
                displayName: recipient?.displayName ?? story.authorName,
                photoUrl: recipient?.photoUrl ?? story.authorPhotoUrl,
              ),
            },
          );

      if (chat == null) {
        showToast('Could not open the chat. Please try again.');
        return;
      }

      await ref
          .read(messageRepositoryProvider)
          .sendTextMessage(
            chatRoomId: chat.id,
            textContent: text,
            senderName: senderName,
            memberUids: chat.members,
            otherUserFcmTokens: recipient?.fcmTokens,
            replyTo: _storyReplyReference(story),
          );

      _replyController.clear();
      if (mounted) {
        setState(() => _isReplyPanelVisible = false);
      }
    } catch (_) {
      showToast('Could not send the reply. Please try again.');
    } finally {
      if (mounted) setState(() => _isSendingReply = false);
    }
  }

  ReplyToModel _storyReplyReference(StoryModel story) => ReplyToModel(
    messageId: story.id,
    senderId: story.authorUid,
    senderName: story.authorName,
    text: _storyPreviewText(story),
    sentAt: story.createdAt,
    mediaUrl: story.thumbnailUrl ?? story.mediaUrl,
    mediaType: 'story:${story.type.name}',
  );

  String _storyPreviewText(StoryModel story) {
    final caption = story.caption?.trim();
    if (caption != null && caption.isNotEmpty) return caption;

    final text = story.text?.trim();
    if (text != null && text.isNotEmpty) return text;

    return switch (story.type) {
      StoryType.image => 'Photo story',
      StoryType.video => 'Video story',
      StoryType.audio => 'Audio story',
      StoryType.text => 'Story',
    };
  }
}

class _StoryCaptionOverlay extends StatelessWidget {
  const _StoryCaptionOverlay({
    required this.caption,
    required this.bottomOffset,
  });

  final String? caption;
  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    final text = caption?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 20,
      right: 20,
      bottom: MediaQuery.of(context).padding.bottom + bottomOffset,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.46),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _StoryReplyPanel extends StatelessWidget {
  const _StoryReplyPanel({
    required this.controller,
    required this.isVisible,
    required this.isSending,
    required this.onClose,
    required this.onEmoji,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isVisible;
  final bool isSending;
  final VoidCallback onClose;
  final ValueChanged<String> onEmoji;
  final VoidCallback onSend;

  static const _emojis = ['❤️', '😂', '😮', '😢', '🙏'];

  @override
  Widget build(BuildContext context) => AnimatedPositioned(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    left: 0,
    right: 0,
    bottom: isVisible ? 0 : -210,
    child: SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.86),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (final emoji in _emojis)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: isSending ? null : () => onEmoji(emoji),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !isSending,
                      minLines: 1,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Reply',
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.12),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Send reply',
                    onPressed: isSending ? null : onSend,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    icon: isSending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
