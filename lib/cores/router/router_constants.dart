import 'package:flutter/material.dart';

class RouterRoute {
  final String path;
  final String name;

  const RouterRoute({required this.path, required this.name});
}

class RouterRoutes {
  static const splash = RouterRoute(path: '/', name: 'splash');
  static const onboarding = RouterRoute(
    path: '/onboarding',
    name: 'onboarding',
  );
  static const privacyPolicy = RouterRoute(
    path: '/privacy-policy',
    name: 'privacy-policy',
  );
  static const login = RouterRoute(path: '/login', name: 'login');
  static const signUp = RouterRoute(path: '/sign-up', name: 'signup');

  static const chatList = RouterRoute(path: '/chats', name: 'chatList');
  static const chatRoom = RouterRoute(path: '/chats/:chatId', name: 'chatRoom');
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
BuildContext get ctx => navigatorKey.currentContext!;
