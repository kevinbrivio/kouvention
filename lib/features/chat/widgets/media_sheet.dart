import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/media_preview_viewmodel.dart';
import 'package:kouvention/features/chat/views/chat_room_view.dart';

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

class MediaSheet extends ConsumerWidget {
  final ChatRoomVM vm;
  const MediaSheet({super.key, required this.vm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = _buildOptions(context, vm);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),

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
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      width: 36.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2.r),
      ),
    ),
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

  List<_MediaOption> _buildOptions(BuildContext context, ChatRoomVM vm) => [
    _MediaOption(
      icon: Icons.photo_library_outlined,
      label: 'Photos & video',
      circleColor: const Color(0xFFEDE7F6),
      iconColor: const Color(0xFF7C4DFF),
      onTap: () async {
        final pickedFiles = await vm.pickMultipleImages();
        if (pickedFiles.isEmpty) return;
        if (!context.mounted) return;
        final router = GoRouter.of(context);
        Navigator.pop(context);

        router.pushNamed(
          RouterRoutes.mediaPreview.name,
          pathParameters: {'chatId': vm.chatId},
          extra: MediaPreviewArgs(
            files: pickedFiles,
            mediaType: MessageType.image,
            chatId: vm.chatId,
            onSend: (result, caption) =>
                vm.sendMediaMessage(result: result, caption: caption ?? ''),
          ),
        );
      },
    ),
    _MediaOption(
      icon: Icons.camera_alt_outlined,
      label: 'Camera',
      circleColor: const Color(0xFFFCE4EC),
      iconColor: const Color(0xFFE91E63),
      onTap: () {
        vm.pickImage(fromCamera: true);
      },
    ),
    _MediaOption(
      icon: Icons.insert_drive_file_outlined,
      label: 'Document',
      circleColor: const Color(0xFFE3F2FD),
      iconColor: const Color(0xFF1E88E5),
      onTap: () {
        Navigator.pop(context);
        // TODO: file_picker
      },
    ),
    _MediaOption(
      icon: Icons.mic_outlined,
      label: 'Audio',
      circleColor: const Color(0xFFFFF3E0),
      iconColor: const Color(0xFFFB8C00),
      onTap: () {
        Navigator.pop(context);
        // TODO: audio picker
      },
    ),
    _MediaOption(
      icon: Icons.location_on_outlined,
      label: 'Location',
      circleColor: const Color(0xFFE8F5E9),
      iconColor: const Color(0xFF43A047),
      onTap: () {
        Navigator.pop(context);
        // TODO: location
      },
    ),
    _MediaOption(
      icon: Icons.person_outline,
      label: 'Contact',
      circleColor: const Color(0xFFE0F2F1),
      iconColor: const Color(0xFF00897B),
      onTap: () {
        Navigator.pop(context);
        // TODO: contact picker
      },
    ),
  ];
}
