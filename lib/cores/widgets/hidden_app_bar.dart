import 'package:flutter/material.dart';
import 'package:kouvention/cores/utils/size_helper.dart';

class HiddenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Color backgroundColor;
  const HiddenAppBar({
    super.key,
    this.backgroundColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.only(top: statusBarHeight),
        height: preferredSize.height + statusBarHeight,
        color: backgroundColor,
      );

  @override
  Size get preferredSize => const Size(double.maxFinite, 0);
}
