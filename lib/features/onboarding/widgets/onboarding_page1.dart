import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/widgets/floating_widget.dart';

class OnboardingPage1 extends StatelessWidget {
  OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Gap(48.h),
        FloatingWidget(
          child: SizedBox(
            width: 50.w,
            height: 50.w,
            child: Image.asset(images.logo),
          ),
        ),
        Gap(12.h),
        Padding(
          padding: EdgeInsetsGeometry.symmetric(horizontal: 4.w),
          child: Text('Fast & Secure', style: textTheme.headline1),
        ),
        Gap(12.h),

        Padding(
          padding: EdgeInsetsGeometry.symmetric(horizontal: 36.w),
          child: Text(
            'Experience lightning-fast messaging with end-to-end encryption. Your privacy is our priority',
            style: textTheme.subDescription,
            textAlign: TextAlign.center,
          ),
        ),
        
      ],
    ),
  );
}
