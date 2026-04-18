import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/widgets/circular_icon_holder.dart';
import 'package:kouvention/cores/widgets/floating_widget.dart';
import 'package:kouvention/cores/widgets/transparent_box.dart';

class OnboardingPage2 extends StatelessWidget {
  OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          height: 200.w,
          child: FloatingWidget(
            child: TransparentBox(child: Image.asset(images.logo)),
          ),
        ),
        Gap(16.h),
        SizedBox(
          height: 160.w,
          child: TransparentBox(
            child: _buildContent(
              'Chat Rooms',
              'Join public communities or create private groups for your team.',
            ),
          ),
        ),
        Gap(16.h),
        SizedBox(
          height: 160.w,
          child: TransparentBox(
            child: _buildContent(
              'Global Search',
              'Find messages, files, and contacts instantly across all chats.',
            ),
          ),
        ),
        Gap(16.h),
        SizedBox(
          height: 160.w,
          child: TransparentBox(
            child: _buildContent(
              'User Profiles',
              'Customize your presence and view detailed contact information',
            ),
          ),
        ),
        Gap(12.h),
      ],
    ),
  );

  Widget _buildContent(String title, String description) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // TODO: Change hardcoded icons to params
      CircularIconHolder(icon: Icon(Icons.access_alarm)),
      Gap(12.w),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.subheadline1.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap(4.h),
            Text(
              description,
              style: textTheme.subDescription,
              softWrap: true,
            ),
          ],
        ),
      ),
    ],
  );
}
