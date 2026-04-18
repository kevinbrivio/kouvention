import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/button_theme.dart/cancel_button_theme.dart';
import 'package:kouvention/cores/constants/button_theme.dart/elevated_button_theme.dart';
import 'package:kouvention/cores/constants/button_theme.dart/secondary_button_theme.dart';
import 'package:kouvention/cores/constants/button_theme.dart/white_button_theme.dart';
import 'package:kouvention/cores/constants/colors.dart';
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

  @override
  build(BuildContext context) {
    ButtonStyle style = widget.isWhiteBackground
        ? whiteButtonTheme.style!
        : widget.isCancel
            ? cancelButtonTheme.style!
            : widget.isSecondary
                ? secondaryElevatedButtonTheme.style!
                : elevatedButtonTheme.style!;
    TextStyle textStyle = style.textStyle!.resolve({})!;
    return SizedBox(
      width: widget.width,
      height: widget.height ?? 48.h,
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
                overlayColor: MaterialStateProperty.all(Colors.transparent),
              )
            : style,
        child: Row(
          mainAxisAlignment: widget.alignment ?? MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: widget.rowSpacing,
          children: [
            if (widget.loading) ...[
              LoadingIndicator(
                indicatorSize: 48.w,
                indicatorColor: AppColors.white,
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

            // if (widget.showArrow)
            //   Padding(
            //     padding: EdgeInsets.only(left: widget.widgetSpacing),
            //     child: SvgPicture.asset(
            //       images.next,
            //       color: widget.isSecondary ? colors.primary : null,
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }
}
