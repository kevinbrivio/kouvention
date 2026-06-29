import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:kouvention/cores/utils/log.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

enum FCMResult { success, unregistered, failed }

class NotificationService {
  static const _projectId = 'kouvention';

  http.Client? _authenticationClient;

  Future<http.Client> _getClient() async {
    if (_authenticationClient != null) return _authenticationClient!;

    iLog('[NotificationService] Authenticating with Firebase Admin SDK...');
    final jsonString = await rootBundle.loadString('service-account.json');
    final accountCredentials = ServiceAccountCredentials.fromJson(
      jsonDecode(jsonString),
    );

    _authenticationClient = await clientViaServiceAccount(accountCredentials, [
      'https://www.googleapis.com/auth/firebase.messaging',
    ]);
    iLog('[NotificationService] Admin SDK authenticated successfully');

    return _authenticationClient!;
  }

  Future<FCMResult> sendNotification({
    required String targetToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    dLog('[NotificationService] Sending FCM to ${targetToken.substring(0, 20)}...');
    try {
      final response = await _trySend(targetToken, title, body, data);

      if (response.statusCode == 200) {
        iLog('[NotificationService] FCM sent successfully');
        return FCMResult.success;
      } 
      if (response.statusCode == 404) {
          final json = jsonDecode(response.body);
          final errorCode = json['error']?['details']?[0]?['errorCode'];
          if (errorCode == 'UNREGISTERED') {
            wLog('[NotificationService] Token is dead: $targetToken');
            return FCMResult.unregistered;
          }
      }
      
      eLog('[NotificationService] FCM send failed: ${response.statusCode} ${response.body}');
      return FCMResult.failed;
    } on http.ClientException {
      // Stale connection — reset client and retry once
      wLog('[NotificationService] Connection reset, retrying in 3s...');
      _authenticationClient = null;

      await Future.delayed(const Duration(seconds: 3));

      final response = await _trySend(targetToken, title, body, data);
      dLog('[NotificationService] Retry response: ${response.statusCode}');
      return response.statusCode == 200 
            ? FCMResult.success 
            : FCMResult.failed;
    }
  }

  Future<http.Response> _trySend(
    String targetToken,
    String title,
    String body,
    Map<String, String>? data,
  ) async {
    final client = await _getClient();
    final url = Uri.parse(
      'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
    );

    final message = {
      'message': {
        'token': targetToken,
        'android': {
          'priority': 'high',
        },
        'apns': {
          'headers': {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          'payload': {
            'aps': {
              'content-available': 1,
            },
          },
        },
        'data': {
          'title': title,
          'body': body,
          if (data != null) ...data,
        },
      },
    };

    return client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(message),
    );
  }

  Future<void> sendChatNotification({
    required String targetToken,
    required String messageText,
    required String chatId,
    required String senderId,
    required String senderName,
    required String? senderImageUrl,
    bool isGroup = false,
  }) async {
    await sendNotification(
      targetToken: targetToken,
      title: senderName,
      body: messageText,
      data: {
        'type': 'chat_message',
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'senderImageUrl': senderImageUrl ?? '',
        'title': senderName,
        'body': messageText,
        'sentBy': 'client',
        'chatType': isGroup ? 'group' : 'direct',
      },
    );
  }
}
