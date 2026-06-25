import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:video_player/video_player.dart';

class StoryPresenterMapper {
  const StoryPresenterMapper._();

  static StoryItem map(
    BuildContext context,
    StoryModel story, {
    double mediaBottomPadding = 0,
  }) => switch (story.type) {
    StoryType.image => _image(story, mediaBottomPadding),
    StoryType.video => _video(story, mediaBottomPadding),
    StoryType.text => _text(context, story),
    StoryType.audio => _audio(context, story),
  };

  static StoryItem _image(StoryModel story, double bottomPadding) {
    final source = _mediaSource(story);
    if (source == null) return _unavailableStory();

    return StoryItem(
      url: source.path,
      storyItemType: StoryItemType.custom,
      storyItemSource: source.source,
      duration: const Duration(seconds: 5),
      customWidget: (_, _) => _SquareMediaStoryContent(
        story: story,
        source: source,
        bottomPadding: bottomPadding,
      ),
    );
  }

  static StoryItem _video(StoryModel story, double bottomPadding) {
    final source = _mediaSource(story);
    if (source == null) return _unavailableStory();

    return StoryItem(
      url: source.path,
      storyItemType: StoryItemType.custom,
      storyItemSource: source.source,
      duration: Duration(seconds: story.mediaDuration ?? 5),
      customWidget: (controller, _) => _SquareMediaStoryContent(
        story: story,
        source: source,
        bottomPadding: bottomPadding,
        storyController: controller,
      ),
    );
  }

  static StoryItem _text(BuildContext context, StoryModel story) {
    final text = story.text?.trim();
    final backgroundColor = textBackgroundColor(context, story);
    final foregroundColor = story.backgroundColorArgb == null
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Colors.white;

    return StoryItem(
      url: text == null || text.isEmpty ? ' ' : text,
      storyItemType: StoryItemType.text,
      duration: const Duration(seconds: 5),
      textConfig: StoryViewTextConfig(
        backgroundColor: backgroundColor,
        textWidget: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            text == null || text.isEmpty ? ' ' : text,
            textAlign: TextAlign.center,
            style: context.text.headlineMedium.copyWith(color: foregroundColor),
          ),
        ),
      ),
    );
  }

  static Color textBackgroundColor(BuildContext context, StoryModel story) =>
      story.backgroundColorArgb == null
      ? Theme.of(context).colorScheme.primaryContainer
      : Color(story.backgroundColorArgb!);

  static StoryItem _audio(BuildContext context, StoryModel story) {
    final source = _mediaSource(story);
    if (source == null) return _unavailableStory();
    final backgroundColor = story.backgroundColorArgb == null
        ? Theme.of(context).colorScheme.secondaryContainer
        : Color(story.backgroundColorArgb!);
    final foregroundColor = story.backgroundColorArgb == null
        ? Theme.of(context).colorScheme.onSecondaryContainer
        : Colors.white;

    return StoryItem(
      storyItemType: StoryItemType.custom,
      storyItemSource: source.source,
      audioConfig: StoryViewAudioConfig(
        audioPath: source.path,
        source: source.source,
        onAudioStart: (_) {},
      ),
      customWidget: (_, audioPlayer) => _AudioStoryContent(
        story: story,
        audioPlayer: audioPlayer,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
      ),
    );
  }

  static StoryItem _unavailableStory() => StoryItem(
    storyItemType: StoryItemType.custom,
    duration: const Duration(seconds: 3),
    customWidget: (_, _) => const _UnavailableStoryContent(),
  );

  static ({String path, StoryItemSource source})? _mediaSource(
    StoryModel story,
  ) {
    final localPath = story.localPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      if (File(localPath).existsSync()) {
        return (path: localPath, source: StoryItemSource.file);
      }
    }

    final mediaUrl = story.mediaUrl?.trim();
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      return (path: mediaUrl, source: StoryItemSource.network);
    }

    return null;
  }
}

class _SquareMediaStoryContent extends StatelessWidget {
  const _SquareMediaStoryContent({
    required this.story,
    required this.source,
    required this.bottomPadding,
    this.storyController,
  });

  final StoryModel story;
  final ({String path, StoryItemSource source}) source;
  final double bottomPadding;
  final FlutterStoryController? storyController;

