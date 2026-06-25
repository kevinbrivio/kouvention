import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_form_notifier.dart';
import 'package:kouvention/cores/mixins/form_validator_mixin.dart';
import 'package:kouvention/cores/models/text_input_model.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/profile/views/edit_status_view..dart';
import 'package:kouvention/features/user/services/user_service.dart';

class EditStatusForm {
  final TextInputModel status;

  EditStatusForm({required this.status});
}

final editStatusVM = ChangeNotifierProvider.autoDispose<EditStatusVM>(
  (ref) => EditStatusVM(ref),
);

class EditStatusVM extends BaseFormNotifier<EditStatusForm>
    with FormValidatorMixin {
  final UserService _userServiceProvider;
  final String? _currentUid;
  String? _currentStatus;

  EditStatusVM(super.ref)
    : _userServiceProvider = ref.read(userServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  @override
  late EditStatusForm form;

  // GETTER
  String? get currentUid => _currentUid;
  String? get currentStatus => _currentStatus;

  @override
  FutureOr<void> init() async {
    _currentStatus = ref.read(authServiceProvider).currentUser?.displayName;
    form = EditStatusForm(
      status: TextInputModel(
        validator: (val) =>
            getValidation(label: '', value: val, validationList: []),
      ),
    );
  }

  void onStatusSelected(DefaultStatus status) {
    _currentStatus = status.label;
    form.status.controller.text = '${status.emoji} ${status.label}';
    notifyListeners();
  }

  Future<void> editStatus(BuildContext context) async {
    if (_currentUid == null) return;
    // validate form
    if (!validate()) return;

    try {
      isLoading = true;
      final status = form.status.text;

      await _userServiceProvider.updateProfile(uid: _currentUid, bio: status);

      if (context.mounted) {
        context.pop();
      }
    } catch (e) {
      debugPrint('error on editting name: $e');
    } finally {
      isLoading = false;
    }
  }
}
