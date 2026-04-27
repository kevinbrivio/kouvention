// lib/features/profile/widgets/profile_header.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';

class ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoUrl;
  final String authProviderLabel;
  final bool isGoogleLinked;
  final Function() onChangePhoto;

  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.authProviderLabel,
    required this.isGoogleLinked,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        // Avatar with camera overlay
        Stack(
          children: [
            CircleAvatar(
              radius: 56.r,
              backgroundColor: AppColors.grey.withValues(alpha: 0.15),
              backgroundImage: photoUrl != null
                  ? NetworkImage(photoUrl!)
                  : null,
              child: photoUrl == null
                  ? Icon(Icons.person, size: 56.sp, color: Colors.grey)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: onChangePhoto,
                child: Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(Icons.camera_alt, size: 16.r, color: Colors.white),
                ),
              ),
            ),
          ],
        ),

        Gap(16.h),

        // Display name
        Text(
          displayName,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),

        Gap(4.h),

        // Email
        Text(
          email,
          style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
        ),

        Gap(8.h),

        // Auth provider badge
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isGoogleLinked
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGoogleLinked) ...[
                Icon(
                  Icons.check_circle,
                  size: 16.r,
                  color: Colors.blue.shade600,
                ),
                Gap(4.w),
              ],
              Text(
                authProviderLabel,
                style: textTheme.subDescription3.copyWith(
                  color: isGoogleLinked
                      ? AppColors.primary
                      : Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
