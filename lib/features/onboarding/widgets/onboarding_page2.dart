import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/widgets/floating_widget.dart';
import 'package:kouvention/cores/widgets/icon_holder.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';

class OnboardingPage2 extends StatelessWidget {
  OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FloatingWidget(
          child: SizedBox(
            width: 320.w,
            height: 180.w,
            child: TransparentBox(
              borderColor: Colors.white,
              color: Colors.white.withValues(alpha: 0.3),
              child: Image.asset(images.onboarding2, fit: BoxFit.cover),
            ),
          ),
        ),
        Gap(AppSpacing.md.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
          child: TransparentBox(
            color: Colors.white.withValues(alpha: 0.2),
            radius: BorderRadius.circular(AppRadius.md.r),
            child: _buildContent(
              context,
              'Chat Rooms',
              'Join public communities or create private groups for your team.',
              Icons.search_outlined,
            ),
          ),
        ),
        Gap(AppSpacing.md.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
          child: TransparentBox(
            color: Colors.white.withValues(alpha: 0.2),
            radius: BorderRadius.circular(AppRadius.md.r),
            child: _buildContent(
              context,
              'Global Search',
              'Find messages, files, and contacts instantly across all chats.',
              Icons.people_alt_outlined,
            ),
          ),
        ),
        Gap(AppSpacing.md.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
          child: TransparentBox(
            color: Colors.white.withValues(alpha: 0.2),
            radius: BorderRadius.circular(AppRadius.md.r),
            child: _buildContent(
              context,
              'User Profiles',
              'Customize your presence and view detailed contact information.',
              Icons.nature_people_outlined,
            ),
          ),
        ),
        Gap(AppSpacing.sm.h),
      ],
    ),
  );

  Widget _buildContent(BuildContext context, String title, String description, IconData icon) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // TODO: Change hardcoded icons to params
      IconHolder(icon: Icon(icon, color: Colors.white)),
      Gap(AppSpacing.sm.w),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.text.subDescription.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Gap(AppSpacing.xxs.h),
            Text(
              description,
              style: context.text.subDescription.copyWith(fontSize: 13.sp),
              textAlign: TextAlign.left,
              softWrap: true,
            ),
          ],
        ),
      ),
    ],
  );
}
