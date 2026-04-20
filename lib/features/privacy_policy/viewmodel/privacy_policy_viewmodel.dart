import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/router/router_constants.dart';
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
    final context = ctx;
    final prefs = ref.read(prefsServiceProvider);
    await prefs.setHasAcceptedPrivacyPolicy(true);
    // navigate to login
    if (!context.mounted) return;
    context.go(RouterRoutes.login.path);
  }

  void declinePolicy() {
    // exit the app
    SystemNavigator.pop();
  }
}
