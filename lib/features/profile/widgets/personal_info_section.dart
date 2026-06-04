import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';

class PersonalInfoSection extends StatelessWidget {
  final String displayName;
  final String status;
  final Function() onEditName;
  final Function() onEditStatus;

  PersonalInfoSection({
    required this.displayName,
    required this.status,
    required this.onEditName,
    required this.onEditStatus,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16.r),
      boxShadow: [ 
        BoxShadow(
          offset: Offset(0, 0.5),
          blurRadius: 0.2,
          color: AppColors.black.withValues(alpha: 0.1)
        ),
      ]
    ),
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
    child: Column(
      children: [
        // Display Name
        InkWell(
          onTap: onEditName,
          splashColor: AppColors.grey,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Display Name', style: AppTextTheme.of(context).subDescription3),
            Gap(4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayName,
                  style: AppTextTheme.of(context).subDescription2,
                ),

                Icon(Icons.create_rounded, size: 24.sp),
              ],
            ),
          ],
        ),
        ),
        Gap(12.h),
        Divider(color: AppColors.grey.withValues(alpha: 0.15),),
        Gap(6.h),
        
        InkWell(
          onTap: onEditStatus,
          splashColor: AppColors.grey,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status', style: AppTextTheme.of(context).subDescription3),
            Gap(4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status,
                  style: AppTextTheme.of(context).subDescription2,
                ),

                Icon(Icons.create_rounded, size: 24.sp),
              ],
            ),
          ],
        ),
        )
      ],
    ),
  );
}
