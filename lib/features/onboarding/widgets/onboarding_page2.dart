import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/widgets/floating_widget.dart';
import 'package:kouvention/cores/widgets/icon_holder.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';

class OnboardingPage2 extends StatelessWidget {
  OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FloatingWidget(
          child: SizedBox(
            width: 320.w,
            height: 180.w,
            child: TransparentBox(
              borderColor: AppColors.white,
              color: AppColors.white.withValues(alpha: 0.3),
              child: Image.asset(images.onboarding2, fit: BoxFit.cover),
            ),
          ),
        ),
        Gap(16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: TransparentBox(
            color: AppColors.white.withValues(alpha: 0.2),
            radius: BorderRadius.circular(12.r),
            child: _buildContent(
              'Chat Rooms',
              'Join public communities or create private groups for your team.',
              Icons.search_outlined,
            ),
          ),
        ),
        Gap(16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: TransparentBox(
            color: AppColors.white.withValues(alpha: 0.2),
            radius: BorderRadius.circular(12.r),
            child: _buildContent(
              'Global Search',
              'Find messages, files, and contacts instantly across all chats.',
              Icons.people_alt_outlined,
            ),
          ),
        ),
        Gap(16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: TransparentBox(
            color: AppColors.white.withValues(alpha: 0.2),
            radius: BorderRadius.circular(12.r),
            child: _buildContent(
              'User Profiles',
              'Customize your presence and view detailed contact information.',
              Icons.nature_people_outlined,
            ),
          ),
        ),
        Gap(12.h),
      ],
    ),
  );

  Widget _buildContent(String title, String description, IconData icon) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // TODO: Change hardcoded icons to params
      IconHolder(icon: Icon(icon, color: AppColors.white)),
      Gap(12.w),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.subDescription.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
            Gap(4.h),
            Text(
              description,
              style: textTheme.subDescription.copyWith(fontSize: 13.sp),
              textAlign: TextAlign.left,
              softWrap: true,
            ),
          ],
        ),
      ),
    ],
  );
}
