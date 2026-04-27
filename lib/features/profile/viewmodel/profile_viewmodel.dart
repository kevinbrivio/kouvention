import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

final profileVM = ChangeNotifierProvider.autoDispose<ProfileVM>(
  (ref) => ProfileVM(ref),
);

class ProfileVM extends BaseNotifier {
  final UserService _userService;
  final AuthService _authService;

  UserModel? _user;
  StreamSubscription? _userSubscription;

  ProfileVM(super.ref)
    : _userService = ref.read(userServiceProvider),
      _authService = ref.read(authServiceProvider);

  // Getters
  UserModel? get user => _user;

  String get authProviderLabel {
    final providerData = _authService.currentUser?.providerData ?? [];

    for (final info in providerData) {
      if (info.providerId == 'google.com') return 'Connected with Google';
      if (info.providerId == 'apple.com') return 'Connected with Apple';
    }

    return 'Email & Password';
  }

  bool get isGoogleLinked {
    final providerData = _authService.currentUser?.providerData ?? [];
    return providerData.any((info) => info.providerId == 'google.com');
  }

  @override
  FutureOr<void> init() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    _userSubscription = _userService
        .streamUser(uid)
        .listen(
          (userModel) {
            _user = userModel;
            notifyListeners();
          },
          onError: (e) {
            debugPrint("Profile stream error: $e");
          },
        );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
