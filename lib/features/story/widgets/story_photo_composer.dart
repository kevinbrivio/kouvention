import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/chat/services/media/media_picker_service.dart';
import 'package:kouvention/features/story/widgets/story_caption_field.dart';
import 'package:oktoast/oktoast.dart';

class StoryPhotoComposer extends ConsumerStatefulWidget {
  const StoryPhotoComposer({
    super.key,
    required this.isActive,
    required this.photo,
    required this.captionController,
    required this.isPublishing,
    required this.onPhotoSelected,
    required this.onPublish,
  });

  final bool isActive;
  final File? photo;
  final TextEditingController captionController;
  final bool isPublishing;
  final ValueChanged<File?> onPhotoSelected;
  final VoidCallback onPublish;

  @override
  ConsumerState<StoryPhotoComposer> createState() => _StoryPhotoComposerState();
}

class _StoryPhotoComposerState extends ConsumerState<StoryPhotoComposer>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  int _initializationToken = 0;
  bool _isInitializing = false;
  bool _isCapturing = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive && widget.photo == null) {
      unawaited(_initializeCamera());
    }
  }

  @override
  void didUpdateWidget(covariant StoryPhotoComposer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isActive || widget.photo != null) {
      unawaited(_disposeCamera());
    } else if (!oldWidget.isActive || oldWidget.photo != null) {
      unawaited(_initializeCamera());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive || widget.photo != null) return;

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
    unawaited(_controller?.dispose());
    super.dispose();
  }

  Future<void> _initializeCamera({int? cameraIndex}) async {
    if (_isInitializing || !widget.isActive || widget.photo != null) return;

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
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted ||
          token != _initializationToken ||
          !widget.isActive ||
          widget.photo != null) {
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
    final controller = _controller;
    _controller = null;
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
    await controller?.dispose();
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final captured = await controller.takePicture();
      await _disposeCamera();
      widget.onPhotoSelected(File(captured.path));
    } on CameraException {
      showToast('Could not take the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ref
          .read(mediaPickerServiceProvider)
          .pickImage(fromGallery: true);
      if (picked == null) return;

      await _disposeCamera();
      widget.onPhotoSelected(File(picked.path));
    } catch (_) {
      showToast('Could not open the photo gallery.');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializing) return;
    await _disposeCamera();
    await _initializeCamera(cameraIndex: (_cameraIndex + 1) % _cameras.length);
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    if (photo != null) return _buildPhotoPreview(photo);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CameraAction(
                  tooltip: 'Gallery',
                  icon: Icons.photo_library_outlined,
                  onPressed: _pickFromGallery,
                ),
                GestureDetector(
                  onTap: _isCapturing ? null : _capturePhoto,
                  child: Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _isCapturing ? Colors.white54 : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                _CameraAction(
                  tooltip: 'Switch camera',
                  icon: Icons.cameraswitch_outlined,
                  onPressed: _cameras.length > 1 ? _switchCamera : null,
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
          aspectRatio: controller.value.aspectRatio,
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
                Icons.no_photography_outlined,
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

  Widget _buildPhotoPreview(File photo) => ColoredBox(
    color: Colors.black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.file(photo, fit: BoxFit.contain),
        Positioned(
          left: 24.w,
          right: 24.w,
          bottom:
              MediaQuery.of(context).padding.bottom +
              MediaQuery.of(context).viewInsets.bottom +
              24.h,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoryCaptionField(
                controller: widget.captionController,
                enabled: !widget.isPublishing,
              ),
              Gap(AppSpacing.lg.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CameraAction(
                    tooltip: 'Gallery',
                    icon: Icons.photo_library_outlined,
                    onPressed: widget.isPublishing ? null : _pickFromGallery,
                  ),
                  _CameraAction(
                    tooltip: 'Retake',
                    icon: Icons.camera_alt_outlined,
                    onPressed: widget.isPublishing
                        ? null
                        : () => widget.onPhotoSelected(null),
                  ),
                  _CameraAction(
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

  String _cameraErrorMessage(CameraException error) => switch (error.code) {
    'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
      'Camera permission is required. '
          'You can still choose a photo from Gallery.',
    'CameraAccessRestricted' =>
      'Camera access is restricted on this device. '
          'You can still choose a photo from Gallery.',
    _ => 'Camera is unavailable. You can still choose a photo from Gallery.',
  };
}

class _CameraAction extends StatelessWidget {
  const _CameraAction({
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
