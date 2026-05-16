import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/router/prefs_guard.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';

final privacyPolicyVM = ChangeNotifierProvider.autoDispose(PrivacyPolicyVM.new);

class PrivacyPolicyVM extends BaseNotifier {
  PrivacyPolicyVM(super.ref);

  bool _isChecked = false;

  bool get isChecked => _isChecked;

  @override
  FutureOr<void> init() {}

  void toggleCheckbox() {
    _isChecked = !_isChecked;
    notifyListeners();
  }

  Future<void> acceptPolicy() async {
    final prefs = ref.read(prefsServiceProvider);
    await prefs.setHasAcceptedPrivacyPolicy(true);

    ref.read(prefsGuardProvider).markPrivacyPolicySeen();
  }

  Future<void> declinePolicy() async {
    final prefs = ref.read(prefsServiceProvider);
    await prefs.setHasAcceptedPrivacyPolicy(false);

    ref.read(prefsGuardProvider).resetOnboarding();
  }
}
