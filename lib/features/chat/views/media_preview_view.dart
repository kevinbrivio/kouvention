import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/widgets/preview/audio_preview.dart';
import 'package:kouvention/features/chat/widgets/preview/document_preview.dart';
import 'package:kouvention/features/chat/widgets/preview/image_preview.dart';
import 'package:kouvention/features/chat/widgets/preview/video_preview.dart';

class MediaPreviewView extends ConsumerStatefulWidget {
  final String chatId;
  final MediaPreviewArgs args;
  MediaPreviewView({super.key, required this.chatId, required this.args});

  @override
  ConsumerState<MediaPreviewView> createState() => _MediaPreviewViewState();
}

class _MediaPreviewViewState extends ConsumerState<MediaPreviewView> {
  late PageController _pageController;
  late TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _captionController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(mediaPreviewProvider(widget.args));

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: _buildAppBar(context, vm),
      body: Column(
        children: [
          Expanded(child: _buildCarousel(vm)),

          _buildThumbnailStrip(vm),
          _buildCaptionBar(context, vm),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, MediaPreviewVM vm) =>
      AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _titleFromType(vm.type),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          if (vm.type == MessageType.image)
            IconButton(
              icon: const Icon(Icons.crop_rotate_rounded, color: Colors.white),
              onPressed: () async {
                await vm.cropImage(vm.currentFile.path);
              },
            ),
        ],
      );

  Widget _buildCaptionBar(BuildContext context, MediaPreviewVM vm) => Container(
    color: Colors.black,
    padding: EdgeInsets.fromLTRB(12.w, 8.h, 8.w, 24.h),
    child: Row(
      children: [
        // Caption field
        Expanded(
          child: TextField(
            controller: _captionController,
            onChanged: (value) {
              final currentFile = vm.files[vm.currentIndex];
              vm.onCaptionChanged(currentFile.path, value);
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a caption...',
              hintStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24.r),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white12,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 10.h,
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),

        // Send button
        GestureDetector(
          onTap: vm.isSending ? null : () => vm.send(context),
          child: CircleAvatar(
            radius: 24.r,
            backgroundColor: AppColors.primary,
            child: vm.isSending
                ? SizedBox(
                    width: 20.sp,
                    height: 20.sp,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.send, color: Colors.white, size: 20.sp),
          ),
        ),
      ],
    ),
  );

  // ─── Carousel ────────────────────────────────────────────
  Widget _buildCarousel(MediaPreviewVM vm) => PageView.builder(
    controller: _pageController,
    itemCount: vm.files.length,
    // Saat user swipe → update index di VM
    onPageChanged: (index) {
      final currFile = vm.files[index];
      _captionController.text = vm.captionFor(currFile.path);

      _captionController.selection = TextSelection.fromPosition(
        TextPosition(offset: _captionController.text.length),
      );
    },
    itemBuilder: (_, index) => _buildPreviewItem(vm.files[index]),
  );

  // Tentukan widget preview berdasarkan ekstensi file
  Widget _buildPreviewItem(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
    final isAudio = ['mp3', 'm4a'].contains(ext);
    final isDocument = ['pdf', 'xlxs', 'docx', 'doc'].contains(ext);

    if (isAudio) return AudioPreview(file: file);
    if (isVideo) return VideoPreview(file: file);
    if (isDocument) return DocumentPreview(file: file);
    return ImagePreview(file: file);
  }

  // ─── Thumbnail Strip ─────────────────────────────────────
  Widget _buildThumbnailStrip(MediaPreviewVM vm) {
    if (vm.files.length <= 1) return const SizedBox.shrink();

    return Container(
      height: 72.h,
      color: Colors.black,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: vm.files.length + 1,
        itemBuilder: (_, index) {
          if (index == vm.files.length) return _buildAddButton(vm);
          return _buildThumbnailItem(vm, index);
        },
      ),
    );
  }

  Widget _buildThumbnailItem(MediaPreviewVM vm, int index) {
    final isSelected = vm.currentIndex == index;

    return GestureDetector(
      onTap: () {
        vm.goToIndex(index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52.w,
        height: 52.w,
        margin: EdgeInsets.only(right: 6.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (vm.type == MessageType.file)
                Icon(Icons.document_scanner_rounded),

              if (vm.type == MessageType.image)
                Image.file(vm.files[index], fit: BoxFit.cover)
              else
                Center(
                  child: Icon(
                    // pilih icon sesuai tipe
                    vm.type == MessageType.video
                        ? Icons.videocam
                        : vm.type == MessageType.audio
                        ? Icons.audiotrack
                        : Icons.description,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

              if (!isSelected)
                Container(color: Colors.black.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(MediaPreviewVM vm) => GestureDetector(
    onTap: () async {
      final chatRoomProvider = ref.read(chatRoomVM(widget.chatId));
      switch (vm.type) {
        case MessageType.image:
          final newImg = await chatRoomProvider.pickImage(fromCamera: false);
          if (newImg == null) return;

          vm.addFile(newImg);
        case MessageType.audio:
          break;
        // final newAudio = await chatRoomProvider.();
        // if (newAudio == null) return;
        // vm.addFile(newAudio);
        case MessageType.video:
          final newVideo = await chatRoomProvider.pickVideo(fromCamera: false);
          if (newVideo == null) return;
          vm.addFile(newVideo);
        case MessageType.file:
          final newFile = await chatRoomProvider.pickFile();
          if (newFile == null) return;
          vm.addFile(newFile);
        case MessageType.text:
          break;
        case MessageType.media:
          break;
      }
    },
    child: Container(
      width: 52.w,
      height: 52.w,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Icon(Icons.add, color: Colors.white, size: 20.w),
    ),
  );

  String _titleFromType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'Photo';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Audio';
      case MessageType.file:
        return 'Document';
      case MessageType.text:
        return 'Document';
      case MessageType.media:
        return 'Media';
    }
  }
}
