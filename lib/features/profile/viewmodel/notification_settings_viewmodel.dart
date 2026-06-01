import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

final notificationSettingsVM =
    ChangeNotifierProvider.autoDispose<NotificationSettingsVM>(
  (ref) => NotificationSettingsVM(ref),
);

class NotificationSettingsVM extends BaseNotifier {
  final UserService _userService;
  final AuthService _authService;
  StreamSubscription? _userSubscription;
  UserModel? _user;

  NotificationSettingsVM(super.ref)
    : _userService = ref.read(userServiceProvider),
      _authService = ref.read(authServiceProvider);

  @override
  FutureOr<void> init() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    _userSubscription = _userService.streamUser(uid).listen(
      (user) {
        _user = user;
        notifyListeners();
      },
      onError: (e) => debugPrint('Notification settings stream error: $e'),
    );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  bool get notificationsEnabled => _user?.notificationsEnabled ?? true;

  Future<void> toggle() async {
    if (_user == null) return;
    final current = notificationsEnabled;
    final updated = !current;

    _user = _user!.copyWith(notificationsEnabled: updated);
    notifyListeners();

    try {
      await _userService.updateNotificationsEnabled(_user!.uid, updated);
    } catch (e) {
      _user = _user!.copyWith(notificationsEnabled: current);
      notifyListeners();
    }
  }
}
