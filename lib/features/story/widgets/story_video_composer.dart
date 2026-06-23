import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/services/media/media_picker_service.dart';
import 'package:kouvention/features/chat/widgets/preview/video_preview.dart';
import 'package:kouvention/features/story/widgets/story_caption_field.dart';
import 'package:oktoast/oktoast.dart';

const storyVideoMaxDuration = Duration(seconds: 30);

class StoryVideoComposer extends ConsumerStatefulWidget {
  const StoryVideoComposer({
    super.key,
    required this.isActive,
    required this.video,
    required this.captionController,
    required this.isPublishing,
    required this.onVideoSelected,
    required this.onPublish,
  });

  final bool isActive;
  final File? video;
  final TextEditingController captionController;
  final bool isPublishing;
  final ValueChanged<File?> onVideoSelected;
  final VoidCallback onPublish;

  @override
  ConsumerState<StoryVideoComposer> createState() => _StoryVideoComposerState();
}

class _StoryVideoComposerState extends ConsumerState<StoryVideoComposer>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  Timer? _recordingTimer;
  int _cameraIndex = 0;
  int _initializationToken = 0;
  Duration _recordingDuration = Duration.zero;
  bool _isInitializing = false;
  bool _isRecording = false;
  bool _isStoppingRecording = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive && widget.video == null) {
      unawaited(_initializeCamera());
    }
  }

  @override
  void didUpdateWidget(covariant StoryVideoComposer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if ((!widget.isActive || widget.video != null) &&
        oldWidget.isActive &&
        oldWidget.video == null) {
      unawaited(_disposeCamera());
    } else if (!oldWidget.isActive || oldWidget.video != null) {
      unawaited(_initializeCamera());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive || widget.video != null) return;

    if (state == AppLifecycleState.inactive) {
      unawaited(_disposeCamera());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initializeCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initializationToken++;
    _recordingTimer?.cancel();
    unawaited(_controller?.dispose());
    super.dispose();
  }

  Future<void> _initializeCamera({int? cameraIndex}) async {
    if (_isInitializing || !widget.isActive || widget.video != null) return;

    final token = ++_initializationToken;
    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });

    try {
      final cameras = _cameras.isEmpty ? await availableCameras() : _cameras;
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera is available.');
      }

      final requestedIndex = cameraIndex ?? _backCameraIndex(cameras);
      final nextIndex = requestedIndex.clamp(0, cameras.length - 1);
      final controller = CameraController(
        cameras[nextIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();

      if (!mounted ||
          token != _initializationToken ||
          !widget.isActive ||
          widget.video != null) {
        await controller.dispose();
        return;
      }

      final previous = _controller;
      setState(() {
        _cameras = cameras;
        _cameraIndex = nextIndex;
        _controller = controller;
        _isInitializing = false;
      });
      await previous?.dispose();
    } on CameraException catch (error) {
      if (!mounted || token != _initializationToken) return;
      setState(() {
        _isInitializing = false;
        _cameraError = _cameraErrorMessage(error);
      });
    } catch (_) {
      if (!mounted || token != _initializationToken) return;
      setState(() {
        _isInitializing = false;
        _cameraError = 'Camera is unavailable.';
      });
    }
  }

  int _backCameraIndex(List<CameraDescription> cameras) {
    final index = cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    return index < 0 ? 0 : index;
  }

  Future<void> _disposeCamera() async {
    _initializationToken++;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final controller = _controller;
    _controller = null;

    if (controller?.value.isRecordingVideo == true) {
      try {
        await controller?.stopVideoRecording();
      } on CameraException {
        // Discard an interrupted recording.
      }
    }
    await controller?.dispose();

    if (mounted) {
      setState(() {
        _isInitializing = false;
        _isRecording = false;
        _isStoppingRecording = false;
        _recordingDuration = Duration.zero;
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isStoppingRecording) return;

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isRecordingVideo) {
      return;
    }

    try {
      await controller.startVideoRecording();
      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final next = _recordingDuration + const Duration(seconds: 1);
        if (next >= storyVideoMaxDuration) {
          unawaited(_stopRecording());
        } else {
          setState(() => _recordingDuration = next);
        }
      });
    } on CameraException {
      showToast('Could not start recording. Please try again.');
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (_isStoppingRecording ||
        controller == null ||
        !controller.value.isRecordingVideo) {
      return;
    }

    setState(() => _isStoppingRecording = true);
    _recordingTimer?.cancel();
    _recordingTimer = null;
    try {
      final captured = await controller.stopVideoRecording();
      if (!mounted) return;
      widget.onVideoSelected(File(captured.path));
    } on CameraException {
      showToast('Could not save the video. Please try again.');
    } finally {
      if (mounted && widget.video == null) {
        setState(() => _isStoppingRecording = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ref
          .read(mediaPickerServiceProvider)
          .pickVideo(maxDuration: storyVideoMaxDuration);
      if (picked == null) return;

      if (!mounted) return;
      widget.onVideoSelected(File(picked.path));
    } catch (_) {
      showToast('Could not open the video gallery.');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializing || _isRecording) return;
    await _disposeCamera();
    await _initializeCamera(cameraIndex: (_cameraIndex + 1) % _cameras.length);
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    if (video != null) return _buildVideoPreview(video);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          if (_isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _VideoAction(
                  tooltip: 'Gallery',
                  icon: Icons.video_library_outlined,
                  onPressed: _isRecording ? null : _pickFromGallery,
                ),
                GestureDetector(
                  onTap: _isStoppingRecording ? null : _toggleRecording,
                  child: Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _isRecording ? 32 : 62,
                        height: _isRecording ? 32 : 62,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: _isRecording
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          borderRadius: _isRecording
                              ? BorderRadius.circular(6)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                _VideoAction(
                  tooltip: 'Switch camera',
                  icon: Icons.cameraswitch_outlined,
                  onPressed: _cameras.length > 1 && !_isRecording
                      ? _switchCamera
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: CameraPreview(controller),
        ),
      );
    }

    final error = _cameraError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _initializeCamera,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _buildVideoPreview(File video) => ColoredBox(
    color: Colors.black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        VideoPreview(file: video),
        Positioned(
          left: 24,
          right: 24,
          bottom:
              MediaQuery.of(context).padding.bottom +
              MediaQuery.of(context).viewInsets.bottom +
              24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoryCaptionField(
                controller: widget.captionController,
                enabled: !widget.isPublishing,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _VideoAction(
                    tooltip: 'Gallery',
                    icon: Icons.video_library_outlined,
                    onPressed: widget.isPublishing ? null : _pickFromGallery,
                  ),
                  _VideoAction(
                    tooltip: 'Retake',
                    icon: Icons.videocam_outlined,
                    onPressed: widget.isPublishing
                        ? null
                        : () => widget.onVideoSelected(null),
                  ),
                  _VideoAction(
                    tooltip: 'Publish story',
                    icon: Icons.send_rounded,
                    isLoading: widget.isPublishing,
                    onPressed: widget.isPublishing ? null : widget.onPublish,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds.toString().padLeft(2, '0');
    return '00:$seconds / 00:${storyVideoMaxDuration.inSeconds}';
  }

  String _cameraErrorMessage(CameraException error) => switch (error.code) {
    'CameraAccessDenied' ||
    'CameraAccessDeniedWithoutPrompt' ||
    'AudioAccessDenied' =>
      'Camera and microphone permission are required. '
          'You can still choose a video from Gallery.',
    'CameraAccessRestricted' || 'AudioAccessRestricted' =>
      'Camera or microphone access is restricted. '
          'You can still choose a video from Gallery.',
    _ => 'Camera is unavailable. You can still choose a video from Gallery.',
  };
}

class _VideoAction extends StatelessWidget {
  const _VideoAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.black45,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.black26,
      disabledForegroundColor: Colors.white38,
      minimumSize: const Size.square(52),
    ),
    icon: isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
        : Icon(icon),
  );
}
