import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

class NotificationService {
  static const _projectId = 'kouvention';

  http.Client? _authenticationClient;

  Future<http.Client> _getClient() async {
    if (_authenticationClient != null) return _authenticationClient!;

    final jsonString = await rootBundle.loadString('service-account.json');
    final accountCredentials = ServiceAccountCredentials.fromJson(
      jsonDecode(jsonString),
    );

    _authenticationClient = await clientViaServiceAccount(accountCredentials, [
      'https://www.googleapis.com/auth/firebase.messaging',
    ]);

    return _authenticationClient!;
  }

  Future<void> sendNotification({
    required String targetToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final response = await _trySend(targetToken, title, body, data);

      if (response.statusCode != 200) {
        debugPrint('FCM send failed: ${response.statusCode} ${response.body}');
      }
    } on http.ClientException {
      // Stale connection — reset client and retry once
      debugPrint('FCM connection reset, retrying 3s...');
      _authenticationClient = null;

      await Future.delayed(const Duration(seconds: 3));

      try {
        final response = await _trySend(targetToken, title, body, data);
        debugPrint('FCM retry response: ${response.statusCode}');
      } catch (e) {
        debugPrint('FCM retry also failed: $e');
      }
    } catch (e) {
      debugPrint('FCM send error: $e');
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
            'apns-priority': '5',
          },
          'payload': {
            'aps': {
              'content-available': 1,
            },
          },
        },
        if (data != null) 'data': data,
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
      },
    );
  }
}
