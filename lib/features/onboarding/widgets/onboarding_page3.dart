import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/floating_widget.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';

class OnboardingPage3 extends StatelessWidget {
  OnboardingPage3({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 200.w,
          child: FloatingWidget(
            child: TransparentBox(child: Image.asset(images.logo)),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            children: [
              Gap(12.h),
              Text(
                'Your Privacy, Guaranteed',
                style: textTheme.headline1.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              Gap(12.h),
              Text(
                'End-to-end encryption and secure Google Oauth sign-in keeps your chats and data fully protected.',
                style: textTheme.subDescription,
                softWrap: true,
              ),
              Gap(16.h),
              GestureDetector(
                onTap: () {
                  context.go(RouterRoutes.privacyPolicy.path);
                },
                child: Text(
                  'Read our Privacy Policy',
                  style: textTheme.subDescription.copyWith(
                    color: AppColors.white.withValues(alpha: 0.5),
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