  @override
  Widget build(BuildContext context) {
    final caption = story.caption?.trim();
    final hasCaption = caption != null && caption.isNotEmpty;

    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final captionReserve = hasCaption ? 96.h : 0.0;
            final videoAreaHeight = math.max(
              0.0,
              constraints.maxHeight - captionReserve,
            );
            final side = math.min(
              constraints.maxWidth,
              videoAreaHeight,
            );
        
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox.square(
                      dimension: side,
                      child: story.type == StoryType.video
                          ? _SquareVideoStory(
                              source: source,
                              storyController: storyController,
                            )
                          : _SquareImageStory(source: source),
                    ),
                  ),
                ),
                if (hasCaption)
                  SizedBox(
                    height: captionReserve,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        AppSpacing.sm.h,
                        AppSpacing.screenH,
                        AppSpacing.sm.h,
                      ),
                      child: Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SquareImageStory extends StatelessWidget {
  const _SquareImageStory({required this.source});

  final ({String path, StoryItemSource source}) source;

  @override
  Widget build(BuildContext context) {
    if (source.source.isFile) {
      return Image.file(
        File(source.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _UnavailableStoryContent(),
      );
    }

    return Image.network(
      source.path,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CupertinoActivityIndicator());
      },
      errorBuilder: (_, _, _) => const _UnavailableStoryContent(),
    );
  }
}

class _SquareVideoStory extends StatefulWidget {
  const _SquareVideoStory({
    required this.source,
    required this.storyController,
  });

  final ({String path, StoryItemSource source}) source;
  final FlutterStoryController? storyController;

  @override
  State<_SquareVideoStory> createState() => _SquareVideoStoryState();
}

class _SquareVideoStoryState extends State<_SquareVideoStory> {
  VideoPlayerController? _controller;
  bool _hasAdvanced = false;

  @override
  void initState() {
    super.initState();
    widget.storyController?.addListener(_onStoryControllerChanged);
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _SquareVideoStory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storyController != widget.storyController) {
      oldWidget.storyController?.removeListener(_onStoryControllerChanged);
      widget.storyController?.addListener(_onStoryControllerChanged);
    }

    if (oldWidget.source != widget.source) {
      _replaceController();
    }
  }

  Future<void> _initialize() async {
    final controller = widget.source.source.isFile
        ? VideoPlayerController.file(File(widget.source.path))
        : VideoPlayerController.networkUrl(Uri.parse(widget.source.path));

    _controller = controller;
    controller.addListener(_onVideoChanged);

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();
    } catch (_) {
      if (!mounted || controller != _controller) return;
    }

    if (mounted && controller == _controller) {
      setState(() {});
    } else {
      await controller.dispose();
    }
  }

  Future<void> _replaceController() async {
    final previous = _controller;
    previous?.removeListener(_onVideoChanged);
    _hasAdvanced = false;
    setState(() => _controller = null);
    await _initialize();
    await previous?.dispose();
  }

  void _onVideoChanged() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _hasAdvanced) {
      return;
    }

    final duration = controller.value.duration;
    if (duration == Duration.zero) return;

    if (controller.value.position >= duration) {
      _hasAdvanced = true;
      widget.storyController?.next();
    }
  }

  void _onStoryControllerChanged() {
    final controller = _controller;
    final action = widget.storyController?.storyStatus;
    if (controller == null || action == null) return;

    if (action.isPause) {
      controller.pause();
    } else if (action.isPlay || action.isPlayCustomWidget) {
      controller.play();
    } else if (action.isMute) {
      controller.setVolume(0);
    } else if (action.isUnMute) {
      controller.setVolume(1);
    }
  }

  @override
  void dispose() {
    widget.storyController?.removeListener(_onStoryControllerChanged);
    _controller?.removeListener(_onVideoChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _AudioStoryContent extends StatelessWidget {
  const _AudioStoryContent({
    required this.story,
    required this.audioPlayer,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final StoryModel story;
  final AudioPlayer? audioPlayer;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: backgroundColor,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.graphic_eq_rounded, size: 88, color: foregroundColor),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Audio story',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.titleLarge.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            StreamBuilder<Duration>(
              stream: audioPlayer?.positionStream,
              initialData: Duration.zero,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                return Text(
                  _formatDuration(position),
                  style: context.text.bodyMedium.copyWith(
                    color: foregroundColor,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _UnavailableStoryContent extends StatelessWidget {
  const _UnavailableStoryContent();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 56,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
