import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/widgets/floating_widget.dart';

class OnboardingPage1 extends StatelessWidget {
  OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Gap(AppSizing.touchMin.h),
          FloatingWidget(
            child: SizedBox(
              width: 320.w,
              height: 320.w,
              child: Image.asset(images.onboarding1, fit: BoxFit.cover),
            ),
          ),
          Gap(AppSpacing.sm.h),
          Padding(
            padding: EdgeInsetsGeometry.symmetric(horizontal: AppSpacing.xxs.w),
            child: Text('Fast & Secure', style: context.text.headlineSmall),
          ),
          Gap(AppSpacing.sm.h),

          Padding(
            padding: EdgeInsetsGeometry.symmetric(horizontal: 36.w),
            child: Text(
              'Experience lightning-fast messaging with end-to-end encryption. Your privacy is our priority',
              style: context.text.titleMedium.copyWith(color: context.text.secondaryText),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );
}
