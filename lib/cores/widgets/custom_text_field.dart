import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/models/text_input_model.dart';

class CustomTextField extends StatefulWidget {
  final TextInputModel inputModel;
  final FocusNode? focusNode;
  final Function()? onTapOutside;
  final bool enabled;
  final String hint;
  final String? label;
  final TextStyle? labelStyle;
  final String? errorMessage;
  final String? Function(String)? validator;
  final void Function(String)? onValidate;
  final Function(String)? onSubmit;
  final Widget? prefixWidget;
  final Widget? suffixWidget;
  final Function()? onSuffixPressed;
  final Function(String)? onChanged;
  final EdgeInsets? contentPadding;
  final TextInputAction? inputAction;
  final TextInputType? keyboardType;
  final bool autoFocus;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;
  final bool isLarge;
  final bool isRequired;
  final TextStyle? style;
  final Color labelColor;
  final Color? errorMsgColor;
  final String? description;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Color? hintColor;
  final bool shakeOnError;

  const CustomTextField({
    super.key,
    this.focusNode,
    this.onTapOutside,
    this.enabled = true,
    required this.hint,
    this.label,
    this.labelStyle,
    this.errorMessage,
    required this.inputModel,
    required this.onSubmit,
    this.validator,
    this.prefixWidget,
    this.suffixWidget,
    this.onSuffixPressed,
    this.onValidate,
    this.onChanged,
    this.contentPadding,
    this.inputAction,
    this.keyboardType,
    this.autoFocus = false,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
    this.isLarge = false, // Default is not large,
    this.isRequired = false,
    this.style,
    this.labelColor = AppColors.black,
    this.errorMsgColor,
    this.description,
    this.borderRadius,
    this.borderColor,
    this.hintColor,
    this.shakeOnError = true,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField>
    with SingleTickerProviderStateMixin {
  String? errorMessage;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  InputBorder getBorder(Color color) => OutlineInputBorder(
    borderRadius: widget.borderRadius ?? BorderRadius.circular(12.r),
    borderSide: BorderSide(
      color:
          widget.borderColor ??
          (errorMessage != null ? AppColors.errorLight : color),
      width: 2.sp,
    ),
  );

  String? validate(String value) {
    if (value.isEmpty) {
      return 'Data is empty';
    }
    return null;
  }

  void _triggerShake() {
    HapticFeedback.lightImpact();
    _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.label != null) ...[
        Row(
          children: [
            Text.rich(
              TextSpan(
                style: textTheme.body2.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  fontFamily: textTheme.body2.fontFamily,
                  color: widget.labelColor,
                ),
                children: [
                  TextSpan(text: widget.label),
                  if (widget.isRequired)
                    TextSpan(
                      text: '*',
                      style: TextStyle(
                        color: AppColors.red1,
                        fontWeight: FontWeight.w500,
                        fontFamily: textTheme.body2.fontFamily,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        Gap(6.h),
      ],
      AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          final offset = sin(_shakeAnimation.value * pi * 3) * 8;
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: SizedBox(
          height: widget.isLarge ? 125.h : 46.h,
          child: TextFormField(
            expands: widget.isLarge,
            maxLines: widget.isLarge ? null : 1,
            textAlignVertical: widget.isLarge
                ? TextAlignVertical.top
                : TextAlignVertical.center,
            focusNode: widget.focusNode,
            onTapOutside: (_) {
              widget.onTapOutside?.call();
            },
            autofocus: widget.autoFocus,
            textInputAction: widget.inputAction,
            enabled: widget.enabled,
            keyboardType: widget.keyboardType,
            controller: widget.inputModel.controller,
            onChanged: (value) {
              setState(() {
                errorMessage = null;
              });
              widget.onChanged?.call(value);
            },
            textAlign: widget.textAlign,
            decoration: InputDecoration(
              alignLabelWithHint: true,
              contentPadding:
                  widget.contentPadding ??
                  EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
              hintText: widget.hint,
              hintStyle: textTheme.body2.copyWith(
                color: widget.hintColor ?? AppColors.grey,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: widget.enabled ? AppColors.white : AppColors.grey,
              focusedBorder: getBorder(AppColors.primary2),
              enabledBorder: getBorder(AppColors.primary2),
              disabledBorder: getBorder(AppColors.grey),
              border: getBorder(AppColors.grey),
              errorBorder: getBorder(AppColors.red1),
              focusedErrorBorder: getBorder(AppColors.primary),
              errorStyle: textTheme.body2.copyWith(
                fontSize: 0,
                color: Colors.transparent,
              ),
              prefixIcon: widget.prefixWidget,
              prefixIconConstraints: BoxConstraints(
                maxWidth: 120.w,
                maxHeight: 23.h,
              ),
              suffixIcon: widget.suffixWidget,
              suffixIconConstraints: BoxConstraints(
                maxWidth: 56.w,
                maxHeight: 23.h,
              ),
            ),
            style: (widget.style ?? textTheme.body2).copyWith(
              color: !widget.enabled
                  ? AppColors.grey
                  : (errorMessage != null
                        ? AppColors.errorLight
                        : AppColors.black),
            ),
            showCursor: true,
            cursorColor: errorMessage != null
                ? AppColors.errorLight
                : AppColors.primary,
            cursorErrorColor: errorMessage != null
                ? AppColors.errorLight
                : AppColors.primary,
            validator: (value) {
              String? message = widget.inputModel.validator?.call(value ?? '');
              if (message != null) {
                setState(() {
                  errorMessage = message;
                });
                if (widget.shakeOnError) _triggerShake();
              }
              widget.onValidate?.call(message!);
              return message;
            },
            onFieldSubmitted: widget.onSubmit,
            inputFormatters: [...?widget.inputFormatters],
          ),
        ),
      ),
      if (errorMessage == null && widget.description != null) ...[
        Gap(3.h),
        Text(
          widget.description!,
          style: textTheme.body2.copyWith(color: AppColors.black),
        ),
      ],
      if (errorMessage != null) ...[
        Gap(3.h),
        Text(
          errorMessage!,
          style: textTheme.body2.copyWith(
            fontWeight: FontWeight.w400,
            color: widget.errorMsgColor ?? AppColors.errorLight,
          ),
        ),
      ],
    ],
  );
}
