import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/repositories/chat_repository.dart';
import 'package:kouvention/features/chat/repositories/message_repository.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/viewmodel/audio_manager.dart';
import 'package:kouvention/features/story/models/story_feed_item.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/models/story_view_model.dart';
import 'package:kouvention/features/story/models/story_viewer_args.dart';
import 'package:kouvention/features/story/repositories/story_repository.dart';
import 'package:kouvention/features/story/viewmodel/story_feed_viewmodel.dart';
import 'package:kouvention/features/user/services/user_service.dart';
import 'package:oktoast/oktoast.dart';

class StoryViewerVM extends ChangeNotifier {
  static const horizontalTransitionDuration = Duration(milliseconds: 160);

  StoryViewerVM(this.ref, {required this.args})
    : _feedIndex = args.initialFeedIndex,
      _currentIndex = 0 {
    _currentIndex = _initialStoryIndex;
    replyFocusNode.addListener(_onReplyFocusChanged);
    replyController.addListener(_onReplyTextChanged);
    unawaited(AudioManager.instance.stop());
  }

  final Ref ref;
  final StoryViewerArgs args;
  FlutterStoryController _controller = FlutterStoryController();
  final TextEditingController replyController = TextEditingController();
  final FocusNode replyFocusNode = FocusNode();

  Timer? _viewTimer;
  Timer? _chromeHideTimer;
  int _feedIndex;
  int _currentIndex;
  double _dragDistance = 0;
  double _dragOffset = 0;
  double _horizontalOffset = 0;
  bool _isReplyOverlayVisible = false;
  bool _isSendingReply = false;
  bool _isDismissing = false;
  bool _isHorizontalDragging = false;
  bool _isAuthorTransitioning = false;
  bool _isStoryPaused = false;
  bool _isDisposed = false;
  bool _isChromeHiddenByLongPress = false;

  FlutterStoryController get controller => _controller;
  bool get isStoryPaused => _isStoryPaused;
  StoryFeedItem get currentFeedItem => args.feedItems[_feedIndex];
  List<StoryModel> get stories => currentFeedItem.stories;
  StoryModel get currentStory => stories[_currentIndex];
  int get feedIndex => _feedIndex;
  int get currentIndex => _currentIndex;
  double get dragOffset => _dragOffset;
  double get horizontalOffset => _horizontalOffset;
  bool get isReplyOverlayVisible => _isReplyOverlayVisible;
  bool get isSendingReply => _isSendingReply;
  bool get canSwipeAuthors =>
      args.feedItems.length > 1 &&
      !_isReplyOverlayVisible &&
      !_isDismissing &&
      !_isAuthorTransitioning;
  Duration get horizontalAnimationDuration =>
      _isHorizontalDragging ? Duration.zero : horizontalTransitionDuration;
  String? get currentUid => ref.read(authServiceProvider).currentUser?.uid;
  bool get canReply =>
      currentUid != null && currentUid != currentStory.authorUid;
  double get scale =>
      (1 - (_dragOffset.abs() / 1200)).clamp(0.86, 1.0).toDouble();
  double get opacity =>
      (1 - (_dragOffset.abs() / 320)).clamp(0.35, 1.0).toDouble();
  int get _initialStoryIndex => args.storyIndexFor(currentFeedItem);
  bool get _hasFocusedReplyText =>
      replyFocusNode.hasFocus && replyController.text.trim().isNotEmpty;
  bool get isStoryChromeVisible => !_isChromeHiddenByLongPress;

  bool moveToNextAuthor() => _moveToAuthor(_feedIndex + 1);

  bool moveToPreviousAuthor() => _moveToAuthor(_feedIndex - 1);

  void onHorizontalDragStart() {
    if (!canSwipeAuthors) return;

    _isHorizontalDragging = true;
    _horizontalOffset = 0;
    controller.pause();
    _notify();
  }

  void onHorizontalDragUpdate(double delta, double viewportWidth) {
    if (!_isHorizontalDragging || _isAuthorTransitioning) return;

    final maxOffset = viewportWidth * 0.45;
    _horizontalOffset = (_horizontalOffset + delta).clamp(
      -maxOffset,
      maxOffset,
    );
    _notify();
  }

