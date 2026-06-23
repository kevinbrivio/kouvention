import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/icon_paths.dart';
import 'package:kouvention/cores/constants/tokens.dart';

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
    final ext = file.path.split('.').last.toUpperCase();
  
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
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
                Gap(AppSpacing.sm.h),
                Text(
                  fileName,
                  style: context.text.headlineSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
                Gap(AppSpacing.sm.h),
                Text('$fileSizes · $ext', style: context.text.titleMedium.copyWith(color: context.text.secondaryText)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
