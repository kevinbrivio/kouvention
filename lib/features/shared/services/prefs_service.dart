import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final prefsServiceProvider = Provider<PrefsService>((ref) {
  throw UnimplementedError(
    'PrefsService must be initialized in main.dart using ProviderScope.overrideWithValue',
  );
});

class PrefsService {
  final SharedPreferences _prefs;

  const PrefsService(this._prefs);

  // --- KEYS
  static const String _onboardingKey = 'has_seen_onboarding';
  static const String _privacyPolicyKey = 'has_accepted_privacy_policy';
  static const String _fcmTokenKey = 'fcm_tokens';
  static const String _lastSyncedKey = 'search_last_sync_time';
  static const String _deviceIdKey = 'device_id';
  static const String _notificationDeniedKey = 'notification_permission_denied';
  static const String _notificationSoundKey = 'notification_sound_chat';

  // --- ONBOARDING
  Future<bool> hasSeenOnboarding() async =>
      _prefs.getBool(_onboardingKey) ?? false;

  Future<bool> setHasSeenOnboarding(bool value) async =>
      _prefs.setBool(_onboardingKey, value);

  // --- PRIVACY POLICY
  Future<bool> hasAcceptedPrivacyPolicy() async =>
      _prefs.getBool(_privacyPolicyKey) ?? false;

  Future<bool> setHasAcceptedPrivacyPolicy(bool value) async =>
      _prefs.setBool(_privacyPolicyKey, value);

  // --- FCM
  String? getFcmToken() => _prefs.getString(_fcmTokenKey);

  Future<bool> setFcmToken(String val) async =>
      _prefs.setString(_fcmTokenKey, val);

  Future<bool> removeFcmToken() async => _prefs.remove(_fcmTokenKey);

  // --- SEARCH LAST SYNC
  DateTime? get lastSynced {
    final millis = _prefs.getInt(_lastSyncedKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  set lastSyncTime(DateTime? value) {
    if (value == null) {
      _prefs.remove(_lastSyncedKey);
    } else {
      _prefs.setInt(_lastSyncedKey, value.millisecondsSinceEpoch);
    }
  }

  // --- DEVICE ID
  Future<bool> setDeviceId(String val) => _prefs.setString(_deviceIdKey, val);
  String? deviceId() => _prefs.getString(_deviceIdKey);

  // --- NOTIFICATION PERMISSION
  bool get notificationPermissionDenied =>
      _prefs.getBool(_notificationDeniedKey) ?? false;

  Future<void> setNotificationPermissionDenied(bool value) async =>
      _prefs.setBool(_notificationDeniedKey, value);

  // --- NOTIFICATION SOUND (for future per-type settings)
  String? get notificationSound => _prefs.getString(_notificationSoundKey);

  Future<void> setNotificationSound(String value) async =>
      _prefs.setString(_notificationSoundKey, value);
}
