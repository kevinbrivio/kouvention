import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
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
  final Color? labelColor;
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
    this.isLarge = false,
    this.isRequired = false,
    this.style,
    this.labelColor,
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

  InputBorder getBorder(Color color, ColorScheme scheme) => OutlineInputBorder(
    borderRadius: widget.borderRadius ?? BorderRadius.circular(AppRadius.md.r),
    borderSide: BorderSide(
      color: widget.borderColor ??
          (errorMessage != null ? AppColorTokens.error : color),
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bodyStyle = context.text.bodyMedium;
    final defaultLabelColor = widget.labelColor ?? scheme.onSurface;
    final defaultHintColor =
        widget.hintColor ?? scheme.onSurface.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Row(
            children: [
              Text.rich(
                TextSpan(
                  style: bodyStyle.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: defaultLabelColor,
                  ),
                  children: [
                    TextSpan(text: widget.label),
                    if (widget.isRequired)
                      TextSpan(
                        text: '*',
                        style: TextStyle(
                          color: AppColorTokens.error,
                          fontWeight: FontWeight.w500,
                          fontFamily: bodyStyle.fontFamily,
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
            height:
                widget.isLarge ? AppSizing.inputLargeHeight.h : AppSizing.inputHeight.h,
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
                hintStyle: bodyStyle.copyWith(
                  color: defaultHintColor,
                  fontWeight: FontWeight.w300,
                ),
                filled: true,
                fillColor:
                    widget.enabled ? AppSurfaceLight.surface : AppSurfaceLight.surfaceInput,
                focusedBorder: getBorder(
                  AppColorTokens.primaryLighter,
                  scheme,
                ),
                enabledBorder: getBorder(
                  AppColorTokens.primaryLighter,
                  scheme,
                ),
                disabledBorder: getBorder(
                  scheme.onSurface.withValues(alpha: 0.5),
                  scheme,
                ),
                border: getBorder(
                  scheme.onSurface.withValues(alpha: 0.5),
                  scheme,
                ),
                errorBorder: getBorder(AppColorTokens.error, scheme),
                focusedErrorBorder: getBorder(scheme.primary, scheme),
                errorStyle: bodyStyle.copyWith(
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
              style: (widget.style ?? bodyStyle).copyWith(
                color: !widget.enabled
                    ? scheme.onSurface.withValues(alpha: 0.5)
                    : (errorMessage != null
                          ? AppColorTokens.error
                          : scheme.onSurface),
              ),
              showCursor: true,
              cursorColor:
                  errorMessage != null ? AppColorTokens.error : scheme.primary,
              cursorErrorColor:
                  errorMessage != null ? AppColorTokens.error : scheme.primary,
              validator: (value) {
                String? message =
                    widget.inputModel.validator?.call(value ?? '');
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
            style: bodyStyle,
          ),
        ],
        if (errorMessage != null) ...[
          Gap(3.h),
          Text(
            errorMessage!,
            style: bodyStyle.copyWith(
              fontWeight: FontWeight.w400,
              color: widget.errorMsgColor ?? AppColorTokens.error,
            ),
          ),
        ],
      ],
    );
  }
}
