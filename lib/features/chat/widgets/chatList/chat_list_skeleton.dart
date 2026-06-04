import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Skeletonizer.zone(
      effect: ShimmerEffect(
        baseColor: isDark ? AppColors.darkSkeleton : AppColors.lightSkeleton,
      ),
      child: ListView.builder(
        itemCount: 8,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              Bone.circle(size: 48.w),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(words: 2),
                    Gap(4.h),
                    Bone.text(words: 4),
                  ],
                ),
              ),
              Gap(4.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Bone.text(words: 1),
                  Gap(4.h),
                  Bone.circle(size: 20.w),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
