import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/router/router_constants.dart';

final loginProvider = ChangeNotifierProvider.autoDispose<LoginVM>(
  (ref) => LoginVM(ref),
);

class LoginVM extends BaseNotifier {
  LoginVM(super.ref);

  @override
  FutureOr<void> init() {}

  Future<void> signInWithGoogle() async {}

  void goToSignUp() {
    final context = ctx;
    if (!context.mounted) return;
    context.push(RouterRoutes.signUp.path);
  }
}
