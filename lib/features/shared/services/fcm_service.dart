import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
  
  
}
