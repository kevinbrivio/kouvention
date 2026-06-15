import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? body;
  final List<Widget>? trailing;
  final Function() onBack;

  const CustomAppBar({
    super.key,
    this.body,
    this.trailing,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => AppBar(
    elevation: 0.5,
    centerTitle: false,
    scrolledUnderElevation: 0,
    automaticallyImplyLeading: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    title: InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onBack();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.arrow_back,
            size: AppSizing.iconSm.r,
            color: Theme.of(context).colorScheme.primary,
          ),
          Gap(AppSpacing.xs.w),
          if (body != null) body!,
        ],
      ),
    ),
    actions: trailing,
  );

  // Wajib di-override karena implements PreferredSizeWidget
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
