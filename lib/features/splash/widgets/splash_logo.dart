import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';

class SplashLogo extends StatelessWidget {
  const SplashLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 120.h,),
        Container(
          width: 92.w,
          height: 92.w,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r), color: AppColors.white.withAlpha(48)),
          child: Center(
            child: Image.asset(images.logo, width: 50.w, height: 50.w),
          ),
        ),

        Text.rich(
          TextSpan(
            text: 'Kouvent',
            style: textTheme.headline1,
            children: [
              TextSpan(
                text: 'ion',
                style: textTheme.headline1.copyWith(fontWeight: FontWeight.w300, color: AppColors.white.withAlpha(200)),
              ),
            ],
          ),
        ),

        Text(
          'Connect instantly, anywhere.',
          style: textTheme.body2,
        ),
      ],
    );
  }
}
