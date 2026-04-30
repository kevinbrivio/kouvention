import 'package:kouvention/cores/bases/base_notifier.dart';

mixin FormValidatorMixin on BaseNotifier {
  final RegExp passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');

  final RegExp emailRegex = RegExp(
    r'^[\w-\.]+@[a-zA-Z0-9-]+(\.[a-zA-Z]{2,})+$',
  );

  String? getValidation({
    required String value,
    required String label,
    required List<Validator> validationList,
    String? confirmValue,
    List<String>? confirmList,
    Function()? setPhoneBorderError,
    bool isRequired = true,
  }) {
    // Empty validation
    if (value.isEmpty && isRequired) {
      return '$label cannot be empty';
    }

    if (value.isEmpty && !isRequired) {
      return null;
    }

    // Length / 8 Characters validation
    if (validationList.contains(Validator.length) && value.length < 8) {
      return '$label must be at least 8 characters long';
    }

    // Uppercase validation
    if (validationList.contains(Validator.uppercase) &&
        !value.contains(RegExp(r'[A-Z]'))) {
      return '$label must contain an uppercase letter';
    }

    // Lowercase validation
    if (validationList.contains(Validator.lowercase) &&
        !value.contains(RegExp(r'[a-z]'))) {
      return '$label must contain a lowercase letter';
    }

    // Number validation
    if (validationList.contains(Validator.number) &&
        !value.contains(RegExp(r'\d'))) {
      return '$label must contain a number';
    }

    // Email format validation
    if (validationList.contains(Validator.emailFormat) &&
        !emailRegex.hasMatch(value)) {
      return '$label format is invalid';
    }

    // Password validation
    if (validationList.contains(Validator.password) &&
        !passwordRegex.hasMatch(value)) {
      return '$label format is invalid';
    }

    // Confirm value validation (e.g. confirm password)
    if (confirmValue != null && value != confirmValue) {
      return '$label does not match';
    }

    // Confirm list validation (e.g. value must match one of the entries)
    if (confirmList != null && !confirmList.contains(value)) {
      return '$label not found in the list';
    }

    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    // Standard email regex — covers 99% of real addresses
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null; // null means valid
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}

enum Validator { length, uppercase, lowercase, number, emailFormat, password }
