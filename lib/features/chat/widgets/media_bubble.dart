import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/viewmodel/audio_manager.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class MediaBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const MediaBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final rawUrls = message.mediaUrls ?? [];
    if (rawUrls.isEmpty) return const SizedBox.shrink();

    final urls = rawUrls.whereType<String>().toList();

    final type = message.type;
    final mimeType = message.mimeType ?? '';
    final fileName = message.fileName ?? '';
    final isPdf =
        mimeType == 'application/pdf' ||
        mimeType == 'image/pdf' ||
        fileName.toLowerCase().endsWith('.pdf');

    final isSticker = type == MessageType.sticker;
    final isImage =
        !isPdf && (type == MessageType.image || mimeType.startsWith('image/'));
    final isVideo = type == MessageType.video || fileName.endsWith('.mp4');
    final isAudio =
        type == MessageType.audio ||
        fileName.endsWith('.mp3') ||
        mimeType == 'video/mp3' ||
        mimeType == 'audio/mp3' ||
        mimeType.startsWith('audio/');

    final bytesSizes = message.fileSizeBytes;

    if (isSticker) return _StickerMedia(urls: urls, isMe: isMe);
    if (isPdf) return _FileMedia(message: message, isMe: isMe);
    if (isImage)
      return _ImageMedia(caption: message.text, captions: message.mediaCaptions, urls: urls, isMe: isMe);
    if (isAudio)
      return _AudioMedia(urls: urls, isMe: isMe, byteSizes: bytesSizes);
    if (isVideo) return _VideoMedia(urls: urls, isMe: isMe);
    return _FileMedia(message: message, isMe: isMe);
  }
}

