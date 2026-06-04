import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ChatRoomAppBarSkeleton extends StatelessWidget
    implements PreferredSizeWidget {
  const ChatRoomAppBarSkeleton({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: Colors.white,
    elevation: 0.5,
    leading: Padding(
      padding: EdgeInsets.all(8.r),
      child: Bone.circle(size: 24.w),
    ),
      title: Skeletonizer.zone(
        child: Row(
          children: [
            Bone.circle(size: 36.w),
            Gap(10.w),
            Flexible(child: Bone.text(words: 3)),
        ],
      ),
    ),
    actions: [
      Padding(
        padding: EdgeInsets.all(8.r),
        child: Bone.icon(size: 24.w,),
      ),
      Padding(
        padding: EdgeInsets.all(8.r),
        child: Bone.icon(size: 24.w,),
      ),
    ],
  );
}
