import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Listen to token (device)every time notification came
  StreamSubscription<String>? _tokenRefreshSub;

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
    await _firestore.doc('users/$uid').set({
      'fcmTokens': {
        'token': {
          'device': _getDevicePlatform(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
    }, SetOptions(merge: true)); // => Create if doc is missing, replace if exist
  }

  String _getDevicePlatform() =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}
