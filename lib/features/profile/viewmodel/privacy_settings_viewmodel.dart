import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';
import 'package:kouvention/cores/utils/log.dart';

final privacySettingsVM = ChangeNotifierProvider.autoDispose<PrivacySettingsVM>(
  (ref) => PrivacySettingsVM(ref),
);

class PrivacySettingsVM extends BaseNotifier {
  final UserService _userService;
  final AuthService _authService;
  StreamSubscription? _userSubscription;
  UserModel? _user;

  PrivacySettingsVM(super.ref)
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
      onError: (e) => eLog('Privacy settings stream error: $e'),
    );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  PrivacySettings? get privacy => _user?.privacy;

  Future<void> toggleOnlineStatus() => _toggle((p) => p.copyWith(
    showOnlineStatus: !p.showOnlineStatus,
  ));

  Future<void> toggleLastSeen() => _toggle((p) => p.copyWith(
    showLastSeen: !p.showLastSeen,
  ));

  Future<void> toggleProfilePhoto() => _toggle((p) => p.copyWith(
    showProfilePhoto: !p.showProfilePhoto,
  ));

  Future<void> _toggle(PrivacySettings Function(PrivacySettings) update) async {
    if (_user == null) return;
    final current = _user!.privacy;
    final updated = update(current);

    _user = _user!.copyWith(privacy: updated);
    notifyListeners();

    try {
      await _userService.updatePrivacy(_user!.uid, updated);
    } catch (e) {
      _user = _user!.copyWith(privacy: current);
      notifyListeners();
    }
  }
}
