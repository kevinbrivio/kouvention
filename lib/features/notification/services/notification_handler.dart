import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kouvention/cores/router/router.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/notification/viewmodel/active_chat_id_provider.dart';
import 'package:kouvention/firebase_options.dart';

@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) async {
  // User typed reply
  final String? replyText = response.input;
  final String? chatId = response.payload;
  final senderName = response.data['senderName'];

  if (replyText == null || chatId == null) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Refresh the firebase
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  await currentUser.getIdToken(true);

  // Inject Chat Service
  final chatService = ChatService();
  final chat = await chatService.getChat(chatId);
  if (chat == null) return;

  // Write to firestore
  await chatService.sendMessage(
    chatId: chatId,
    senderId: currentUser.uid,
    senderName: senderName ?? '',
    text: replyText,
    memberUids: chat.members,
  );
}

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final plugin = FlutterLocalNotificationsPlugin();

  await plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        AndroidNotificationChannel(
          'chat_messages',
          'Chat Messages',
          description: 'Notifications for new message',
          importance: Importance.high,
        ),
      );

  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    ),
  );

  final data = message.data;
  await _showChatNotification(
    plugin: plugin,
    chatId: data['chatId'] ?? '',
    senderId: data['senderId'] ?? '',
    senderName: data['senderName'] ?? 'Someone',
    senderImageUrl: data['senderImageUrl'] ?? '',
    title: data['title'] ?? '',
    body: data['body'] ?? '',
  );
}

Future<void> _showChatNotification({
  required FlutterLocalNotificationsPlugin plugin,
  required String chatId,
  required String senderId,
  required String senderName,
  required String title,
  required String body,
  String? senderImageUrl,
}) async {
  // Get the user creds
  final currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? 'Unknown_id';

  // Download sender's profile image
  final senderIcon = await _downloadIcon(senderImageUrl);

  final MessagingStyleInformation messageStyle = MessagingStyleInformation(
    Person(key: currentUserUid, name: 'You'),
    messages: [
      Message(
        body,
        DateTime.now(),
        Person(key: senderId, name: senderName, icon: senderIcon),
      ),
    ],
  );

  const replyAction = AndroidNotificationAction(
    'reply_action',
    'Reply',
    inputs: [AndroidNotificationActionInput(label: 'Type a message...')],
    showsUserInterface: false,
  );

  await plugin.show(
    id: chatId.hashCode,
    title: title,
    body: body,
    payload: chatId,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_messages',
        'Chat messages',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: messageStyle,
        actions: [replyAction],
      ),
    ),
  );
}

// ----- HELPER ---------------------
Future<ByteArrayAndroidIcon?> _downloadIcon(String? imageUrl) async {
  if (imageUrl == null || imageUrl.isEmpty) return null;

  try {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      return ByteArrayAndroidIcon(response.bodyBytes);
    }
  } catch (e) {
    debugPrint('Failed to download icon: $e');
  }
  return null;
}

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
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
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
    final data = message.data;
    final chatId = data['chatId'] ?? '';
    final senderName = data['senderName'] ?? 'Someone';
    final senderId = data['senderId'] ?? '';
    final body = data['body'] ?? '';
    final title = data['title'] ?? 'New message';
    final senderImageUrl = data['senderImageUrl'];

    _showChatNotification(
      plugin: _localNotifications,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderImageUrl: senderImageUrl,
      title: title,
      body: body,
    );
  }

  // Tap in a local notification (foreground)
  void _onNotificationTapped(NotificationResponse response) {
    final chatId = response.payload;
    if (chatId == null || chatId.isEmpty) return;
    _navigateToChat(chatId);
  }

  // Tap a system notification (background/terminated)
  void _handleNotificationTapped(RemoteMessage message) {
    final chatId = message.data['chatId'];
    if (chatId != null) {
      _navigateToChat(chatId);
    }
  }

  void _navigateToChat(String chatId) {
    router.push('/chats/$chatId');
  }
}
