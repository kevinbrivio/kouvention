import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/icon_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/constants/colors.dart';

class AudioPreview extends StatelessWidget {
  final File file;
  const AudioPreview({super.key, required this.file});

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final cachedName = file.path;
    final fileName   = cachedName.split('/').last;
    final fileSizes  = formatFileSize(file.lengthSync());
  
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: SizedBox(
          height: MediaQuery.of(context).size.height
              - MediaQuery.of(context).viewPadding.top
              - MediaQuery.of(context).viewInsets.bottom
              - 80.h,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(icons.audio, height: 176.w, width: 176.w),
                Gap(12.h),
                Text(
                  fileName,
                  style: AppTextTheme.of(context).subheadline1.copyWith(
                    color: AppColors.grey,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                Gap(12.h),
                Text('$fileSizes · MP3', style: AppTextTheme.of(context).subDescription),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
