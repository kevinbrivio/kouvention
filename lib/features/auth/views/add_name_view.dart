// lib/features/user/views/add_name_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/custom_button.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';
import 'package:kouvention/features/user/viewmodel/add_name_viewmodel.dart';

class AddNameView extends StatelessWidget {
  const AddNameView({super.key});

  @override
  Widget build(BuildContext context) =>
      BaseView(provider: addNameVM, builder: _buildScreen);

  Widget _buildScreen(BuildContext context, AddNameVM vm) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      child: SizedBox(
        height:
            MediaQuery.of(context).size.height -
            MediaQuery.of(context).padding.top,
        child: Column(
          children: [
            Gap(40.h),
            _buildLogo(),
            Gap(AppSpacing.xl.h),
            _buildCard(context, vm),
          ],
        ),
      ),
    ),
  );

  Widget _buildLogo() => Column(
    children: [
      Image.asset(images.splash, height: 144.w, width: 144.w),
      Gap(AppSpacing.xs.h),
      const Text(
        'Kouvention',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _buildCard(BuildContext context, AddNameVM vm) => TransparentBox(
    color: AppColorTokens.primary.withValues(alpha: 0.4),
    borderColor: Colors.white.withValues(alpha: 0.7),
    child: Form(
      key: vm.formKey,
      child: Column(
        children: [
          Text('One last thing', style: context.text.bodyMedium),
          Gap(AppSpacing.xs.h),
          Text(
            'What should others call you?',
            style: context.text.bodyMedium.copyWith(
              color: context.text.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          Gap(AppSpacing.xl.h),
          _buildNameField(context, vm),
          Gap(AppSpacing.lg.h),
          _buildSubmitButton(vm),
        ],
      ),
    ),
  );

  Widget _buildNameField(BuildContext context, AddNameVM vm) => TextFormField(
    controller: vm.form.displayName.controller,
    textCapitalization: TextCapitalization.words,
    style: context.text.bodyMedium.copyWith(
      color: context.text.secondaryText,
    ),
    validator: (val) => vm.form.displayName.validator?.call(val ?? ''),
    decoration: InputDecoration(
      hintText: 'Display name',
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(
        Icons.person_outline,
        color: Colors.white70,
        size: AppSizing.iconSm.sp,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: 14.h,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        borderSide: BorderSide.none,
      ),
      errorStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
    ),
  );

  Widget _buildSubmitButton(AddNameVM vm) => SizedBox(
    height: AppSizing.buttonHeight.h,
    child: Button(
      onPressed: vm.isLoading ? null : () => vm.submit(),
      text: 'Continue',
      // isWhiteBackground: true,
    ),
  );
}
