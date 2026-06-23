import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:video_player/video_player.dart';

class VideoPreview extends StatefulWidget {
  const VideoPreview({super.key, required this.file, this.repeat = true});

  final File file;
  final bool repeat;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _replaceController();
    } else if (oldWidget.repeat != widget.repeat) {
      _controller.setLooping(widget.repeat);
    }
  }

  Future<void> _initializeController() async {
    final controller = VideoPlayerController.file(widget.file);
    _controller = controller;
    await controller.initialize();
    await controller.setLooping(widget.repeat);

    if (!mounted || controller != _controller) {
      await controller.dispose();
      return;
    }

    setState(() => _initialized = true);
    await controller.play();
  }

  Future<void> _replaceController() async {
    final previous = _controller;
    setState(() => _initialized = false);
    await _initializeController();
    await previous.dispose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: LoadingIndicator());
    }
    return GestureDetector(
      onTap: () => _controller.value.isPlaying
          ? _controller.pause()
          : _controller.play(),
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}
