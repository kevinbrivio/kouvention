import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/auth/views/login_view.dart';
import 'package:kouvention/features/onboarding/views/onboarding_view.dart';
import 'package:kouvention/features/splash/views/splash_view.dart';

late GoRouter _router;
GoRouter get router => _router;

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// ignore: inference_failure_on_function_return_type
setupRouter({required String initialRouter}) {
  _router = GoRouter(
    initialLocation: initialRouter,
    navigatorKey: navigatorKey,
    observers: [routeObserver],
    routes: [
      GoRoute(
        path: RouterRoutes.splash.path,
        name: RouterRoutes.splash.name,
        builder: (_, _) => SplashView(),
      ),
      GoRoute(
        path: RouterRoutes.login.path,
        name: RouterRoutes.login.name,
        builder: (_, _) => LoginView(),
      ),
      GoRoute(
        path: RouterRoutes.onboarding.path,
        name: RouterRoutes.onboarding.name,
        builder: (_, _) => OnboardingView(),
      ),
      // GoRoute(
      //   path: RouterRoutes.privacyPolicy.path,
      //   name: RouterRoutes.privacyPolicy.name,
      //   builder: (_, _) => const PrivacyPolicyView(),
      // ),
    ],
  );
}
