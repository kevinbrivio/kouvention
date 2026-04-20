import 'package:flutter/material.dart';
import 'package:kouvention/cores/router/router.dart';

double get statusBarHeight {
  BuildContext? context = router.routerDelegate.navigatorKey.currentContext;
  return context != null ? MediaQuery.of(context).viewPadding.top : 0.0;
}
