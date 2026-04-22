import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/shared/services/connectivity_service.dart';
import 'package:kouvention/features/shared/viewmodel/connectivity_viewmodel.dart';
import 'package:oktoast/oktoast.dart';

final loginProvider = ChangeNotifierProvider.autoDispose<LoginVM>(
  (ref) => LoginVM(ref),
);

class LoginVM extends BaseNotifier {
  final AuthService _authService;
  final ConnectivityService _connectivityService;

  LoginVM(super.ref)
    : _authService = ref.read(authServiceProvider),
      _connectivityService = ref.read(connectivityServiceProvider);

  @override
  FutureOr<void> init() {}

  Future<void> signInWithGoogle() async {
    final connected = await _connectivityService.isConnected;
    if (!connected) {
      showToast('No internet connection');
      return;
    }

    isLoading = true;
    try {
      await _authService.signInWithGoogle();
      if (ctx.mounted) {
        ctx.go(RouterRoutes.chatList.path);
      }
    } on AuthException catch (e) {
      debugPrint('Google sign in cancelled: $e');
    } catch (e) {
      showToast('Sign in failed. Please try again.');
    } finally {
      isLoading = false;
    }
  }

  void goToSignUp() {
    final context = ctx;
    if (!context.mounted) return;
    context.push(RouterRoutes.signUp.path);
  }

  void goToEmailSignIn() {
    final context = ctx;
    if (context.mounted) {
      context.push(RouterRoutes.emailSignIn.path);
    }
  }
}
