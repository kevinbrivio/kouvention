import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService();
  ref.onDispose(service.dispose);
  return service;
});

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Listen to token (device)every time notification came
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> initialize() async {
    final granted = await requestPermission();
    if (!granted) return;

    await saveToken();
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

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<void> saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    return _saveTokenToFirestore(uid, token);
  }

  Future<void> _saveTokenToFirestore(String uid, token) async {
    await _firestore.doc('users/$uid').set(
      {
        'fcmTokens': {
          'token': {
            'device': _getDevicePlatform(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
      },
      SetOptions(merge: true),
    ); // => Create if doc is missing, replace if exist
  }

  String _getDevicePlatform() =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  void listenToTokenRefresh() {
    // FCM aren't permanent, user could clear app data or reinstall app.
    // Hence we listen to new token from Firebase instead of using stale token.
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      return _saveTokenToFirestore(uid, newToken);
    });
  }

  Future<void> removeToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await _firestore.doc('users/$uid').update({
      'fcmTokens.$token': FieldValue.delete(), // Remove device-uid only token.
      // Since fcmTokens are map, we delete specific token.
    });

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }
}
