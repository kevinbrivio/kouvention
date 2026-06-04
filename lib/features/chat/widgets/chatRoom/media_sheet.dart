import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/utils/message_label.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/media/media_picker_helper.dart';
import 'package:kouvention/features/chat/viewmodel/media/media_preview_viewmodel.dart';
import 'package:path_provider/path_provider.dart';

class _MediaOption {
  final IconData icon;
  final String label;
  final Color circleColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _MediaOption({
    required this.icon,
    required this.label,
    required this.circleColor,
    required this.iconColor,
    required this.onTap,
  });
}

class MediaSheet extends ConsumerStatefulWidget {
  final ChatRoomVM vm;
  const MediaSheet({super.key, required this.vm});

  @override
  ConsumerState<MediaSheet> createState() => _MediaSheetState();
}

class _MediaSheetState extends ConsumerState<MediaSheet> {
  List<Message>? _recentMedia;

  @override
  void initState() {
    super.initState();
    _loadRecentMedia();
  }

  Future<void> _loadRecentMedia() async {
    final db = ref.read(messageDatabaseProvider);
    final media = await db.getRecentMediaMessages(limit: 10);
    if (mounted) {
      setState(() => _recentMedia = media);
    }
  }

  Future<void> _onRecentMediaTap(Message msg) async {
    final urls = msg.mediaUrls;
    final imageUrl = urls != null && urls.isNotEmpty ? urls.first : null;
    if (imageUrl == null || imageUrl.isEmpty) return;

    final router = GoRouter.of(navigatorKey.currentContext!);

    try {
      final dir = await getTemporaryDirectory();
      final ext = imageUrl.split('.').last.split('?').first;
      final file = File(
        '${dir.path}/recent_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );

      if (!await file.exists()) {
        final dio = Dio();
        await dio.download(imageUrl, file.path);
      }

      widget.vm.closeMediaPanel();

      final type = msg.type == MessageType.video.name
          ? MessageType.video
          : MessageType.image;

      router.pushNamed(
        RouterRoutes.mediaPreview.name,
        pathParameters: {'chatId': widget.vm.chatId},
        extra: MediaPreviewArgs(
          files: [file],
          mediaType: type,
          chatId: widget.vm.chatId,
          onSend: (result, caption) =>
              widget.vm.sendMediaMessage(files: result),
        ),
      );
    } catch (e) {
      widget.vm.closeMediaPanel();
      debugPrint('Failed to download recent media: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaPickerHelper = ref.read(mediaPickerHelperProvider);
    final options = _buildOptions(context, mediaPickerHelper);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      padding: EdgeInsets.only(top: 6.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 350.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_recentMedia != null && _recentMedia!.isNotEmpty)
                _buildRecentGallery(),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 4.w,
                childAspectRatio: 0.85,
                children: options
                    .map((option) => _buildMediaItem(option, context))
                    .toList(),
              ),
              Gap(8.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentGallery() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: 80.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: _recentMedia!.length,
          separatorBuilder: (_, __) => Gap(6.w),
          itemBuilder: (_, i) {
            final msg = _recentMedia![i];
            final urls = msg.mediaUrls;
            final imageUrl = urls != null && urls.isNotEmpty
                ? urls.first
                : null;
            if (imageUrl == null) return const SizedBox.shrink();

            final isVideo = msg.type == MessageType.video.name;
            final displayUrl =
                isVideo ? getCloudinaryThumbnail(imageUrl) : imageUrl;

            return GestureDetector(
              onTap: () => _onRecentMediaTap(msg),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CachedNetworkImage(
                      imageUrl: displayUrl,
                      width: 80.h,
                      height: 80.h,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 80.h,
                        height: 80.h,
                        color: Colors.grey.shade100,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 80.h,
                        height: 80.h,
                        color: Colors.grey.shade100,
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                    if (isVideo)
                      Container(
                        width: 28.w,
                        height: 28.w,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 18.w,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      Divider(height: 1.h, color: Colors.grey.shade200),
    ],
  );

  Widget _buildMediaItem(_MediaOption option, BuildContext context) =>
      GestureDetector(
        onTap: option.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: option.circleColor,
                shape: BoxShape.circle,
              ),
              child: Icon(option.icon, color: option.iconColor, size: 22.w),
            ),
            Gap(6.h),
            Text(
              option.label,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      );

  List<_MediaOption> _buildOptions(
    BuildContext context,
    MediaPickerHelper mediaPickerHelper,
  ) => [
    _MediaOption(
      icon: Icons.photo_library_outlined,
      label: 'Photos',
      circleColor: const Color(0xFFEDE7F6),
      iconColor: const Color(0xFF7C4DFF),
      onTap: () async {
        final pickedFiles = await mediaPickerHelper.pickMultipleImages();
        if (pickedFiles.isEmpty) return;
        if (!context.mounted) return;
        final router = GoRouter.of(context);
        widget.vm.closeMediaPanel();

        router.pushNamed(
          RouterRoutes.mediaPreview.name,
          pathParameters: {'chatId': widget.vm.chatId},
          extra: MediaPreviewArgs(
            files: pickedFiles,
            mediaType: MessageType.image,
            chatId: widget.vm.chatId,
            onSend: (result, caption) {
              return widget.vm.sendMediaMessage(files: result);
            },
          ),
        );
      },
    ),
    _MediaOption(
      icon: Icons.camera_alt_outlined,
      label: 'Camera',
      circleColor: const Color(0xFFFCE4EC),
      iconColor: const Color(0xFFE91E63),
      onTap: () async {
        final img = await mediaPickerHelper.pickImage(fromGallery: false);
        if (img == null) return;

        if (!context.mounted) return;
        final router = GoRouter.of(context);
        widget.vm.closeMediaPanel();

        router.pushNamed(
          RouterRoutes.mediaPreview.name,
          pathParameters: {'chatId': widget.vm.chatId},
          extra: MediaPreviewArgs(
            files: [img],
            mediaType: MessageType.image,
            chatId: widget.vm.chatId,
            onSend: (result, caption) =>
                widget.vm.sendMediaMessage(files: result),
          ),
        );
      },
    ),
    _MediaOption(
      icon: Icons.video_library_outlined,
      label: 'Videos',
      circleColor: const Color(0xFFE0F2F1),
      iconColor: const Color(0xFF00897B),
      onTap: () async {
        final pickedFiles = await mediaPickerHelper.pickMultipleVideos(
          fromCamera: false,
        );
        if (pickedFiles.isEmpty) return;
        if (!context.mounted) return;
        final router = GoRouter.of(context);
        widget.vm.closeMediaPanel();

        router.pushNamed(
          RouterRoutes.mediaPreview.name,
          pathParameters: {'chatId': widget.vm.chatId},
          extra: MediaPreviewArgs(
            files: pickedFiles,
            mediaType: MessageType.video,
            chatId: widget.vm.chatId,
            onSend: (result, caption) =>
                widget.vm.sendMediaMessage(files: result),
          ),
        );
      },
    ),
    _MediaOption(
      icon: Icons.insert_drive_file_outlined,
      label: 'Document',
      circleColor: const Color(0xFFE3F2FD),
      iconColor: const Color(0xFF1E88E5),
      onTap: () async {
        final pickedFiles = await mediaPickerHelper.pickMultipleFiles();
        if (pickedFiles.isEmpty) return;
        if (!context.mounted) return;
        final router = GoRouter.of(context);
        widget.vm.closeMediaPanel();

        router.pushNamed(
          RouterRoutes.mediaPreview.name,
          pathParameters: {'chatId': widget.vm.chatId},
          extra: MediaPreviewArgs(
            files: pickedFiles,
            mediaType: MessageType.file,
            chatId: widget.vm.chatId,
            onSend: (result, caption) =>
                widget.vm.sendMediaMessage(files: result),
          ),
        );
      },
    ),
    _MediaOption(
      icon: Icons.mic_outlined,
      label: 'Audio',
      circleColor: const Color(0xFFFFF3E0),
      iconColor: const Color(0xFFFB8C00),
      onTap: () async {
        final picked = await mediaPickerHelper.pickAudio();
        if (picked == null) return;
        if (!context.mounted) return;
        final router = GoRouter.of(context);
        widget.vm.closeMediaPanel();

        router.pushNamed(
          RouterRoutes.mediaPreview.name,
          pathParameters: {'chatId': widget.vm.chatId},
          extra: MediaPreviewArgs(
            files: [picked],
            mediaType: MessageType.audio,
            chatId: widget.vm.chatId,
            onSend: (result, caption) =>
                widget.vm.sendMediaMessage(files: result),
          ),
        );
      },
    ),
    _MediaOption(
      icon: Icons.location_on_outlined,
      label: 'Location',
      circleColor: const Color(0xFFE8F5E9),
      iconColor: const Color(0xFF43A047),
      onTap: () {
        // TODO: location
      },
    ),
  ];
}
