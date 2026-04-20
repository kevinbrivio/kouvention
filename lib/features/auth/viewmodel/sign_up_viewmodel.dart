import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_form_notifier.dart';
import 'package:kouvention/cores/mixins/form_validator_mixin.dart';
import 'package:kouvention/cores/models/text_input_model.dart';
import 'package:kouvention/features/auth/models/sign_up_form.dart';
import 'package:kouvention/features/shared/services/connectivity_service.dart';
import 'package:kouvention/features/shared/viewmodel/connectivity_viewmodel.dart';

final signUpProvider = ChangeNotifierProvider.autoDispose<SignUpVM>(
  (ref) => SignUpVM(ref),
);

class SignUpVM extends BaseFormNotifier<SignUpForm> with FormValidatorMixin {
  final ConnectivityService _connectivityService;

  SignUpVM(super.ref)
    : _connectivityService = ref.read(connectivityServiceProvider);

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
    debugPrint('EMAIL : ${form.email.text.length}');
    debugPrint('PASSWORD : ${form.password.text}');
    debugPrint('2. Is Valid: $isValid');
    if (!isValid) return;

    debugPrint('3. reach signup logic');
    isLoading = true;
    try {
      // Simulate
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
    } finally {
      isLoading = false;
    }
  }
}