// ------------------------------------------------------------
// Image Media (Single or Multiple, scrollable)
// ------------------------------------------------------------
class _ImageMedia extends StatelessWidget {
  final String caption;
  final List<String>? captions;
  final List<String> urls;
  final bool isMe;
  const _ImageMedia({
    required this.urls,
    required this.caption,
    this.captions,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final count = urls.length;
    if (count == 1) {
      final c = captions?.isNotEmpty == true ? captions![0] : caption;
      return _buildSingleImage(context, urls.first, 0, caption: c);
    } else {
      final nonEmptyCaptions = captions?.where((c) => c.isNotEmpty).toList() ?? [];
      final effectiveCaption = nonEmptyCaptions.isNotEmpty ? nonEmptyCaptions.first : caption;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            _buildCollage(context, urls),
            if (effectiveCaption.isNotEmpty)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                  child: Text(
                    effectiveCaption,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }

  Widget _buildSingleImage(BuildContext context, String url, int index, {String caption = ''}) =>
      GestureDetector(
        onTap: () => _openFullscreen(context, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200.h,
                placeholder: (_, __) => const Center(child: LoadingIndicator()),
                errorWidget: (_, __, ___) => Container(
                  height: 200.h,
                  color: AppColors.grey,
                  child: const Icon(Icons.broken_image),
                ),
              ),
              if (caption.isNotEmpty)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Text(
                      caption,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _buildCollage(BuildContext context, List<String> urls) {
    final count = urls.length;
    if (count == 2) {
      return SizedBox(
        height: 150.h,
        child: Row(
          children: [
            Expanded(child: _buildCollageTile(context, urls[0], 0)),
            Gap(2.w),
            Expanded(child: _buildCollageTile(context, urls[1], 1)),
          ],
        ),
      );
    } else if (count == 3) {
      return Column(
        children: [
          SizedBox(
            height: 120.h,
            child: _buildCollageTile(context, urls[0], 0, fullWidth: true),
          ),
          Gap(2.h),
          SizedBox(
            height: 120.h,
            child: Row(
              children: [
                Expanded(child: _buildCollageTile(context, urls[1], 1)),
                Gap(2.w),
                Expanded(child: _buildCollageTile(context, urls[2], 2)),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          SizedBox(
            height: 100.h,
            child: Row(
              children: [
                Expanded(child: _buildCollageTile(context, urls[0], 0)),
                Gap(2.w),
                Expanded(child: _buildCollageTile(context, urls[1], 1)),
              ],
            ),
          ),
          Gap(2.h),
          SizedBox(
            height: 100.h,
            child: Row(
              children: [
                Expanded(child: _buildCollageTile(context, urls[2], 2)),
                Gap(2.w),
                Expanded(child: _buildCollageTile(context, urls[3], 3, last: count > 4)),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildCollageTile(BuildContext context, String url, int index, {bool fullWidth = false, bool last = false}) =>
      GestureDetector(
        onTap: () => _openFullscreen(context, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => const Center(child: LoadingIndicator()),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image),
                ),
              ),
              if (last)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: Text(
                      '+N',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  void _openFullscreen(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            FullScreenViewer(
              urls: urls,
              initialIndex: initialIndex,
              captions: captions ?? [caption],
            ),
      ),
    );
  }
}

// Fullscreen viewer with Hero and swipe to dismiss
class FullScreenViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final List<String> captions;
  const FullScreenViewer({
    super.key,
    required this.urls,
    required this.initialIndex,
    required this.captions,
  });

  @override
  State<FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<FullScreenViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        GestureDetector(
          onTap: _toggleControls,
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) => Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: widget.urls[index],
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        const Center(child: LoadingIndicator()),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ),
          ),
        ),
        if (_showControls) ...[
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (widget.urls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.urls.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          if (widget.captions.length > _currentIndex && widget.captions[_currentIndex].isNotEmpty)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 300.w),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.captions[_currentIndex],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    ),
  );
}

// ------------------------------------------------------------
// Placeholder for Video, Audio, File
// ------------------------------------------------------------
class _VideoMedia extends StatelessWidget {
  final List<String> urls;
  final bool isMe;
  const _VideoMedia({required this.urls, required this.isMe});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (urls.length > 1)
        Text('${urls.length} videos', style: textTheme.subDescription),
      Gap(6.h),
      if (urls.length == 1)
        _VideoTile(url: urls[0], isMe: isMe)
      else
        SizedBox(
          height: 180.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) =>
                _VideoTile(url: urls[index], isMe: isMe),
          ),
        ),
    ],
  );
}

class _VideoTile extends StatefulWidget {
  final String url;
  final bool isMe;
  const _VideoTile({required this.url, required this.isMe});

  @override
  State<StatefulWidget> createState() => _VideoTileState();
}

class _VideoTileState extends State<_VideoTile> {
  Uint8List? _thumbnail;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final result = await VideoThumbnail.thumbnailData(
      video: widget.url,
      imageFormat: ImageFormat.JPEG,
      quality: 75,
    );
    if (result != null) {
      final codec = await ui.instantiateImageCodec(result);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      setState(() {
        _thumbnail = result;
        _aspectRatio = (image.width / image.height);
      });
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(videoUrl: widget.url),
        ),
      );
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_thumbnail != null && _aspectRatio != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 240.w, maxHeight: 180.h),
              child: AspectRatio(
                aspectRatio: _aspectRatio!,
                child: Image.memory(_thumbnail!, fit: BoxFit.cover),
              ),
            )
          else
            Container(width: 160.w, height: 180.w, color: Colors.grey[800]),

          Container(
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(8.w),
            child: Icon(Icons.play_arrow, color: Colors.white, size: 36.sp),
          ),
        ],
      ),
    ),
  );
}

