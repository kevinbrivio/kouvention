import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';

class SplashLogo extends StatelessWidget {
  const SplashLogo({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Center(
        child: Image.asset(
          images.splash,
          width: 320.h,
          height: 320.h,
          fit: BoxFit.cover,
        ),
      ),

      Text.rich(
        TextSpan(
          text: 'Kouvent',
          style: textTheme.headline1,
          children: [
            TextSpan(
              text: 'ion',
              style: textTheme.headline1.copyWith(
                fontWeight: FontWeight.w300,
                color: AppColors.white.withAlpha(200),
              ),
            ),
          ],
        ),
      ),

      Text('Connect instantly, anywhere.', style: textTheme.body2),
    ],
  );
}
