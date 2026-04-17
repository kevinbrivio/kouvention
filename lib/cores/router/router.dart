import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/router/router_constants.dart';

late GoRouter _router;
GoRouter get router => _router;

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void setupRouter({required String initialRouter}) {
  _router = GoRouter(
    initialLocation: initialRouter,
    navigatorKey: navigatorKey,
    observers: [routeObserver],
    routes: [],
  );
}
