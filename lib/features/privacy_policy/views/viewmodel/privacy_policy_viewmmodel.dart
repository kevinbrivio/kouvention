import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/router/router_constants.dart';

final privacyPolicyVM = ChangeNotifierProvider.autoDispose(PrivacyPolicyVM.new);

class PrivacyPolicyVM extends BaseNotifier {
  PrivacyPolicyVM(super.ref);

  @override
  FutureOr<void> init() {}
  
  void goToLogin() {
    ctx.go(RouterRoutes.login.path);
  }
}
