import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_form_notifier.dart';
import 'package:kouvention/cores/mixins/form_validator_mixin.dart';
import 'package:kouvention/cores/models/text_input_model.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/auth/models/email_sign_in_form.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/shared/services/connectivity_service.dart';
import 'package:kouvention/features/shared/services/fcm_service.dart';
import 'package:kouvention/features/shared/viewmodel/connectivity_viewmodel.dart';
import 'package:kouvention/features/user/services/user_service.dart';
import 'package:oktoast/oktoast.dart';

final emailSignInVM = ChangeNotifierProvider.autoDispose<EmailSignInVM>(
  (ref) => EmailSignInVM(ref),
);

class EmailSignInVM extends BaseFormNotifier<EmailSignInForm>
    with FormValidatorMixin {
  final AuthService _authService;
  final ConnectivityService _connectivityService;
  final UserService _userService;

  EmailSignInVM(super.ref)
    : _authService = ref.read(authServiceProvider),
      _connectivityService = ref.read(connectivityServiceProvider),
      _userService = ref.read(userServiceProvider);

  // password visibility
  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  @override
  late EmailSignInForm form;

  @override
  FutureOr<void> init() {
    form = EmailSignInForm(
      email: TextInputModel(
        validator: (val) => getValidation(
          value: val,
          label: 'Email',
          validationList: [Validator.emailFormat],
        ),
      ),
      password: TextInputModel(
        validator: (val) => getValidation(
          value: val,
          label: 'Password',
          validationList: [
            Validator.length,
            Validator.number,
            Validator.uppercase,
            Validator.lowercase,
          ],
        ),
      ),
    );
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  Future<void> signIn() async {
    if (!validate()) return;

    final connected = await _connectivityService.isConnected;
    if (!connected) {
      showToast('No internet connection');
      return;
    }

    isLoading = true;
    try {
      final credential = await _authService.signInWithEmail(
        email: form.email.text,
        password: form.password.untrimmedText,
      );

      // Check whether user already registered inside user docs
      final hasProfile = await _userService.userDocExists(credential.user!.uid);
      if (ctx.mounted) {
        // Set user token to FCM
        final fcmService = ref.read(fcmServiceProvider);
        await fcmService.initialize();

        if (hasProfile) {
          if (ctx.mounted) ctx.go(RouterRoutes.chatList.path);
        } else {
          if (ctx.mounted) ctx.go(RouterRoutes.addName.path);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential') {
        showToast('Incorrect email or password.');
      } else {
        showToast(_mapFirebaseError(e.code));
      }
    } catch (e) {
      showToast('Sign in failed. Please try again.');
    } finally {
      isLoading = false;
    }
  }

  String _mapFirebaseError(String code) => switch (code) {
    'user-not-found' => 'No account found with this email.',
    'wrong-password' => 'Incorrect password.',
    'invalid-credential' => 'Invalid email or password.',
    'user-disabled' => 'This account has been disabled.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    _ => 'Sign in failed. Please try again.',
  };
}
