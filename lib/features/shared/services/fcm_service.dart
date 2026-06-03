import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  final prefsService = ref.read(prefsServiceProvider);
  final service = FcmService(prefsService);
  ref.onDispose(service.dispose);
  return service;
});

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PrefsService _prefs;

  late String _deviceId;

  // Listen to token (device)every time notification came
  StreamSubscription<String>? _tokenRefreshSub;

  static const int _maxTokensPerUser = 5;
  static const Duration _tokenMaxAge = Duration(days: 30);

  FcmService(this._prefs);
  Future<void> initialize() async {
    String? deviceId = _prefs.deviceId();
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _prefs.setDeviceId(deviceId);
    }
    _deviceId = deviceId;
    debugPrint('[FcmService] initialize() called, deviceId=$deviceId');

    // Android 13+ requires explicit POST_NOTIFICATIONS runtime permission.
    // FirebaseMessaging.requestPermission() should handle this internally,
    // but we explicitly check + request as a fallback.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final osNotification = await Permission.notification.status;
      debugPrint('[FcmService] Android POST_NOTIFICATIONS status: $osNotification');
      if (osNotification.isDenied) {
        final result = await Permission.notification.request();
        debugPrint('[FcmService] POST_NOTIFICATIONS request result: $result');
      }
    }

    final granted = await requestPermission();
    debugPrint('[FcmService] requestPermission() returned granted=$granted');
    if (!granted) {
      debugPrint('[FcmService] Permission denied — skipping token registration');
      return;
    }

    await saveToken();
    await _cleanupStaleTokens();
    listenToTokenRefresh();
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: false,
      sound: true,
      provisional: false, // Show the original dialog
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized;
    await _prefs.setNotificationPermissionDenied(!granted);
    return granted;
  }

  Future<void> saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[FcmService] saveToken() skipped — no user signed in');
      return;
    }

    try {
      final newToken = await _messaging.getToken();
      if (newToken == null) {
        debugPrint('[FcmService] getToken() returned null');
        return;
      }
      debugPrint('[FcmService] FCM token obtained: ${newToken.substring(0, 20)}...');

      final oldToken = _prefs.getFcmToken();
      if (oldToken != null && oldToken != newToken) {
        debugPrint('[FcmService] Token changed — removing old token from Firestore');
        await _firestore.doc('users/$uid').update({
          'fcmTokens.$oldToken': FieldValue.delete(),
        });
      }

      await _saveTokenToFirestore(uid, newToken);
      await _prefs.setFcmToken(newToken);
      debugPrint('[FcmService] Token saved to Firestore and SharedPreferences');

      await _cleanupOldTokensForDevice(uid, newToken);
    } catch (e) {
      debugPrint('[FcmService] saveToken() failed: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String uid, String token) async {
    await _firestore.doc('users/$uid').set(
      {
        'fcmTokens': {
          token: {
            'device': _getDevicePlatform(),
            'deviceId': _deviceId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
      },
      SetOptions(merge: true),
    ); // => Create if doc is missing, replace if exist
  }

  Future<void> _cleanupOldTokensForDevice(
    String uid,
    String currentToken,
  ) async {
    try {
      final doc = await _firestore.doc('users/$uid').get();
      final tokens = doc.data()?['fcmTokens'] as Map<String, dynamic>? ?? {};

      final tokensToDelete = <String>[];

      for (final entry in tokens.entries) {
        final tokenKey = entry.key;
        final tokenData = entry.value as Map<String, dynamic>? ?? {};

        // Same device but different token, so replace
        if (tokenData['deviceId'] == _deviceId && tokenKey != currentToken) {
          tokensToDelete.add(tokenKey);
        }
      }

      if (tokensToDelete.isEmpty) return;

      final updates = <String, dynamic>{};
      for (final oldToken in tokensToDelete) {
        updates['fcmTokens.$oldToken'] = FieldValue.delete();
      }

      await _firestore.doc('users/$uid').update(updates);
      debugPrint('Cleaned up ${tokensToDelete.length} stale token(s)');
    } catch (e) {
      debugPrint('Token cleanup failed: $e');
    }
  }

  Future<void> _cleanupStaleTokens() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _firestore.doc('users/$uid').get();
      final tokens = doc.data()?['fcmTokens'] as Map<String, dynamic>? ?? {};
      if (tokens.isEmpty) return;

      final now = DateTime.now();
      final tokensToDelete = <String>{};
      // Track the latest token per deviceId
      final Map<String, _TokenEntry> latestPerDevice = {};
      // Track all entries sorted by updatedAt for overall cap
      final allEntries = <_TokenEntry>[];

      for (final entry in tokens.entries) {
        final tokenKey = entry.key;
        final tokenData = entry.value as Map<String, dynamic>? ?? {};

        final deviceId = tokenData['deviceId'] as String? ?? '_unknown_device_id_';
        final updatedAt = (tokenData['updatedAt'] as Timestamp?)?.toDate();
        final isCurrent = tokenKey == _prefs.getFcmToken();

        final tokenEntry = _TokenEntry(
          token: tokenKey,
          deviceId: deviceId,
          updatedAt: updatedAt ?? now,
          isCurrent: isCurrent,
        );
        allEntries.add(tokenEntry);

        // 1. Remove tokens > 60 days old
        if (updatedAt != null && now.difference(updatedAt) > _tokenMaxAge) {
          tokensToDelete.add(tokenKey);
          continue;
        }

        // 2. Remove orphaned _unknown_device_id_ tokens
        if (deviceId == '_unknown_device_id_' && !isCurrent) {
          tokensToDelete.add(tokenKey);
          continue;
        }

        // 3. Track latest token per deviceId for dedup
        final existing = latestPerDevice[deviceId];
        if (existing == null || (updatedAt != null && existing.updatedAt.isBefore(updatedAt))) {
          latestPerDevice[deviceId] = tokenEntry;
        }
      }

      // 4. Deduplicate by deviceId — keep only newest token per device
      for (final entry in allEntries) {
        if (tokensToDelete.contains(entry.token)) continue;
        final best = latestPerDevice[entry.deviceId];
        if (best != null && entry.token != best.token) {
          tokensToDelete.add(entry.token);
        }
      }

      // 5. Cap total tokens to _maxTokensPerUser (keep most recent)
      final remaining = allEntries
          .where((e) => !tokensToDelete.contains(e.token))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (remaining.length > _maxTokensPerUser) {
        for (var i = _maxTokensPerUser; i < remaining.length; i++) {
          tokensToDelete.add(remaining[i].token);
        }
      }

      if (tokensToDelete.isEmpty) {
        debugPrint('[FcmService] Stale cleanup: no tokens to remove');
        return;
      }

      final updates = <String, dynamic>{};
      for (final token in tokensToDelete) {
        updates['fcmTokens.$token'] = FieldValue.delete();
      }

      await _firestore.doc('users/$uid').update(updates);
      debugPrint('[FcmService] Stale cleanup: removed ${tokensToDelete.length} token(s)');
    } catch (e) {
      debugPrint('[FcmService] Stale cleanup failed: $e');
    }
  }

  String _getDevicePlatform() =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  void listenToTokenRefresh() {
    // FCM aren't permanent, user could clear app data or reinstall app.
    // Hence we listen to new token from Firebase instead of using stale token.
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FcmService] Token refresh event: ${newToken.substring(0, 20)}...');
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('[FcmService] Token refresh skipped — no user');
        return;
      }

      final oldToken = _prefs.getFcmToken();
      if (oldToken != null && oldToken != newToken) {
        debugPrint('[FcmService] Refresh: removing old token from Firestore');
        await _firestore.doc('users/$uid').update({
          'fcmTokens.$oldToken': FieldValue.delete(),
        });
      }

      await _saveTokenToFirestore(uid, newToken);
      await _prefs.setFcmToken(newToken);
      debugPrint('[FcmService] Refresh: new token saved');
    });
  }

  Future<void> removeToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[FcmService] removeToken() skipped — no user');
      return;
    }

    final token = await _messaging.getToken();
    if (token == null) {
      debugPrint('[FcmService] removeToken() skipped — no token');
      return;
    }

    debugPrint('[FcmService] Removing token for uid=$uid');

    // Invalidate SDK-level token so a new user on this device
    // doesn't inherit the previous user's notification stream.
    try {
      await _messaging.deleteToken();
      debugPrint('[FcmService] SDK token deleted');
    } catch (e) {
      debugPrint('[FcmService] deleteToken() failed: $e');
    }

    await _firestore.doc('users/$uid').update({
      'fcmTokens.$token': FieldValue.delete(), // Remove device-uid only token.
      // Since fcmTokens are map, we delete specific token.
    });
    debugPrint('[FcmService] Token removed from Firestore');

    await _prefs.removeFcmToken();
    debugPrint('[FcmService] Token removed from SharedPreferences');

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }
}

class _TokenEntry {
  final String token;
  final String deviceId;
  final DateTime updatedAt;
  final bool isCurrent;

  const _TokenEntry({
    required this.token,
    required this.deviceId,
    required this.updatedAt,
    this.isCurrent = false,
  });
}
