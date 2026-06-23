import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class StoryCaptionField extends StatelessWidget {
  const StoryCaptionField({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLength: 120,
      minLines: 1,
      maxLines: 3,
      textInputAction: TextInputAction.newline,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Add a caption',
        hintStyle: const TextStyle(color: Colors.white70),
        counterText: '',
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.42),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
    );
  }
}
