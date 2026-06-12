import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/tap_detector.dart';
import 'package:kouvention/features/onboarding/viewmodel/onboarding_viewmodel.dart';

class BottomIndicatorButton extends ConsumerWidget {
  const BottomIndicatorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(onboardingVM);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH.w),
      child: Row(
        children: [
          if (vm.currentPage > 0) ...[
            SizedBox(
              height: AppSizing.buttonHeight.h,
              width: AppSizing.buttonHeight.h, 
              child: TapDetector(
                onTap: vm.backPage,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                    color: AppColorTokens.info,
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: AppSizing.iconXs.sp,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            Gap(AppSpacing.lg.w), 
          ],
  
          Expanded(
            child: SizedBox(
              height: AppSizing.buttonHeight.h,
              child: Button(
                text: vm.currentPage == 2 ? 'Get Started' : 'Next',
                textStyle: context.text.titleMedium.copyWith(
                  color: vm.currentPage == 2 ? Colors.white : AppColorTokens.info,
                  fontWeight: FontWeight.bold,
                ),
                showArrow: true,
                onPressed: () {
                  if (vm.currentPage == 2) {
                    vm.goToPrivacyPolicy();
                  } else if (vm.currentPage < OnboardingVM.totalPages) {
                    vm.nextPage();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}