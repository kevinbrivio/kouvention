import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_form_notifier.dart';
import 'package:kouvention/cores/mixins/form_validator_mixin.dart';
import 'package:kouvention/cores/models/text_input_model.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/user/services/user_service.dart';

class EditNameForm {
  final TextInputModel name;

  EditNameForm({required this.name});
}

final editNameVM = ChangeNotifierProvider.autoDispose<EditNameVM>(
  (ref) => EditNameVM(ref),
);

class EditNameVM extends BaseFormNotifier<EditNameForm>
    with FormValidatorMixin {
  final UserService _userServiceProvider;
  final String? _currentUid;
  String? _currentName;

  EditNameVM(super.ref)
    : _userServiceProvider = ref.read(userServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  @override
  late EditNameForm form;

  // GETTER
  String? get currentUid => _currentUid;
  String? get currentName => _currentName;

  @override
  FutureOr<void> init() async {
    _currentName = ref.read(authServiceProvider).currentUser?.displayName;
    form = EditNameForm(
      name: TextInputModel(
        validator: (val) =>
            getValidation(label: 'Your name', value: val, validationList: []),
      ),
    );
  }

  Future<void> editName(BuildContext context) async {
    if (_currentUid == null) return;
    // validate form
    if (!validate()) return;

    try {
      isLoading = true;
      final name = form.name.text;

      await _userServiceProvider.updateProfile(
        uid: _currentUid,
        displayName: name,
      );

      if (context.mounted) {
        context.pop();
      }
    } catch (e, s) {
      debugPrint('error on editting name: $e');
      print(s);
    } finally {
      isLoading = false;
    }
  }
}
