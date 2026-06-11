import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/floating_widget.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';

class OnboardingPage3 extends StatelessWidget {
  OnboardingPage3({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FloatingWidget(
            child: SizedBox(
              width: 320.w,
              height: 320.w,
              child: TransparentBox(
                borderColor: Theme.of(context).colorScheme.primary,
                color: Colors.white.withValues(alpha: 0.3),
                child: Image.asset(images.onboarding3, fit: BoxFit.cover),
              ),
            ),
          ),
          Gap(AppSpacing.md.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
            child: Column(
              children: [
                Gap(AppSpacing.sm.h),
                Text(
                  'Your Privacy, Guaranteed',
                  style: context.text.headlineSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                Gap(AppSpacing.sm.h),
                Text(
                  'End-to-end encryption and secure Google Oauth sign-in keeps your chats and data fully protected.',
                  style: context.text.bodyMedium.copyWith(fontSize: 13.sp, color: context.text.secondaryText),
                  textAlign: TextAlign.center,
                  softWrap: true,
                ),
                Gap(20.h),
                GestureDetector(
                  onTap: () {
                    context.go(RouterRoutes.privacyPolicy.path);
                  },
                  child: Text(
                    'Read our Privacy Policy',
                    style: context.text.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
