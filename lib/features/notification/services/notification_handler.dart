import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kouvention/cores/router/router.dart';
import 'package:kouvention/features/notification/viewmodel/active_chat_id_provider.dart';

class NotificationHandler {
  final Ref _ref;

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Notifications for new message',
    importance: Importance.high,
  );

  StreamSubscription? _onMessageSub;

  NotificationHandler(this._ref);

  void dispose() {
    _onMessageSub?.cancel();
    _onMessageSub = null;
  }

  Future<void> initialize() async {
    // 1. Create the local notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    // 2. setup the local notification plugin
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 3. Listen for foreground message
    _onMessageSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // 4. Listen for background tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTapped);

    // 5. Check if the app is opened via notification (from killed state)
    final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMsg != null) {
      _handleNotificationTapped(initialMsg);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final incomingChatId = message.data['chatId'];
    final activeChatId = _ref.read(activeChatIdProvider);

    // User already read the chat -> No need to ring notifiation
    if (incomingChatId != null && incomingChatId == activeChatId) return;

    _showLocalNotification(message);
  }

  void _showLocalNotification(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    final chatId = message.data['chatId'] ?? '';

    _localNotifications.show(
      id: chatId.hashCode,
      title: notif.title ?? 'New message',
      body: notif.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: chatId,
    );
  }

  // Tap in a local notification (foreground)
  void _onNotificationTapped(NotificationResponse response) {
    final chatId = response.payload;
    if (chatId != null && chatId.isNotEmpty) {
      _navigateToChat(chatId);
    }
  }

  // Tap a system notification (background/terminated)
  void _handleNotificationTapped(RemoteMessage message) {
    final chatId = message.data['chatId'];
    if (chatId != null) {
      _navigateToChat(chatId);
    }
  }

  void _navigateToChat(String chatId) {
    router.push('chat/$chatId');
  }
}
