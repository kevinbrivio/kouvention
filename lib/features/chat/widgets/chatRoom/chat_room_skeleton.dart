import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ChatRoomSkeleton extends StatelessWidget {
  const ChatRoomSkeleton({super.key});

  static const int _itemCount = 8;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Skeletonizer.zone(
      effect: ShimmerEffect(
        baseColor: isDark ? AppColors.darkSkeleton : AppColors.lightSkeleton,
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: _itemCount,
        itemBuilder: (context, index) {
          final isMe = index % 2 == 0;
          return _buildBubble(isMe);
        },
      ),
    );
  }

  Widget _buildBubble(bool isMe) => Padding(
    padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
    child: Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMe) ...[Bone.circle(size: 28.w), Gap(8.w)],
        // Bubble body
        Container(
          constraints: BoxConstraints(maxWidth: 260.w),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMe ? 16.r : 4.r),
              topRight: Radius.circular(isMe ? 4.r : 16.r),
              bottomRight: Radius.circular(16.r),
              bottomLeft: Radius.circular(16.r),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [Bone.text(words: 3), Gap(4.h), Bone.text(words: 1)],
          ),
        ),
      ],
    ),
  );
}
