import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    scrolledUnderElevation: 0,
    leading: IconButton(
      icon: Icon(
        Icons.arrow_back,
        color: Theme.of(context).colorScheme.primary,
      ),
      onPressed: () => onBack(),
    ),
    title: InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onBack();
      },
      borderRadius: BorderRadius.circular(AppRadius.sm.r),
      child: body,
    ),
    actions: trailing,
  );

  // Wajib di-override karena implements PreferredSizeWidget
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
