import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/auth/views/login_view.dart';
import 'package:kouvention/features/auth/views/sign_up_view.dart';
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
      ];

      final isOnPublicRoute = publicRoutes.contains(currentPath);

      // Just signed in while on login/signup → go home
      if (isLoggedIn && (
          currentPath == RouterRoutes.login.path ||
          currentPath == RouterRoutes.signUp.path)) {
        return RouterRoutes.home.path;
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
    ],
  );
}
