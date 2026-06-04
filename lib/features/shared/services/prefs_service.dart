import 'package:flutter/material.dart';
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
  static const String _notificationVibrationKey =
      'notification_vibration_enabled';
  static const String _themeModeKey = 'theme_mode';
  static const String _bubbleSchemeKey = 'bubble_color_scheme';
  static const String _wallpaperPathKey = 'chat_wallpaper_path';

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

  // --- NOTIFICATION CHANNEL — DM
  static const String _dmChannelKey = 'pref_dm_channel';
  static const String _groupChannelKey = 'pref_group_channel';

  String get dmChannelId => _prefs.getString(_dmChannelKey) ?? 'dm_default';

  Future<void> setDmChannelId(String value) async =>
      _prefs.setString(_dmChannelKey, value);

  String? get groupChannelId => _prefs.getString(_groupChannelKey);

  Future<void> setGroupChannelId(String? value) async {
    if (value != null) {
      await _prefs.setString(_groupChannelKey, value);
    } else {
      await _prefs.remove(_groupChannelKey);
    }
  }

  // --- NOTIFICATION VIBRATION
  bool get notificationVibrationEnabled =>
      _prefs.getBool(_notificationVibrationKey) ?? true;

  Future<void> setNotificationVibrationEnabled(bool value) async =>
      _prefs.setBool(_notificationVibrationKey, value);

  // --- THEME MODE
  ThemeMode getThemeMode() {
    final val = _prefs.getString(_themeModeKey);
    switch (val) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final val = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      _ => 'system',
    };
    await _prefs.setString(_themeModeKey, val);
  }

  // --- BUBBLE COLOR SCHEME
  String? getBubbleSchemeId() => _prefs.getString(_bubbleSchemeKey);

  Future<void> setBubbleSchemeId(String? id) async {
    if (id != null) {
      await _prefs.setString(_bubbleSchemeKey, id);
    } else {
      await _prefs.remove(_bubbleSchemeKey);
    }
  }

  // --- CHAT WALLPAPER
  // Stored value uses a prefix scheme so PrefsService stays format-agnostic:
  //   `null`         → no wallpaper / removed
  //   `'asset:path'` → bundled asset (e.g. default wallpaper)
  //   `'file:path'`  → user-picked file in app documents directory
  // Decoding lives in `wallpaper_provider.dart` (`_decode`).
  String? getWallpaperPath() => _prefs.getString(_wallpaperPathKey);

  Future<void> setWallpaperPath(String? path) async {
    if (path != null) {
      await _prefs.setString(_wallpaperPathKey, path);
    } else {
      await _prefs.remove(_wallpaperPathKey);
    }
  }

  /// Per-chat wallpaper overrides, keyed by chatId.
  /// Value follows the same prefix scheme as [getWallpaperPath].
  String? getChatWallpaperPath(String chatId) =>
      _prefs.getString('$_wallpaperPathKey:$chatId');

  Future<void> setChatWallpaperPath(String chatId, String? path) async {
    final key = '$_wallpaperPathKey:$chatId';
    if (path != null) {
      await _prefs.setString(key, path);
    } else {
      await _prefs.remove(key);
    }
  }

  /// All chatIds that have a per-chat wallpaper override stored.
  Set<String> getChatWallpaperKeys() {
    final prefix = '$_wallpaperPathKey:';
    return _prefs
        .getKeys()
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toSet();
  }
}
