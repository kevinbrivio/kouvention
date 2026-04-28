import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/shared/services/fcm_service.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';

final splashVM = ChangeNotifierProvider.autoDispose<SplashVM>(SplashVM.new);

class SplashVM extends BaseNotifier {
  SplashVM(super.ref);

  late final PrefsService _prefsService = ref.read(prefsServiceProvider);
  late final AuthService _authService = ref.read(authServiceProvider);

  bool _hasSeenOnboarding = false;
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  bool _hasAcceptedPrivacyPolicy = false;
  bool get hasAcceptedPrivacyPolicy => _hasAcceptedPrivacyPolicy;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String? _nextRoute;
  String? get nextRoute => _nextRoute;

  @override
  Future<void> init() async {
    _hasSeenOnboarding = await _prefsService.hasSeenOnboarding();
    _hasAcceptedPrivacyPolicy = await _prefsService.hasAcceptedPrivacyPolicy();
    _isLoggedIn = await _authService.isLoggedIn;
    
    if (_isLoggedIn) {
      final fcmService = ref.read(fcmServiceProvider);
      await fcmService.initialize();
    }

    _nextRoute = _resolveInitialRoute();
    notifyListeners();
  }

  String _resolveInitialRoute() {
    if (!_hasSeenOnboarding) {
      return RouterRoutes.onboarding.path;
    }

    if (_isLoggedIn) {
      return RouterRoutes.chatList.path;
    }

    if (!_hasAcceptedPrivacyPolicy) {
      return RouterRoutes.privacyPolicy.path;
    }

    return RouterRoutes.login.path;
  }
}
