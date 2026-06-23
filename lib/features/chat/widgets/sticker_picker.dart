import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/features/chat/models/sticker_model.dart';
import 'package:kouvention/features/chat/services/sticker_service.dart';

class StickerPicker extends ConsumerStatefulWidget {
  final Function(StickerModel) onStickerSelected;

  const StickerPicker({super.key, required this.onStickerSelected});

  @override
  ConsumerState<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends ConsumerState<StickerPicker> {
  int _selectedPackIndex = 0;

  @override
  Widget build(BuildContext context) {
    final packs = ref.read(stickerServiceProvider).getStickerPacks();
    if (packs.isEmpty) return const SizedBox.shrink();

    final activePack = packs[_selectedPackIndex];

    return Column(
      children: [
        _buildPackTabs(packs),
        Expanded(child: _buildStickerGrid(activePack.stickers)),
      ],
    );
  }

  Widget _buildPackTabs(List<StickerPack> packs) => Container(
    height: 56.h,
    padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
      itemCount: packs.length,
      separatorBuilder: (_, __) => Gap(AppSpacing.xs.w),
      itemBuilder: (context, index) {
        final pack = packs[index];
        final isSelected = index == _selectedPackIndex;

        return GestureDetector(
          onTap: () => setState(() => _selectedPackIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
            child: Center(
              child: Text(pack.icon, style: TextStyle(fontSize: 22.sp)),
            ),
          ),
        );
      },
    ),
  );

  Widget _buildStickerGrid(List<StickerModel> stickers) => GridView.builder(
    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      crossAxisSpacing: AppSpacing.xs.w,
      mainAxisSpacing: AppSpacing.xs.h,
      childAspectRatio: 1,
    ),
    itemCount: stickers.length,
    itemBuilder: (context, index) {
      final sticker = stickers[index];
      return GestureDetector(
        onTap: () => widget.onStickerSelected(sticker),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          child: CachedNetworkImage(
            imageUrl: sticker.url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: Colors.grey.shade100,
              child: const LoadingIndicator(),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey.shade100,
              child: Icon(Icons.sticky_note_2_outlined, color: Colors.grey.shade400),
            ),
          ),
        ),
      );
    },
  );
}
