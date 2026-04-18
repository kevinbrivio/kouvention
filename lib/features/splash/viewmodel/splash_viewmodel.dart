import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/shared/viewmodel/prefs_viewmodel.dart';

final splashVM = ChangeNotifierProvider.autoDispose<SplashVM>(SplashVM.new);

class SplashVM extends BaseNotifier {
  SplashVM(super.ref) {
    ref.listen<PrefsVM>(prefsVM, (_, __) {
      notifyListeners();
    });
  }

  late final PrefsVM _prefsVM = ref.read(prefsVM);
  late final AuthService _authService = AuthService();

  bool get hasSeenOnboarding => _prefsVM.hasSeenOnboarding;
  bool get hasAcceptedPrivacyPolicy => _prefsVM.hasAcceptedPrivacyPolicy;
  bool get shouldShowOnboarding => !_prefsVM.hasSeenOnboarding;
  bool get shouldShowPrivacyPolicy => !_prefsVM.hasAcceptedPrivacyPolicy;

  // Auth flag
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  @override
  Future<void> init() async {
    await _prefsVM.loadPrefs();

    // Check whether user has token
    _isLoggedIn = await _authService.isLoggedIn;
    notifyListeners();
  }

  Future<void> markOnboardingSeen() async {
    await _prefsVM.markOnboardingSeen();
    notifyListeners();
  }

  Future<void> acceptPrivacyPolicy() async {
    await _prefsVM.acceptPrivacyPolicy();
    notifyListeners();
  }
}
