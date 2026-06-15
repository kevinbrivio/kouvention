// lib/features/profile/widgets/profile_header.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/icon_paths.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/profile/widgets/bubble_container.dart';

class ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? bio;
  final String authProviderLabel;
  final bool isGoogleLinked;
  final Function() onChangePhoto;

  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.bio,
    required this.authProviderLabel,
    required this.isGoogleLinked,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        children: [
          // Avatar with camera overlay
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 56.r,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.15),
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
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: AppSpacing.md.r,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (bio != null && bio!.isNotEmpty)
                Positioned(
                  top: -12.r,
                  left: 90.w,
                  child: BubbleContainer(
                    child: Text(
                      bio!,
                      style: context.text.bodyMedium.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Gap(AppSpacing.md.h),
          // Display name
          Text(displayName, style: context.text.headlineSmall.copyWith(
            color: context.text.secondaryText
          )),
          Gap(AppSpacing.xs.h),

          // Auth provider badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm.w,
              vertical: AppSpacing.xxs.h,
            ),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isGoogleLinked) ...[
                  Image.asset(
                    icons.google,
                    width: AppSizing.iconMd.r,
                    height: AppSizing.iconMd.r,
                  ),
                ] else ...[
                  Icon(
                    Icons.email_outlined,
                    size: AppSizing.iconMd.r,
                    color: scheme.primary,
                  ),
                ],
                Gap(AppSpacing.xs.w),
                Text(
                  email,
                  style: context.text.labelLarge.copyWith(
                    color: context.text.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
