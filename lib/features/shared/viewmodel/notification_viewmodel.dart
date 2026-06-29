import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';
import 'package:kouvention/cores/utils/log.dart';

enum NotificationPermissionState { granted, denied, notDetermined }

final notificationPermissionProvider =
    StateNotifierProvider<NotificationPermissionVM, NotificationPermissionState>(
  (ref) => NotificationPermissionVM(ref),
);

class NotificationPermissionVM extends StateNotifier<NotificationPermissionState> {
  final Ref _ref;

  NotificationPermissionVM(this._ref) : super(NotificationPermissionState.notDetermined);

  NotificationPermissionState get currentState => state;

  static const _ringtoneChannel = MethodChannel('kouvention/ringtone_picker');

  Future<void> checkPermission() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    state = settings.authorizationStatus == AuthorizationStatus.authorized
        ? NotificationPermissionState.granted
        : NotificationPermissionState.denied;
  }

  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: false,
      sound: true,
    );
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized;
    final prefs = _ref.read(prefsServiceProvider);
    await prefs.setNotificationPermissionDenied(!granted);
    state = granted ? NotificationPermissionState.granted : NotificationPermissionState.denied;
    return granted;
  }

  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  Future<Map<String, String>?> pickSystemRingtone(String? currentUri) async {
    try {
      final result = await _ringtoneChannel.invokeMethod<Map<dynamic, dynamic>>(
        'pickRingtone',
        {'currentUri': currentUri},
      );
      if (result == null) return null;
      return {
        'uri': result['uri'] as String,
        'displayName': result['displayName'] as String,
      };
    } catch (e) {
      eLog('Ringtone picker failed: $e');
      return null;
    }
  }
}
