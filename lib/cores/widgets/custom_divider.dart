import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class CustomDivider extends StatelessWidget {
  final String? text;
  final Color? color;
  const CustomDivider({super.key, this.text, this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Divider(
          color:
              color ??
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          thickness: 1,
        ),
      ),
      if (text != null && text!.isNotEmpty) ...[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          child: Text(
            text!,
            style: context.text.bodyMedium.copyWith(
              color: context.text.secondaryText,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color:
                color ??
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            thickness: 1,
          ),
        ),
      ],
    ],
  );
}
