// Load only once to hold onboarding + privacy policy values from SharedPreferences
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final prefsGuardProvider = Provider<PrefsGuard>((ref) {
  throw UnimplementedError(
    'PrefsGuard must be initialized in main.dart '
    'using ProviderScope.overrideWithValue',
  );
});

class PrefsGuard extends ChangeNotifier {
  bool _onboardingSeen;
  bool _privacyPolicySeen;

  PrefsGuard({required bool onboardingSeen, required bool privacyPolicySeen})
    : _onboardingSeen = onboardingSeen,
      _privacyPolicySeen = privacyPolicySeen;

  // Getters
  bool get onboardingSeen => _onboardingSeen;
  bool get privacyPolicySeen => _privacyPolicySeen;

  // Update from user check in first time
  void markOnboardingSeen() {
    _onboardingSeen = true;
    notifyListeners();
  }

  void markPrivacyPolicySeen() {
    _privacyPolicySeen = true;
    notifyListeners();
  }

  // Reset onboarding when user decline policy
  void resetOnboarding() {
    _onboardingSeen = false;
    notifyListeners();
  }
}
