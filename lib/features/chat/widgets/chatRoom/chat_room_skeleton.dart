import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/chat/models/bubble_color_scheme.dart';
import 'package:kouvention/features/chat/viewmodel/bubble_scheme_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ChatRoomSkeleton extends ConsumerWidget {
  const ChatRoomSkeleton({super.key});

  static const int _itemCount = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = ref.watch(bubbleSchemeProvider);

    return Skeletonizer.zone(
      effect: ShimmerEffect(
        baseColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE6E9ED),
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: _itemCount,
        itemBuilder: (context, index) {
          final isMe = index % 2 == 0;
          return _buildBubble(isMe, scheme);
        },
      ),
    );
  }

  Widget _buildBubble(bool isMe, BubbleColorScheme scheme) => Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h, horizontal: AppSpacing.md.w),
    child: Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMe) ...[Bone.circle(size: AppSizing.avatarSm.w), Gap(AppSpacing.xs.w)],
        // Bubble body
        Container(
          constraints: BoxConstraints(maxWidth: 260.w),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isMe
                ? scheme.sentBubble.withValues(alpha: 0.5)
                : scheme.receivedBubble.withValues(alpha: 0.5),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMe ? AppRadius.lg.r : AppRadius.xs.r),
              topRight: Radius.circular(isMe ? AppRadius.xs.r : AppRadius.lg.r),
              bottomRight: Radius.circular(AppRadius.lg.r),
              bottomLeft: Radius.circular(AppRadius.lg.r),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [Bone.text(words: 3), Gap(AppSpacing.xxs.h), Bone.text(words: 1)],
          ),
        ),
      ],
    ),
  );
}
