import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';

class DeviceBlockedView extends StatelessWidget {
  final String threatType;
  final VoidCallback onExit;

  const DeviceBlockedView({
    super.key,
    required this.threatType,
    required this.onExit,
  });

  String get _threatMessage {
    switch (threatType) {
      case 'rooted':
        return 'Your device has been detected as rooted or jailbroken.';
      case 'hooks':
        return 'Detected some apps might misuse your phone';
      case 'tampered':
        return 'This app has been modified by unknown parties.';
      default:
        return 'Detected security threats in this app';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary2],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 80.r, color: Colors.redAccent),
          Gap(24.h),
          Text(
            'Access Refused',
            style: textTheme.subheadline1
          ),
          Gap(16.h),
          Text(
            _threatMessage,
            textAlign: TextAlign.center,
            style: textTheme.subDescription2
          ),
          Gap(8.h),
          Text(
            'Kouvention cannot be used in this device '
            ' for your own data safety.',
            textAlign: TextAlign.center,
            style: textTheme.subDescription2
          ),
          Gap(32.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onExit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Close App',
                style: textTheme.subDescription,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}