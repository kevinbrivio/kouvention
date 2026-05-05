import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/widgets/hidden_app_bar.dart';
import 'package:kouvention/features/onboarding/viewmodel/onboarding_viewmodel.dart';
import 'package:kouvention/features/onboarding/widgets/bottom_indicator_button.dart';
import 'package:kouvention/features/onboarding/widgets/onboarding_page1.dart';
import 'package:kouvention/features/onboarding/widgets/onboarding_page2.dart';
import 'package:kouvention/features/onboarding/widgets/onboarding_page3.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) => BaseView(
    provider: onboardingVM,
    appBar: (_) => const HiddenAppBar(),
    builder: _buildScreen,
  );

  Widget _buildScreen(BuildContext context, OnboardingVM vm) => PopScope(
    canPop: false,
    child: SafeArea(
      child: Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: vm.goToPrivacyPolicy,
                child: Text('Skip', style: textTheme.subDescription),
              ),
            ),
          ),
          Gap(12.h),
          Expanded(
            child: CarouselSlider(
              carouselController: vm.controller,
              items: [
                OnboardingPage1(),
                OnboardingPage2(),
                OnboardingPage3(),
              ],
              options: CarouselOptions(
                height: double.infinity,
                enableInfiniteScroll: false,
                viewportFraction: 1.0,
                onPageChanged: (index, reason) {
                  vm.syncPage(index);
                },
              ),
            ),
          ),
          
          Gap(12.h),
          _buildIndicator(vm.currentPage),
          Gap(12.h),
          BottomIndicatorButton(),
          Gap(12.h),
        ],
      ),
      ),
    ),
  );

  Widget _buildIndicator(int currentPage) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(OnboardingVM.totalPages, (index) {
      final isActive = index == currentPage;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isActive ? 32.w : 8.w,
        height: 6.h,
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.white
              : AppColors.white.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(6.r),
        ),
      );
    }),
  );
}
