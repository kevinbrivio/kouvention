import 'package:flutter/material.dart';
import 'package:kouvention/cores/router/auth_notifier.dart';
import 'package:kouvention/cores/router/prefs_guard.dart';

class RouterGuard extends ChangeNotifier {
  final AuthNotifier _authNotifier;
  final PrefsGuard _prefsGuard;

  RouterGuard({
    required AuthNotifier authNotifier,
    required PrefsGuard prefsGuard,
  }) : _authNotifier = authNotifier,
       _prefsGuard = prefsGuard {
    // If on of these call notifyListeners,
    // RouterGuard will enable redirect from GoRouter
    _authNotifier.addListener(notifyListeners);
    _prefsGuard.addListener(notifyListeners);
  }

  // Getters
  bool get isLoggedIn => _authNotifier.isLoggedIn;
  bool get hasDisplayName => _authNotifier.hasDisplayName;
  bool get onboardingSeen => _prefsGuard.onboardingSeen;
  bool get privacyPolicySeen => _prefsGuard.privacyPolicySeen;

  @override
  void dispose() {
    _authNotifier.removeListener(notifyListeners);
    _prefsGuard .removeListener(notifyListeners);
    super.dispose();
  }
}
