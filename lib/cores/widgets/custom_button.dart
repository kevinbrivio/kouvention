import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';

class Button extends StatefulWidget {
  final String text;
  final Widget? leadingWidget;
  final double widgetSpacing;
  final double rowSpacing;
  final double? width;
  final double? height;
  final MainAxisAlignment? alignment;
  final bool isSecondary;
  final bool isWhiteBackground;
  final bool isCancel;
  final bool showArrow;
  final TextStyle? textStyle;
  final bool loading;

  ///[onPressed] must be null to disable button
  final Function()? onPressed;
  final bool? isPressed;

  const Button({
    super.key,
    required this.text,
    this.isPressed,
    this.onPressed,
    this.leadingWidget,
    this.widgetSpacing = 10,
    this.rowSpacing = 0,
    this.width,
    this.height,
    this.alignment,
    this.isSecondary = false,
    this.isCancel = false,
    this.showArrow = false,
    this.isWhiteBackground = false,
    this.textStyle,
    this.loading = false,
  });

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  bool isButtonPressed = false;

  // Inlined button styles replacing the deleted button_theme.dart files.
  // All 4 variants share shape, padding, elevation, splash, minSize.
  // Differences: backgroundColor, foregroundColor.

  TextStyle get _buttonTextStyle => TextStyle(
    fontFamily: 'Asap',
    fontSize: 12.sp,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: Colors.white,
  );

  ButtonStyle _elevatedStyle(ColorScheme scheme) => ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: AppColorTokens.disabled,
        disabledForegroundColor: AppColorTokens.disabledText,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
        minimumSize: Size(double.minPositive, AppSizing.buttonHeight.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button.r),
        ),
        textStyle: _buttonTextStyle,
        splashFactory: InkRipple.splashFactory,
      );

  ButtonStyle _secondaryStyle(ColorScheme scheme) => ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.primary,
        disabledBackgroundColor: AppColorTokens.disabled,
        disabledForegroundColor: AppColorTokens.disabledText,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
        minimumSize: Size(double.minPositive, AppSizing.buttonHeight.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button.r),
        ),
        textStyle: _buttonTextStyle,
        splashFactory: InkRipple.splashFactory,
      );

  ButtonStyle _cancelStyle(ColorScheme scheme) => ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: AppColorTokens.disabled,
        disabledForegroundColor: AppColorTokens.disabledText,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
        minimumSize: Size(double.minPositive, AppSizing.buttonHeight.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button.r),
        ),
        textStyle: _buttonTextStyle,
        splashFactory: InkRipple.splashFactory,
      );

  ButtonStyle _whiteStyle() => ElevatedButton.styleFrom(
        backgroundColor: AppSurfaceLight.surface,
        foregroundColor: AppSurfaceLight.surface,
        disabledBackgroundColor: AppColorTokens.disabled,
        disabledForegroundColor: AppColorTokens.disabledText,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
        minimumSize: Size(double.minPositive, AppSizing.buttonHeight.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button.r),
        ),
        textStyle: _buttonTextStyle,
        splashFactory: InkRipple.splashFactory,
      );

  @override
  build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final ButtonStyle style = widget.isWhiteBackground
        ? _whiteStyle()
        : widget.isCancel
            ? _cancelStyle(scheme)
            : widget.isSecondary
                ? _secondaryStyle(scheme)
                : _elevatedStyle(scheme);

    final TextStyle textStyle = _buttonTextStyle;

    return SizedBox(
      width: widget.width,
      height: widget.height ?? AppSizing.buttonHeight.h,
      child: ElevatedButton(
        onPressed: widget.onPressed != null
            ? () async {
                if (isButtonPressed) return;
                if (widget.loading) return;
                isButtonPressed = true;
                FocusScope.of(context).unfocus();
                await widget.onPressed!();
                isButtonPressed = false;
              }
            : null,
        style: widget.loading
            ? style.copyWith(
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              )
            : style,
        child: Row(
          mainAxisAlignment: widget.alignment ?? MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: widget.rowSpacing,
          children: [
            if (widget.loading) ...[
              LoadingIndicator(
                indicatorSize: AppSizing.touchMin.w,
                indicatorColor: AppSurfaceLight.surface,
                strokeWidth: 2,
              ),
            ] else ...[
              if (widget.leadingWidget != null)
                Padding(
                  padding: EdgeInsets.only(right: widget.widgetSpacing),
                  child: widget.leadingWidget!,
                ),
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 4.h,
                ),
                child: Text(
                  widget.text,
                  style: widget.textStyle ?? textStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