// Video player screen dengan kontrol manual (tanpa Chewie)
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _controller.initialize();
    _controller.addListener(_videoListener);
    setState(() {
      _isInitialized = true;
      _isPlaying = _controller.value.isPlaying;
    });
  }

  void _videoListener() {
    if (mounted && _controller.value.isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = _controller.value.isPlaying;
      });
    }
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          // Video player
          Center(
            child: _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const LoadingIndicator(),
          ),
          // Kontrol overlay
          if (_isInitialized && _showControls)
            Container(
              color: Colors.black54,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play/Pause button besar di tengah
                  IconButton(
                    iconSize: 64.w,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.white,
                    ),
                    onPressed: _togglePlay,
                  ),
                  const SizedBox(height: 8),
                  // Progress slider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(_controller.value.position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _controller.value.position.inSeconds
                                .toDouble(),
                            max: _controller.value.duration.inSeconds
                                .toDouble(),
                            onChanged: (value) {
                              _controller.seekTo(
                                Duration(seconds: value.toInt()),
                              );
                            },
                            activeColor: Colors.white,
                            inactiveColor: Colors.white30,
                          ),
                        ),
                        Text(
                          _formatDuration(_controller.value.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StickerMedia extends StatelessWidget {
  final List<String> urls;
  final bool isMe;
  const _StickerMedia({required this.urls, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final url = urls.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: SizedBox(
        width: 160.r,
        height: 160.r,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: Colors.grey.shade100,
          ),
          errorWidget: (_, __, ___) => Container(
            color: Colors.grey.shade100,
            child: Icon(Icons.sticky_note_2_outlined, color: Colors.grey.shade400),
          ),
        ),
      ),
    );
  }
}

class _AudioMedia extends StatelessWidget {
  final List<String> urls;
  final bool isMe;
  final int? byteSizes;
  const _AudioMedia({
    required this.urls,
    required this.isMe,
    this.byteSizes = 0,
  });
  @override
  Widget build(BuildContext context) {
    // Single audio or list
    return Column(
      children: urls
          .map((url) => _AudioTile(url: url, isMe: isMe, byteSizes: byteSizes))
          .toList(),
    );
  }
}

class _AudioTile extends StatefulWidget {
  final String url;
  final bool isMe;
  final int? byteSizes;
  const _AudioTile({required this.url, required this.isMe, this.byteSizes});

