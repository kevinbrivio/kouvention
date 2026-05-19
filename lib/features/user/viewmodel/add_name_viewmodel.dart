// lib/features/profile/viewmodel/add_name_viewmodel.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_form_notifier.dart';
import 'package:kouvention/cores/mixins/form_validator_mixin.dart';
import 'package:kouvention/cores/models/text_input_model.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/shared/services/fcm_service.dart';
import 'package:kouvention/features/user/models/add_name_form.dart';
import 'package:kouvention/features/user/services/user_service.dart';
import 'package:oktoast/oktoast.dart';

final addNameVM = ChangeNotifierProvider.autoDispose<AddNameVM>(
  (ref) => AddNameVM(ref),
);

class AddNameVM extends BaseFormNotifier<AddNameForm> with FormValidatorMixin {
  final AuthService _authService;
  final UserService _userService;

  AddNameVM(super.ref)
    : _authService = ref.read(authServiceProvider),
      _userService = ref.read(userServiceProvider);

  @override
  late AddNameForm form;

  @override
  FutureOr<void> init() {
    form = AddNameForm(
      displayName: TextInputModel(
        validator: (val) =>
            getValidation(label: 'Name', value: val, validationList: []),
      ),
    );
  }

  Future<void> submit() async {
    if (!validate()) return;

    final user = _authService.currentUser;
    if (user == null) {
      showToast('Session expired. Please sign in again.');
      if (ctx.mounted) ctx.go(RouterRoutes.login.path);
      return;
    }

    isLoading = true;
    try {
      // Create the Firestore user doc (source of truth)
      await _userService.createUser(
        uid: user.uid,
        displayName: form.displayName.text,
        email: user.email ?? '',
      );

      // Register fcm tokens
      final fcmService = ref.read(fcmServiceProvider);
      await fcmService.initialize();

      // Also mirror to Firebase Auth for convenience
      await user.updateDisplayName(form.displayName.text);

      if (ctx.mounted) {
        ctx.go(RouterRoutes.chatList.path);
      }
    } catch (e) {
      showToast('Something went wrong. Please try again.');
    } finally {
      isLoading = false;
    }
  }
}
