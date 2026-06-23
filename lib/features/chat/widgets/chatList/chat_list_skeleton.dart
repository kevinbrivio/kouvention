import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Skeletonizer.zone(
      effect: ShimmerEffect(
        baseColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE6E9ED),
      ),
      child: ListView.builder(
        itemCount: 8,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
          child: Row(
            children: [
              Bone.circle(size: AppSizing.touchMin.w),
              Gap(AppSpacing.sm.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(words: 2),
                    Gap(AppSpacing.xxs.h),
                    Bone.text(words: 4),
                  ],
                ),
              ),
              Gap(AppSpacing.xxs.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Bone.text(words: 1),
                  Gap(AppSpacing.xxs.h),
                  Bone.circle(size: AppSizing.iconSm.w),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