  @override
  State<StatefulWidget> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> with RouteAware {
  final _manager = AudioManager.instance;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Dengarkan perubahan posisi
    _manager.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    // Dengarkan perubahan durasi
    _manager.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur ?? Duration.zero);
    });
    // Dengarkan play/pause
    _manager.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying =
              state.playing &&
              _manager.currentUrl == widget.url; // ← hanya tile INI
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    if (_manager.currentUrl == widget.url) {
      _manager.stop();
    }
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    AudioManager.instance.stop(); // stop audio
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          color: AppColors.white.withValues(alpha: 0.3),
        ),
        padding: EdgeInsets.only(left: 2.w, right: 8.w),
        child: Row(
          children: [
            // Tombol play/pause
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: AppColors.white,
              ),
              onPressed: () {
                if (_isPlaying) {
                  _manager.pause();
                } else {
                  _manager.play(widget.url);
                }
              },
            ),
            // Slider
            Expanded(
              child: Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble(),
                onChanged: (val) {
                  // Seek ke posisi baru
                },
                activeColor: AppColors.primary,
              ),
            ),
            // Durasi
            Text(
              _formatDuration(_position),
              style: textTheme.subDescription2.copyWith(color: AppColors.white),
            ),
          ],
        ),
      ),
      if (widget.byteSizes != null && widget.byteSizes != 0)
        Text(formatBytes(widget.byteSizes!), style: textTheme.subDescription3),
    ],
  );
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _FileMedia extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _FileMedia({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final urls = message.mediaUrls ?? [];
    final thumbnails = message.thumbnailUrls;
    final fileName = message.fileName;
    final totalSize = message.fileSizeBytes;

    if (urls.isEmpty) return const SizedBox.shrink();

    if (urls.length == 1) {
      return _FileTile(
        url: urls.first,
        thumbnailUrl: thumbnails?.firstOrNull,
        name: fileName ?? 'File',
        size: totalSize,
        isMe: isMe,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${urls.length} files',
          style: textTheme.subDescription3.copyWith(
            color: isMe ? AppColors.white : AppColors.black,
          ),
        ),
        Gap(6.h),
        InkWell(
          onTap: () => _showMultipleFilesDialog(context, urls),
          child: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: isMe ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder),
                Gap(4.h),
                Expanded(
                  child: Text(
                    fileName ?? '${urls.length} files',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (totalSize != null)
                  Text(
                    formatBytes(totalSize),
                    style: TextStyle(fontSize: 12, color: AppColors.grey),
                  ),

                Icon(Icons.chevron_right, size: 20.sp, color: AppColors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showMultipleFilesDialog(BuildContext context, List<dynamic> urls) {
    final thumbnails = message.thumbnailUrls;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File List',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: urls.length,
                separatorBuilder: (_, __) => Gap(8.h),
                itemBuilder: (context, index) {
                  final fileUrl = urls[index].toString();
                  final originalName = extractFileNameFromUrl(fileUrl);
                  return _FileTile(
                    url: urls[index].toString(),
                    thumbnailUrl: thumbnails?[index],
                    name: originalName,
                    isMe: false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String extractFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);

      final lastSegment = uri.pathSegments.last;

      final decodedName = Uri.decodeComponent(lastSegment);

      return decodedName.split('/').last;
    } catch (e) {
      // Kalau gagal dibongkar, pakai nama darurat
      return 'Unknown_File';
    }
  }
}

class _FileTile extends StatefulWidget {
  final String url;
  final String name;
  final int? size;
  final bool isMe;
  final String? thumbnailUrl;

  const _FileTile({
    required this.url,
    required this.name,
    this.size,
    required this.isMe,
    this.thumbnailUrl,
  });

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  Future<void> _downloadAndOpen() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.name}');
      final mimeType = _getMimeType(widget.url);

      if (await file.exists()) {
        print('=============================================');
        print('MIME TYPE: ${mimeType}');
        print('=============================================');
        await OpenFile.open(file.path, type: mimeType);
        if (mounted) setState(() => _isDownloading = false);
        return;
      }

      final dio = Dio();
      await dio.download(
        widget.url,
        file.path,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      await OpenFile.open(file.path, type: mimeType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed opening file: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      // Dokumen
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      // Gambar
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';

      // Video
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';

      // Audio
      case 'mp3':
        return 'audio/mpeg';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';

      default:
        return '*/*';
    }
  }

  IconData _getFileIcon(String name) {
    if (!name.contains('.')) return Icons.insert_drive_file;

    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Icons.audiotrack;
      case 'mp4':
      case 'mkv':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thumbnailUrl != null) {
      return _buildThumbnailPreview();
    }
    return _buildIconTile();
  }

  Widget _buildThumbnailPreview() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: _downloadAndOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: widget.thumbnailUrl!,
                height: 100.h,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 100.h,
                  color: Colors.grey[300],
                  child: const Center(child: LoadingIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 100.h,
                  color: Colors.grey[300],
                  child: Icon(
                    Icons.picture_as_pdf,
                    size: 48.w,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.white,
                    size: 20.w,
                  ),
                ),
              ),
              if (_isDownloading)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
      Gap(8.h),
      GestureDetector(
        onTap: _downloadAndOpen,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: textTheme.subDescription2.copyWith(
                      color: widget.isMe ? Colors.white : AppColors.black,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Gap(2.h),
                  if (widget.size != null && !_isDownloading)
                    Text(
                      formatBytes(widget.size ?? 0),
                      style: textTheme.subDescription3.copyWith(
                        color: widget.isMe ? Colors.white : AppColors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              _isDownloading ? Icons.hourglass_empty : Icons.download,
              color: widget.isMe ? Colors.white70 : AppColors.grey,
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildIconTile() => GestureDetector(
    onTap: _downloadAndOpen,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.white24 : Colors.black12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(widget.name),
            size: 32,
            color: widget.isMe ? Colors.white70 : AppColors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: textTheme.subDescription3.copyWith(
                    color: widget.isMe ? Colors.white : AppColors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.size != null && !_isDownloading)
                  Text(
                    formatBytes(widget.size!),
                    style: textTheme.subDescription3.copyWith(
                      color: widget.isMe ? Colors.white : AppColors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (_isDownloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            _isDownloading ? Icons.hourglass_empty : Icons.download,
            color: widget.isMe ? Colors.white70 : AppColors.grey,
          ),
        ],
      ),
    ),
  );
}
