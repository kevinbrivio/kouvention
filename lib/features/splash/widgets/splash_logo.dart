import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/constants/image_paths.dart';

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
      ).animate()
        .fadeIn(duration: 400.ms)
          .scale(duration: 400.ms)
          .blurXY(
            begin: 0.0,
            end: 8.0,
            duration: 400.ms,
          )
        .then(delay: 200.ms)
        .blurXY(
          begin: 8.0,
          end: 0.0,
          duration: 400.ms
          ),
        
      Text.rich(
        TextSpan(
          text: 'Kouvént',
          style: context.text.headlineLarge.copyWith(
            color: AppColorTokens.info,
          ),
          children: [
            TextSpan(
              text: 'ion',
              style: context.text.headlineLarge.copyWith(
                color: AppColorTokens.info,
              ),
            ),
          ],
        ),
      ),

      Text(
        'Connect instantly, anywhere.',
        style: context.text.bodyMedium.copyWith(color: AppColorTokens.info),
      ),
    ],
  );
}