  Future<void> onHorizontalDragEnd({
    required double velocity,
    required double viewportWidth,
  }) async {
    if (!_isHorizontalDragging || _isAuthorTransitioning) return;

    _isHorizontalDragging = false;
    final shouldMove =
        _horizontalOffset.abs() >= viewportWidth * 0.2 || velocity.abs() >= 500;
    final direction = velocity.abs() >= 500
        ? velocity.sign
        : _horizontalOffset.sign;
    final targetFeedIndex = direction < 0 ? _feedIndex + 1 : _feedIndex - 1;

    if (!shouldMove ||
        direction == 0 ||
        targetFeedIndex < 0 ||
        targetFeedIndex >= args.feedItems.length) {
      _horizontalOffset = 0;
      _playControllerUnlessReplyTextFocused();
      _notify();
      return;
    }

    _isAuthorTransitioning = true;
    _horizontalOffset = direction < 0 ? -viewportWidth : viewportWidth;
    _notify();
    await Future<void>.delayed(horizontalTransitionDuration);
    if (_isDisposed) return;

    _isHorizontalDragging = true;
    _moveToAuthor(targetFeedIndex, notify: false);
    _horizontalOffset = direction < 0 ? viewportWidth : -viewportWidth;
    _notify();
    await Future<void>.delayed(Duration.zero);
    if (_isDisposed) return;

    _isHorizontalDragging = false;
    _horizontalOffset = 0;
    _notify();
    await Future<void>.delayed(horizontalTransitionDuration);
    if (_isDisposed) return;

    _isAuthorTransitioning = false;
    _notify();
  }

  void onHorizontalDragCancel() {
    if (!_isHorizontalDragging || _isAuthorTransitioning) return;

    _isHorizontalDragging = false;
    _horizontalOffset = 0;
    _playControllerUnlessReplyTextFocused();
    _notify();
  }

  void onStoryChanged(int index) {
    _viewTimer?.cancel();
    if (_currentIndex != index) {
      _currentIndex = index;
      controller.pause();
      _notify();
    }

    final uid = currentUid;
    final story = stories[index];
    if (uid == null) return;

    _viewTimer = Timer(const Duration(seconds: 1), () {
      if (_isDisposed) return;
      unawaited(
        ref
            .read(storyRepositoryProvider)
            .markViewed(
              StoryViewModel(
                storyId: story.id,
                viewerUid: uid,
                viewedAt: DateTime.now(),
                syncStatus: SyncStatus.pending,
                retryCount: 0,
              ),
            ),
      );
    });
  }

  void onSlideStart() {
    _dragDistance = 0;
    _dragOffset = 0;
    _notify();
  }

  void onSlideUpdate(double delta, {required VoidCallback onDismissed}) {
    if (_isDismissing) return;

    _dragDistance += delta;
    if (_dragDistance > 0) {
      _dragOffset = _dragDistance.clamp(0, 220).toDouble();
      if (_isReplyOverlayVisible) {
        _collapseReplyOverlay(notify: false);
      }
      _notify();

      if (_dragDistance > 120) {
        unawaited(_dismissStory(onDismissed));
      }
      return;
    }

    if (canReply && _dragDistance < -48 && !_isReplyOverlayVisible) {
      _dragOffset = 0;
      openReplyOverlay();
    }
  }

