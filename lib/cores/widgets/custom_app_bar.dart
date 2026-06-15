import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    title: _InteractiveBackTitle(
      onBack: onBack,
      body: body,
    ),
    actions: trailing,
  );

  // Wajib di-override karena implements PreferredSizeWidget
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _InteractiveBackTitle extends StatefulWidget {
  final VoidCallback onBack;
  final Widget? body;

  const _InteractiveBackTitle({required this.onBack, this.body});

  @override
  State<_InteractiveBackTitle> createState() => _InteractiveBackTitleState();
}

class _InteractiveBackTitleState extends State<_InteractiveBackTitle> {
  // Melacak tekanan mekanik pada layar
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) => InkWell(
    // Siklus sentuhan seperti yang kita pelajari di eksperimen sebelumnya
    onTapDown: (_) => setState(() => _isPressed = true),
    onTapUp: (_) {
      setState(() => _isPressed = false);
      HapticFeedback.selectionClick();

      Future.delayed(const Duration(milliseconds: 200), () {
        widget.onBack();
      });
    },
    onTapCancel: () => setState(() => _isPressed = false),
    child:
        Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back,
                  size: AppSizing.iconSm.r,
                  color: Theme.of(context).colorScheme.primary,
                ),
                Gap(AppSpacing.xs.w),
                if (widget.body != null) widget.body!,
              ],
            )
            .animate(target: _isPressed ? 1 : 0)
            .scaleXY(
              end: 0.9,
              duration: 100.ms,
              curve: Curves.easeOutCubic,
            )
            .moveX(end: -2, duration: 100.ms)
            .shimmer(
              duration: 150.ms,
              color: Colors.white,
            ),
  );
}
