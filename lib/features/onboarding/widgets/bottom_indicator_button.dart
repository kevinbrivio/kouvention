import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/features/onboarding/viewmodel/onboarding_viewmodel.dart';

class BottomIndicatorButton extends ConsumerWidget {
  BottomIndicatorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(onboardingVM);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (vm.currentPage > 0)
          SizedBox(
            height: 56.h,
            child: Button(
              leadingWidget: const Icon(Icons.arrow_back_rounded),
              width: 60.w,
              onPressed: vm.backPage,
              text: '',
            ),
          ),
        if (vm.currentPage > 0) Gap(AppSpacing.sm.w),
        SizedBox(
          height: 56.h,
          child: Button(
            isWhiteBackground: true,
            text: vm.currentPage == 2 ? 'Get Started' : 'Next',
            textStyle: context.text.titleMedium.copyWith(color: Theme.of(context).colorScheme.onSurface,
            ),
            showArrow: true,
            width: 224.w,
            onPressed: vm.currentPage < OnboardingVM.totalPages
                ? vm.currentPage == 2 
                  ? vm.goToPrivacyPolicy
                  : vm.nextPage
                : null,
          ),
        ),
      ],
    );
  }
}
