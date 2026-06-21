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
  static const profile = RouterRoute(path: '/profile', name: 'profile');
  static const editName = RouterRoute(
    path: '/profile/edit-name',
    name: 'editName',
  );
  static const editStatus = RouterRoute(
    path: '/profile/edit-status',
    name: 'editStatus',
  );
  static const privacySettings = RouterRoute(
    path: '/profile/privacy',
    name: 'privacySettings',
  );
  static const notificationSettings = RouterRoute(
    path: '/profile/notifications',
    name: 'notificationSettings',
  );
  static const appearanceSettings = RouterRoute(
    path: '/profile/appearance',
    name: 'appearanceSettings',
  );

  static const login = RouterRoute(path: '/login', name: 'login');
  static const signUp = RouterRoute(path: '/sign-up', name: 'signup');
  static const emailSignIn = RouterRoute(path: '/email', name: 'emailSignIn');
  static const addName = RouterRoute(path: '/add-name', name: 'addName');

  static const chatList = RouterRoute(path: '/chats', name: 'chatList');
  static const storyFeed = RouterRoute(path: '/stories', name: 'storyFeed');
  static const storyViewer = RouterRoute(
    path: '/stories/viewer',
    name: 'storyViewer',
  );
  static const chatRoom = RouterRoute(path: '/chats/:chatId', name: 'chatRoom');
  static const newChat = RouterRoute(path: '/new-chat', name: 'newChat');
  static const newGroupChat = RouterRoute(
    path: '/new-chat/group',
    name: 'newGroupChat',
  );
  static const groupSetup = RouterRoute(
    path: '/new-chat/group/setup',
    name: 'groupSetup',
  );
  static const chatDetail = RouterRoute(
    path: '/chats/:chatId/detail',
    name: 'chatDetail',
  );
  static const mediaPreview = RouterRoute(
    path: '/chats/:chatId/media-preview',
    name: 'mediaPreview',
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
BuildContext get ctx => navigatorKey.currentContext!;
