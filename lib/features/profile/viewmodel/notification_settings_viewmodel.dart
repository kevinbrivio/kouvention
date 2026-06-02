import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/shared/services/connectivity_service.dart';
import 'package:kouvention/features/shared/services/fcm_service.dart';
import 'package:kouvention/features/shared/viewmodel/connectivity_viewmodel.dart';
import 'package:kouvention/features/shared/viewmodel/notification_viewmodel.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';
import 'package:oktoast/oktoast.dart';

final notificationSettingsVM =
    ChangeNotifierProvider.autoDispose<NotificationSettingsVM>(
      (ref) => NotificationSettingsVM(ref),
    );

class NotificationSettingsVM extends BaseNotifier {
  final UserService _userService;
  final AuthService _authService;
  final FcmService _fcmService;
  final ConnectivityService _connectivityService;
  final NotificationPermissionVM _permissionVM;
  StreamSubscription? _userSubscription;
  UserModel? _user;

  NotificationPermissionState _osPermission =
      NotificationPermissionState.notDetermined;
  bool _reconciled = false;
  bool _reenableOnGrant = false;

  NotificationSettingsVM(super.ref)
    : _userService = ref.read(userServiceProvider),
      _authService = ref.read(authServiceProvider),
      _fcmService = ref.read(fcmServiceProvider),
      _connectivityService = ref.read(connectivityServiceProvider),
      _permissionVM = ref.read(notificationPermissionProvider.notifier);

  @override
  FutureOr<void> init() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    await _checkOSPermission();

    _userSubscription = _userService.streamUser(uid).listen((user) {
      _user = user;
      if (!_reconciled) {
        _reconciled = true;
        _reconcileOSPermission();
      }
      notifyListeners();
    }, onError: (e) => debugPrint('Notification settings stream error: $e'));
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  bool get notificationsEnabled => _user?.notificationsEnabled ?? true;

  bool get osPermissionGranted =>
      _osPermission == NotificationPermissionState.granted;

  Future<void> _checkOSPermission() async {
    await _permissionVM.checkPermission();
    _osPermission = _permissionVM.currentState;
  }

  Future<void> _reconcileOSPermission() async {
    if (_user == null) return;
    if (!osPermissionGranted && _user!.notificationsEnabled) {
      try {
        await _userService.updateNotificationsEnabled(_user!.uid, false);
        _user = _user!.copyWith(notificationsEnabled: false);
        _reenableOnGrant = true;
      } catch (e) {
        debugPrint('Failed to reconcile notification permission: $e');
      }
    }
  }

  Future<void> toggle() async {
    if (_user == null) return;
    _reenableOnGrant = false;

    final connected = await _connectivityService.isConnected;
    if (!connected) {
      showToast('No internet connection. Please check your network and try again.');
      return;
    }

    // If toggling ON but OS permission denied — let the UI handle it
    final current = notificationsEnabled;
    final updated = !current;
    if (updated && !osPermissionGranted) return;

    _user = _user!.copyWith(notificationsEnabled: updated);
    notifyListeners();

    try {
      await _userService.updateNotificationsEnabled(_user!.uid, updated);

      if (updated) {
        await _fcmService.saveToken();
      } else {
        await _fcmService.removeToken();
      }
    } catch (e) {
      _user = _user!.copyWith(notificationsEnabled: current);
      notifyListeners();
      showToast('Failed to update notification settings');
    }
  }

  Future<void> refreshPermission() async {
    await _checkOSPermission();
    if (!_reconciled && _user != null) {
      _reconciled = true;
      _reconcileOSPermission();
    } else if (_reconciled &&
        !osPermissionGranted &&
        _user?.notificationsEnabled == true) {
      _reconcileOSPermission();
    }

    if (osPermissionGranted && _reenableOnGrant && _user != null && !_user!.notificationsEnabled) {
      try {
        await _userService.updateNotificationsEnabled(_user!.uid, true);
        _user = _user!.copyWith(notificationsEnabled: true);
        await _fcmService.saveToken();
        _reenableOnGrant = false;
      } catch (e) {
        debugPrint('Failed to restore notification permission: $e');
      }
    }

    notifyListeners();
  }

  Future<void> openAppSettings() async {
    await _permissionVM.openSystemSettings();
    await refreshPermission();
  }
}
