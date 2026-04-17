import 'package:flutter/material.dart';

class RouterRoute {
  final String path;
  final String name;

  const RouterRoute({required this.path, required this.name});
}

class RouterRoutes {
  static const home = RouterRoute(
    path: '/',
    name: 'home'
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
BuildContext get ctx => navigatorKey.currentContext!;