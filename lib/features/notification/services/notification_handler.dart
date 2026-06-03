import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kouvention/cores/router/router.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/notification/services/notification_config.dart';
import 'package:kouvention/features/notification/services/notification_sound.dart';
import 'package:kouvention/features/notification/viewmodel/active_chat_id_provider.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';
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

  final docId = FirebaseFirestore.instance
    .collection('chats')
    .doc(chatId)
    .collection('messages')
    .doc()
    .id;

  // Write to firestore
  await chatService.sendMessage(
    chatId: chatId,
    messageId: docId,
    senderId: currentUser.uid,
    senderName: senderName ?? '',
    text: replyText,
    memberUids: chat.members,
  );
}

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final enabled = doc.data()?['notificationsEnabled'] as bool? ?? true;
      if (!enabled) return;
    } catch (_) {}
  }

  final plugin = FlutterLocalNotificationsPlugin();
  final chatConfig = NotificationConfig.chatMessages;

  await plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(chatConfig.toAndroidChannel());

  await plugin.initialize(
    settings: InitializationSettings(
      android: AndroidInitializationSettings(
        chatConfig.iconDrawable ?? 'ic_notification',
      ),
    ),
  );

  // Resolve sound from SharedPreferences (background isolate — no Riverpod)
  AndroidNotificationSound? backgroundSound;
  String? backgroundIosSound;
  bool backgroundVibration = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    final soundId = prefs.getString('notification_sound_chat');
    final soundUri = prefs.getString('notification_sound_uri');
    if (soundId == 'system' && soundUri != null) {
      backgroundSound = UriAndroidNotificationSound(soundUri);
    } else {
      final sound = NotificationSound.fromId(soundId ?? 'default');
      backgroundSound = sound?.toAndroidNotificationSound();
      backgroundIosSound = sound?.iosFilename;
    }
    backgroundVibration =
        prefs.getBool('notification_vibration_enabled') ?? true;
  } catch (_) {}

  final data = message.data;
  await _showChatNotification(
    plugin: plugin,
    chatId: data['chatId'] ?? '',
    senderId: data['senderId'] ?? '',
    senderName: data['senderName'] ?? 'Someone',
    senderImageUrl: data['senderImageUrl'] ?? '',
    title: data['title'] ?? '',
    body: data['body'] ?? '',
    sound: backgroundSound,
    iosSoundFilename: backgroundIosSound,
    enableVibration: backgroundVibration,
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
  AndroidNotificationSound? sound,
  String? iosSoundFilename,
  bool enableVibration = true,
}) async {
  final config = NotificationConfig.chatMessages;

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
        config.id,
        config.name,
        channelDescription: config.description,
        icon: config.iconDrawable,
        sound: sound,
        importance: config.importance,
        priority: config.priority,
        styleInformation: messageStyle,
        actions: [replyAction],
        enableVibration: enableVibration,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: iosSoundFilename,
      ),
    ),
  );
}

// ----- HELPERS ---------------------
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

  StreamSubscription? _onMessageSub;

  NotificationHandler(this._ref);

  void dispose() {
    _onMessageSub?.cancel();
    _onMessageSub = null;
  }

  Future<void> initialize() async {
    // 1. Create all notification channels
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      for (final channel in NotificationConfig.all) {
        await androidImpl.createNotificationChannel(channel.toAndroidChannel());
      }
    }

    // 2. setup the local notification plugin
    await _localNotifications.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings(
          NotificationConfig.chatMessages.iconDrawable ?? 'ic_notification',
        ),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
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

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final incomingChatId = message.data['chatId'];
    final activeChatId = _ref.read(activeChatIdProvider);

    if (incomingChatId != null && incomingChatId == activeChatId) return;

    final enabled = await _areNotificationsEnabled();
    if (!enabled) return;

    _showLocalNotification(message);

    // Sync missed messages into the local DB so they appear in the chat list
    if (incomingChatId != null && incomingChatId.isNotEmpty) {
      try {
        await _ref.read(syncServiceProvider).fetchMessages(incomingChatId);
        debugPrint('Foreground FCM: synced messages for $incomingChatId');
      } catch (e) {
        debugPrint('Foreground FCM sync failed for $incomingChatId: $e');
      }
    }
  }

  Future<bool> _areNotificationsEnabled() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      return doc.data()?['notificationsEnabled'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  ({AndroidNotificationSound? sound, String? iosFilename}) _resolveSound() {
    final prefs = _ref.read(prefsServiceProvider);
    final soundId = prefs.notificationSoundId;
    final soundUri = prefs.notificationSoundUri;
    if (soundId == NotificationSound.systemId && soundUri != null) {
      return (sound: UriAndroidNotificationSound(soundUri), iosFilename: null);
    }
    final sound = NotificationSound.fromId(soundId ?? NotificationSound.defaultId);
    return (sound: sound?.toAndroidNotificationSound(), iosFilename: sound?.iosFilename);
  }

  void _showLocalNotification(RemoteMessage message) {
    final data = message.data;
    final chatId = data['chatId'] ?? '';
    final senderName = data['senderName'] ?? 'Someone';
    final senderId = data['senderId'] ?? '';
    final body = data['body'] ?? '';
    final title = data['title'] ?? 'New message';
    final senderImageUrl = data['senderImageUrl'];

    ({AndroidNotificationSound? sound, String? iosFilename}) resolved;
    try {
      resolved = _resolveSound();
    } catch (_) {
      resolved = (sound: null, iosFilename: null);
    }

    final vibration = _ref.read(prefsServiceProvider).notificationVibrationEnabled;

    _showChatNotification(
      plugin: _localNotifications,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderImageUrl: senderImageUrl,
      title: title,
      body: body,
      sound: resolved.sound,
      iosSoundFilename: resolved.iosFilename,
      enableVibration: vibration,
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