  void openReplyOverlay({bool requestFocus = true}) {
    if (!canReply) return;

    final wasVisible = _isReplyOverlayVisible;
    _isReplyOverlayVisible = true;
    controller.pause();
    if (!wasVisible) _notify();

    if (!requestFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && _isReplyOverlayVisible) {
        replyFocusNode.requestFocus();
      }
    });
  }

  void closeReplyOverlay() {
    _collapseReplyOverlay();
  }

  void _onReplyFocusChanged() {
    if (_isDisposed || !replyFocusNode.hasFocus) {
      return;
    }

    _pauseControllerForFocusedReplyText();

    if (_isReplyOverlayVisible) return;

    openReplyOverlay();
  }

  void _onReplyTextChanged() {
    if (_isDisposed) return;

    _pauseControllerForFocusedReplyText();
  }

  void resetDragOffset() {
    if (!_isDismissing && _dragOffset != 0) {
      _dragOffset = 0;
      _notify();
    }
  }

  bool _moveToAuthor(int feedIndex, {bool notify = true}) {
    if (feedIndex < 0 || feedIndex >= args.feedItems.length) return false;

    _viewTimer?.cancel();
    _chromeHideTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    replyController.clear();
    _isChromeHiddenByLongPress = false;
    _isReplyOverlayVisible = false;
    _isSendingReply = false;
    _isDismissing = false;
    _isStoryPaused = false;
    _dragDistance = 0;
    _dragOffset = 0;
    _feedIndex = feedIndex;
    _currentIndex = _initialStoryIndex;
    _controller = FlutterStoryController();
    if (notify) _notify();
    return true;
  }

  Future<void> sendStoryReply(String value) async {
    final text = value.trim();
    if (text.isEmpty || _isSendingReply) return;

    final story = currentStory;
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null || currentUser.uid == story.authorUid) return;

    final currentProfile = ref
        .read(storyCurrentUserProfileProvider(currentUser.uid))
        .valueOrNull;
    final userService = ref.read(userServiceProvider);
    final chatRepository = ref.read(chatRepositoryProvider);
    final messageRepository = ref.read(messageRepositoryProvider);

    _isSendingReply = true;
    _notify();

    try {
      final recipient = await userService.getUser(story.authorUid);
      final senderName =
          currentProfile?.displayName ?? currentUser.displayName ?? 'Unknown';
      final chat = await chatRepository.getOrCreateDirectChat(
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
        if (!_isDisposed) {
          showToast('Could not open the chat. Please try again.');
        }
        return;
      }

      await messageRepository.sendTextMessage(
        chatRoomId: chat.id,
        textContent: text,
        senderName: senderName,
        memberUids: chat.members,
        otherUserFcmTokens: recipient?.fcmTokens,
        replyTo: _storyReplyReference(story),
      );

      if (_isDisposed) return;
      replyController.clear();
      closeReplyOverlay();
    } catch (_) {
      if (!_isDisposed) {
        showToast('Could not send the reply. Please try again.');
      }
    } finally {
      _isSendingReply = false;
      _notify();
    }
  }

  Future<void> _dismissStory(VoidCallback onDismissed) async {
    if (_isDismissing) return;

    _isDismissing = true;
    _dragOffset = 260;
    _notify();

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!_isDisposed) onDismissed();
  }

  ReplyToModel _storyReplyReference(StoryModel story) => ReplyToModel(
    messageId: story.id,
    senderId: story.authorUid,
    senderName: story.authorName,
    text: story.type == StoryType.text
        ? story.text?.trim() ?? 'Story'
        : _storyPreviewText(story),
    sentAt: story.createdAt,
    mediaUrl: _storyReplyThumbnailUrl(story),
    mediaType: 'story:${story.type.name}',
  );

  String? _storyReplyThumbnailUrl(StoryModel story) {
    if (story.type != StoryType.image && story.type != StoryType.video) {
      return null;
    }

    final thumbnailUrl = story.thumbnailUrl?.trim();
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) return thumbnailUrl;

    final mediaUrl = story.mediaUrl?.trim();
    if (mediaUrl == null || mediaUrl.isEmpty) return null;
    if (story.type == StoryType.image) return mediaUrl;

    return mediaUrl
        .replaceFirst('/video/upload/', '/video/upload/so_0,f_jpg/')
        .replaceFirst(RegExp(r'\.[^.]+$'), '.jpg');
  }

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

  void togglePlayback() {
    if (_isStoryPaused) {
      _playControllerUnlessReplyTextFocused();
    } else {
      controller.pause();
      _isStoryPaused = true;
    }
    _notify();
  }

  void _pauseControllerForFocusedReplyText() {
    if (!_hasFocusedReplyText) return;

    controller.pause();
    if (!_isStoryPaused) {
      _isStoryPaused = true;
      _notify();
    }
  }

  void _playControllerUnlessReplyTextFocused() {
    if (_hasFocusedReplyText) {
      controller.pause();
      _isStoryPaused = true;
      return;
    }

    controller.play();
    _isStoryPaused = false;
  }

  void _collapseReplyOverlay({bool notify = true}) {
    if (replyFocusNode.hasFocus) {
      replyFocusNode.unfocus();
    }

    if (replyController.text.isNotEmpty) {
      replyController.clear();
    }

    _isReplyOverlayVisible = false;
    controller.play();
    _isStoryPaused = false;
    if (notify) _notify();
  }

  void onStoryPressStart() {
    if (_isReplyOverlayVisible) return;

    _chromeHideTimer?.cancel();
    _chromeHideTimer = Timer(kLongPressTimeout, () {
      if (_isDisposed) return;
      controller.pause();
      _isStoryPaused = true;
      _isChromeHiddenByLongPress = true;
      _notify();
    });
  }

  void onStoryPressEnd() {
    _chromeHideTimer?.cancel();

    var shouldNotify = false;
    if (_isChromeHiddenByLongPress) {
      _isChromeHiddenByLongPress = false;
      _playControllerUnlessReplyTextFocused();
      shouldNotify = true;
    }

    if (!_isDismissing && _dragOffset != 0) {
      _dragOffset = 0;
      shouldNotify = true;
    }

    if (shouldNotify) _notify();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _viewTimer?.cancel();
    _chromeHideTimer?.cancel();
    replyFocusNode.removeListener(_onReplyFocusChanged);
    replyController.removeListener(_onReplyTextChanged);
    replyFocusNode.dispose();
    replyController.dispose();
    // FlutterStoryPresenter owns and disposes the controller it receives.
    super.dispose();
  }
}

final storyViewerVMProvider = ChangeNotifierProvider.autoDispose
    .family<StoryViewerVM, StoryViewerArgs>(
      (ref, args) => StoryViewerVM(ref, args: args),
    );
