import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';

final privacyPolicyVM = ChangeNotifierProvider.autoDispose(PrivacyPolicyVM.new);

class PrivacyPolicyVM extends BaseNotifier {
  PrivacyPolicyVM(super.ref);

  late final PrefsService _prefsService = ref.read(prefsServiceProvider);

  @override
  FutureOr<void> init() {}

  Future<void> acceptAndContinue() async {
    final context = ctx;
    await _prefsService.setHasAcceptedPrivacyPolicy(true);
    if (!context.mounted) return;
    context.go(RouterRoutes.login.path);
  }
}
