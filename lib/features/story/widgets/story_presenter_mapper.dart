import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:video_player/video_player.dart';

class StoryPresenterMapper {
  const StoryPresenterMapper._();

  static StoryItem map(BuildContext context, StoryModel story) =>
      switch (story.type) {
        StoryType.image => _image(story),
        StoryType.video => _video(story),
        StoryType.text => _text(context, story),
        StoryType.audio => _audio(context, story),
      };

  static StoryItem _image(StoryModel story) {
    final source = _mediaSource(story);
    if (source == null) return _unavailableStory();

    return StoryItem(
      url: source.path,
      storyItemType: StoryItemType.image,
      storyItemSource: source.source,
      duration: const Duration(seconds: 5),
      imageConfig: StoryViewImageConfig(
        fit: BoxFit.cover,
        progressIndicatorBuilder: (_, _, loadProgress) =>
            const Center(child: CupertinoActivityIndicator()),
      ),
    );
  }

  static StoryItem _video(StoryModel story) {
    final source = _mediaSource(story);
    if (source == null) return _unavailableStory();

    if (source.source == StoryItemSource.file) {
      return StoryItem(
        storyItemType: StoryItemType.custom,
        duration: const Duration(seconds: 30),
        customWidget: (storyController, _) => _LocalVideoStoryContent(
          path: source.path,
          storyController: storyController,
        ),
      );
    }

    return StoryItem(
      url: source.path,
      storyItemType: StoryItemType.video,
      storyItemSource: source.source,
      videoConfig: const StoryViewVideoConfig(
        fit: BoxFit.cover,
        cacheVideo: true,
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

class _LocalVideoStoryContent extends StatefulWidget {
  const _LocalVideoStoryContent({
    required this.path,
    required this.storyController,
  });

  final String path;
  final FlutterStoryController? storyController;

  @override
  State<_LocalVideoStoryContent> createState() =>
      _LocalVideoStoryContentState();
}

class _LocalVideoStoryContentState extends State<_LocalVideoStoryContent> {
  VideoPlayerController? _videoController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    widget.storyController?.addListener(_syncPlayback);
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _LocalVideoStoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storyController != widget.storyController) {
      oldWidget.storyController?.removeListener(_syncPlayback);
      widget.storyController?.addListener(_syncPlayback);
    }
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.file(File(widget.path));
    _videoController = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      if (mounted && controller == _videoController) {
        setState(() => _hasError = true);
      }
      return;
    }

    if (!mounted || controller != _videoController) {
      await controller.dispose();
      return;
    }

    setState(() {});
    _syncPlayback();
  }

  void _syncPlayback() {
    final controller = _videoController;
    final action = widget.storyController?.storyStatus;
    if (controller == null || !controller.value.isInitialized) return;

    switch (action) {
      case StoryAction.pause:
        controller.pause();
        return;
      case StoryAction.play:
      case StoryAction.playCustomWidget:
        controller.play();
        return;
      case StoryAction.mute:
        controller.setVolume(0);
        return;
      case StoryAction.unMute:
        controller.setVolume(1);
        return;
      case StoryAction.next:
      case StoryAction.previous:
      case null:
        return;
    }
  }

  @override
  void dispose() {
    widget.storyController?.removeListener(_syncPlayback);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    if (_hasError) return const _UnavailableStoryContent();
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CupertinoActivityIndicator(color: Colors.white)),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
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
