// lib/features/user/views/add_name_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
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
      padding: EdgeInsetsDirectional.symmetric(horizontal: 16.w),
      child: SizedBox(
        height:
            MediaQuery.of(context).size.height -
            MediaQuery.of(context).padding.top,
        child: Column(
          children: [Gap(40.h), _buildLogo(), Gap(32.h), _buildCard(vm)],
        ),
      ),
    ),
  );

  Widget _buildLogo() => Column(
    children: [
      Image.asset(images.logo, height: 48.h),
      Gap(8.h),
      Text(
        'Kouvention',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _buildCard(AddNameVM vm) => TransparentBox(
    color: AppColors.primary.withValues(alpha: 0.4),
    borderColor: AppColors.white.withValues(alpha: 0.7),
    child: Form(
      key: vm.formKey,
      child: Column(
        children: [
          Text('One last thing', style: textTheme.body1),

          Gap(8.h),
          Text(
            'What should others call you?',
            style: textTheme.subDescription2,
            textAlign: TextAlign.center,
          ),
          Gap(32.h),

          _buildNameField(vm),

          Gap(24.h),

          _buildSubmitButton(vm),
        ],
      ),
    ),
  );

  Widget _buildNameField(AddNameVM vm) => TextFormField(
    controller: vm.form.displayName.controller,
    textCapitalization: TextCapitalization.words,
    style: textTheme.subDescription2,
    validator: (val) => vm.form.displayName.validator?.call(val ?? ''),
    decoration: InputDecoration(
      hintText: 'Display name',
      hintStyle: TextStyle(color: Colors.white54),
      prefixIcon: Icon(
        Icons.person_outline,
        color: Colors.white70,
        size: 20.sp,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      errorStyle: TextStyle(color: Colors.orangeAccent, fontSize: 12.sp),
    ),
  );

  Widget _buildSubmitButton(AddNameVM vm) => SizedBox(
    height: 48.h,
    child: Button(
      onPressed: vm.isLoading ? null : () => vm.submit(),
      text: 'Continue',
      isWhiteBackground: true,
    ),
  );
}
