import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';

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
        return 'Your device have been detected root | jailbreak.';
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
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w600,
              fontFamily: 'Asap',
              color: Colors.white,
            ),
          ),
          Gap(16.h),
          Text(
            _threatMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              fontFamily: 'Asap',
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          Gap(8.h),
          Text(
            'Kouvention cannot be used in this device '
            ' for your own data safety.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              fontFamily: 'Asap',
              color: Colors.white54,
              height: 1.5,
            ),
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
                'Tutup Aplikasi',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontFamily: 'Asap',
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}