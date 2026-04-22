import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/auth/views/add_name_view.dart';
import 'package:kouvention/features/auth/views/email_sign_in_view.dart';
import 'package:kouvention/features/auth/views/login_view.dart';
import 'package:kouvention/features/auth/views/sign_up_view.dart';
import 'package:kouvention/features/chat/views/chat_list_view.dart';
import 'package:kouvention/features/chat/views/chat_room_view.dart';
import 'package:kouvention/features/chat/views/new_chat_view.dart';
import 'package:kouvention/features/chat/views/new_group_chat_view.dart';
import 'package:kouvention/features/onboarding/views/onboarding_view.dart';
import 'package:kouvention/features/privacy_policy/views/privacy_policy_view.dart';
import 'package:kouvention/features/splash/views/splash_view.dart';

late GoRouter _router;
GoRouter get router => _router;

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// ignore: inference_failure_on_function_return_type
setupRouter({required String initialRouter, required AuthService authService}) {
  _router = GoRouter(
    initialLocation: initialRouter,
    navigatorKey: navigatorKey,
    observers: [routeObserver],
    redirect: (context, state) {
      final isLoggedIn = authService.currentUser != null;
      final currentPath = state.matchedLocation;
      debugPrint('ROUTER: path=$currentPath, isLoggedIn=$isLoggedIn');

      final publicRoutes = [
        RouterRoutes.splash.path,
        RouterRoutes.onboarding.path,
        RouterRoutes.privacyPolicy.path,
        RouterRoutes.login.path,
        RouterRoutes.signUp.path,
        RouterRoutes.emailSignIn.path,
      ];

      final isOnPublicRoute = publicRoutes.contains(currentPath);

      // Just signed in while on login/signup → go chat list
      if (isLoggedIn &&
          (currentPath == RouterRoutes.login.path ||
              currentPath == RouterRoutes.signUp.path ||
              currentPath == RouterRoutes.emailSignIn.path)) {
        return null;
      }

      // Not logged in and trying to access a protected route → login
      if (!isLoggedIn && !isOnPublicRoute) {
        return RouterRoutes.login.path;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouterRoutes.splash.path,
        name: RouterRoutes.splash.name,
        builder: (_, _) => const SplashView(),
      ),
      GoRoute(
        path: RouterRoutes.login.path,
        name: RouterRoutes.login.name,
        builder: (_, _) => LoginView(),
      ),
      GoRoute(
        path: RouterRoutes.emailSignIn.path,
        name: RouterRoutes.emailSignIn.name,
        builder: (_, _) => EmailSignInView(),
      ),
      GoRoute(
        path: RouterRoutes.addName.path,
        name: RouterRoutes.addName.name,
        builder: (_, _) => AddNameView(),
      ),
      GoRoute(
        path: RouterRoutes.signUp.path,
        name: RouterRoutes.signUp.name,
        builder: (_, _) => SignUpView(),
      ),
      GoRoute(
        path: RouterRoutes.onboarding.path,
        name: RouterRoutes.onboarding.name,
        builder: (_, _) => const OnboardingView(),
      ),
      GoRoute(
        path: RouterRoutes.privacyPolicy.path,
        name: RouterRoutes.privacyPolicy.name,
        builder: (_, _) => PrivacyPolicyView(),
      ),
      GoRoute(
        path: RouterRoutes.chatList.path,
        name: RouterRoutes.chatList.name,
        builder: (_, _) => ChatListView(),
      ),
      GoRoute(
        path: RouterRoutes.chatRoom.path,
        name: RouterRoutes.chatRoom.name,
        builder: (_, state) {
          final chatId = state.pathParameters['chatId']!;
          return ChatRoomView(chatId: chatId);
        },
      ),
      GoRoute(
        path: RouterRoutes.newChat.path,
        name: RouterRoutes.newChat.name,
        builder: (_, _) => NewChatView(),
      ),
      GoRoute(
        path: RouterRoutes.newGroupChat.path,
        name: RouterRoutes.newGroupChat.name,
        builder: (_, _) => NewGroupChatView(),
      ),
    ],
  );
}
