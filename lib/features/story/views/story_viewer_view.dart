import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/models/story_viewer_args.dart';
import 'package:kouvention/features/story/viewmodel/story_feed_viewmodel.dart';
import 'package:kouvention/features/story/viewmodel/story_viewer_viewmodel.dart';
import 'package:kouvention/features/story/widgets/story_author_avatar.dart';
import 'package:kouvention/features/story/widgets/story_presenter_mapper.dart';

final _visibleStoryIndicatorConfig = StoryViewIndicatorConfig(
  activeColor: Colors.white,
  backgroundCompletedColor: Colors.white,
  backgroundDisabledColor: Colors.white38,
  margin: EdgeInsets.fromLTRB(
    12.w, 8.h, 12.w, 0
  ),
);

final _hiddenStoryIndicatorConfig = StoryViewIndicatorConfig(
  activeColor: Colors.transparent,
  backgroundCompletedColor: Colors.transparent,
  backgroundDisabledColor: Colors.transparent,
  margin: EdgeInsets.fromLTRB(
    12.w, 8.h, 12.w, 0
  ),
);

class StoryViewerView extends ConsumerWidget {
  const StoryViewerView({super.key, required this.args});

  final StoryViewerArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(storyViewerVMProvider(args));
    final story = vm.currentStory;
    final currentUid = vm.currentUid;
    final currentProfile = currentUid == story.authorUid
        ? ref.watch(storyCurrentUserProfileProvider(currentUid!)).valueOrNull
        : null;
    final presenterItems = vm.stories
        .map((item) => StoryPresenterMapper.map(context, item))
        .toList(growable: false);
    final viewportWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: (_) => vm.onStoryPressStart(),
        onPointerUp: (_) => vm.onStoryPressEnd(),
        onPointerCancel: (_) => vm.onStoryPressEnd(),
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: vm.canSwipeAuthors
                  ? (_) => vm.onHorizontalDragStart()
                  : null,
              onHorizontalDragUpdate: vm.canSwipeAuthors
                  ? (details) => vm.onHorizontalDragUpdate(
                      details.delta.dx,
                      viewportWidth,
                    )
                  : null,
              onHorizontalDragEnd: vm.canSwipeAuthors
                  ? (details) => vm.onHorizontalDragEnd(
                      velocity: details.primaryVelocity ?? 0,
                      viewportWidth: viewportWidth,
                    )
                  : null,
              onHorizontalDragCancel: vm.canSwipeAuthors
                  ? vm.onHorizontalDragCancel
                  : null,
              child: AnimatedSlide(
                duration: vm.horizontalAnimationDuration,
                curve: Curves.easeOutCubic,
                offset: Offset(vm.horizontalOffset / viewportWidth, 0),
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOut,
                  offset: Offset(
                    0,
                    vm.dragOffset / MediaQuery.sizeOf(context).height,
                  ),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOut,
                    scale: vm.scale,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 90),
                      curve: Curves.easeOut,
                      opacity: vm.opacity,
                      child: FlutterStoryPresenter(
                        key: ValueKey(vm.currentFeedItem.authorUid),
                        flutterStoryController: vm.controller,
                        items: presenterItems,
                        initialIndex: vm.currentIndex,
                        restartOnCompleted: false,
                        onStoryChanged: vm.onStoryChanged,
                        onCompleted: () async {
                          if (!vm.moveToNextAuthor() && context.mounted) {
                            context.pop();
                          }
                        },
                        onSlideStart: (_) => vm.onSlideStart(),
                        onSlideDown: (details) {
                          vm.onSlideUpdate(
                            details.delta.dy,
                            onDismissed: () {
                              if (context.mounted) context.pop();
                            },
                          );
                        },
                        storyViewIndicatorConfig: vm.isStoryChromeVisible
                            ? _visibleStoryIndicatorConfig
                            : _hiddenStoryIndicatorConfig,
                        headerWidget: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: vm.isStoryChromeVisible ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !vm.isStoryChromeVisible,
                            child: _StoryViewerHeader(
                              story: story,
                              authorName:
                                  currentProfile?.displayName ??
                                  story.authorName,
                              authorPhotoUrl:
                                  currentProfile?.photoUrl ??
                                  story.authorPhotoUrl,
                              onClose: context.pop,
                            ),
                          ),
                        ),
                        footerWidget: vm.canReply
                            ? vm.isReplyOverlayVisible
                                  ? const SizedBox.shrink()
                                  : _StoryReplyBar(
                                      controller: vm.replyController,
                                      isSending: vm.isSendingReply,
                                      onSend: () => vm.sendStoryReply(
                                        vm.replyController.text,
                                      ),
                                      onOpenReplyOverlay: vm.openReplyOverlay,
                                    )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _StoryCaptionOverlay(
              key: ValueKey('${vm.currentFeedItem.authorUid}:${story.id}'),
              caption:
                  story.type == StoryType.audio || story.type == StoryType.text
                  ? null
                  : story.caption,
              bottomOffset: vm.canReply ? 70.h : 0,
              onTogglePlayback: vm.togglePlayback,
            ),
            if (vm.isReplyOverlayVisible && vm.canReply)
              Positioned.fill(
                child: _StoryReplyOverlay(
                  controller: vm.replyController,
                  focusNode: vm.replyFocusNode,
                  isSending: vm.isSendingReply,
                  onEmoji: vm.sendStoryReply,
                  onClose: vm.closeReplyOverlay,
                  onSend: () => vm.sendStoryReply(vm.replyController.text),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StoryCaptionOverlay extends StatefulWidget {
  const _StoryCaptionOverlay({
    required this.caption,
    required this.bottomOffset,
    required this.onTogglePlayback,
    super.key,
  });

  final String? caption;
  final double bottomOffset;
  final VoidCallback onTogglePlayback;

  @override
  State<_StoryCaptionOverlay> createState() => _StoryCaptionOverlayState();
}

class _StoryCaptionOverlayState extends State<_StoryCaptionOverlay> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.caption?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).viewInsets.bottom + widget.bottomOffset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _isExpanded = !_isExpanded);
          widget.onTogglePlayback();
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.0),
                Colors.black.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH.w,
              AppSpacing.xl.h,
              AppSpacing.screenH.w,
              AppSpacing.md.h + MediaQuery.of(context).padding.bottom,
            ),
            child: Text(
              text,
              maxLines: _isExpanded ? null : 3,
              overflow: _isExpanded ? null : TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryReplyBar extends StatelessWidget {
  const _StoryReplyBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onOpenReplyOverlay,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onOpenReplyOverlay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! < 0) {
          onOpenReplyOverlay();
        }
      },
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.screenH.w,
            right: AppSpacing.screenH.w,
            top: AppSpacing.md.h,
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isSending,
                  readOnly: true,
                  minLines: 1,
                  maxLines: 3,
                  onTap: onOpenReplyOverlay,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Reply',
                    hintStyle: context.text.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                    filled: true,
                    counterStyle: TextStyle(color: scheme.primary),
                    fillColor: scheme.surface.withValues(
                      alpha: isDark ? 0.8 : 0.2,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full.r),
                      borderSide: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full.r),
                      borderSide: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full.r),
                      borderSide: BorderSide(color: scheme.primary),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md.w,
                    ),
                  ),
                  showCursor: false,
                  cursorColor: scheme.primary,
                ),
              ),
              Gap(AppSpacing.md.h),
              IconButton.filled(
                tooltip: 'Send reply',
                onPressed: isSending ? null : onSend,
                style: IconButton.styleFrom(
                  backgroundColor: AppColorTokens.primary,
                ),
                icon: isSending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.send_rounded, color: scheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryReplyOverlay extends StatelessWidget {
  const _StoryReplyOverlay({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onEmoji,
    required this.onClose,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final ValueChanged<String> onEmoji;
  final VoidCallback onClose;
  final VoidCallback onSend;

  static const _emojis = ['😍', '😂', '😮', '😢', '🙏', '🧐', '😴', '🤬'];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.78),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH.w,
              AppSpacing.md.h,
              AppSpacing.screenH.w,
              AppSpacing.md.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Wrap(
                  spacing: AppSpacing.md.w,
                  runSpacing: AppSpacing.sm.h,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final emoji in _emojis)
                      GestureDetector(
                        onTap: isSending ? null : () => onEmoji(emoji),
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.sm.w),
                          child: Text(emoji, style: context.text.displaySmall),
                        ),
                      ),
                  ],
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            enabled: !isSending,
                            autofocus: true,
                            minLines: 1,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Reply',
                              hintStyle: context.text.bodySmall.copyWith(
                                color: Colors.white,
                              ),
                              filled: true,
                              counterStyle: TextStyle(color: scheme.primary),
                              fillColor: scheme.surface.withValues(alpha: 0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full.r,
                                ),
                                borderSide: BorderSide(
                                  color: scheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full.r,
                                ),
                                borderSide: BorderSide(
                                  color: scheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full.r,
                                ),
                                borderSide: BorderSide(color: scheme.primary),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md.w,
                              ),
                            ),
                            showCursor: true,
                            cursorColor: scheme.primary,
                          ),
                        ),
                        Gap(AppSpacing.md.h),
                        IconButton.filled(
                          tooltip: 'Send reply',
                          onPressed: isSending ? null : onSend,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColorTokens.primary,
                          ),
                          icon: isSending
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  color: scheme.onSurface,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        Gap(AppSpacing.sm),
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
