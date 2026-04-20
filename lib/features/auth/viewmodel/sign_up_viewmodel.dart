import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_form_notifier.dart';
import 'package:kouvention/cores/mixins/form_validator_mixin.dart';
import 'package:kouvention/cores/models/text_input_model.dart';
import 'package:kouvention/features/auth/models/sign_up_form.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/shared/services/connectivity_service.dart';
import 'package:kouvention/features/shared/viewmodel/connectivity_viewmodel.dart';
import 'package:oktoast/oktoast.dart';

final signUpProvider = ChangeNotifierProvider.autoDispose<SignUpVM>(
  (ref) => SignUpVM(ref),
);

class SignUpVM extends BaseFormNotifier<SignUpForm> with FormValidatorMixin {
  final ConnectivityService _connectivityService;
  final AuthService _authService;

  SignUpVM(super.ref)
    : _connectivityService = ref.read(connectivityServiceProvider),
      _authService = ref.read(authServiceProvider);

  // password visibility
  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  @override
  late SignUpForm form;

  @override
  FutureOr<void> init() {
    form = SignUpForm(
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

  Future<void> signUp() async {
    final connected = await _connectivityService.isConnected;
    if (!connected) {
      _isOffline = true;
      notifyListeners();
      return;
    }
    _isOffline = false;

    // validate
    final isValid = validate();
    if (!isValid) return;

    isLoading = true;
    try {
      await _authService.signUpWithEmail(
        email: form.email.text,
        password: form.password.text,
      );
      debugPrint('SIGNUP: success, currentUser=${_authService.currentUser}');
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'email-already-in-use' => 'This email is already registered',
        'invalid-email' => 'Invalid email address',
        'weak-password' => 'Password is too weak',
        _ => 'Sign up failed. Please try again.',
      };

      showToast(message);
    } catch (e) {
      showToast('Something went wrong. Please try again.');
    } finally {
      isLoading = false;
    }
  }
}
