import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:kouvention/features/shared/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kouvention/cores/router/router.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/sync/chat_sync_coordinator.dart';
import 'package:kouvention/features/notification/services/notification_config.dart';
import 'package:kouvention/features/notification/services/notification_sound.dart';
import 'package:kouvention/features/notification/viewmodel/active_chat_id_provider.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';
import 'package:kouvention/firebase_options.dart';

@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) async {
  debugPrint(
    '[BackgroundReply] Notification response: action=${response.actionId}, payload=${response.payload}',
  );

  final String? replyText = response.input;
  final String? chatId = response.payload;
  final senderName = response.data['senderName'];

  if (replyText == null || chatId == null) {
    debugPrint('[BackgroundReply] Missing replyText or chatId');
    return;
  }
  debugPrint(
    '[BackgroundReply] Direct reply text: "$replyText" for chat: $chatId',
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    debugPrint('[BackgroundReply] No user signed in');
    return;
  }

  await currentUser.getIdToken(true);

  final chatService = ChatService();
  final chat = await chatService.getChat(chatId);
  if (chat == null) {
    debugPrint('[BackgroundReply] Chat not found: $chatId');
    return;
  }

  final docId = FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .doc()
      .id;

  await chatService.sendMessage(
    chatId: chatId,
    messageId: docId,
    senderId: currentUser.uid,
    senderName: senderName ?? '',
    text: replyText,
    sentAt: DateTime.now(),
    memberUids: chat.members,
  );
  debugPrint('[BackgroundReply] Reply sent successfully, messageId=$docId');
}

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '[BackgroundHandler] ENTERED — Received FCM data: ${message.data}',
  );
  try {
    await Firebase.initializeApp();
    debugPrint('[BackgroundHandler] Firebase.initializeApp() OK');
  } catch (e, s) {
    debugPrint('[BackgroundHandler] Firebase.initializeApp() FAILED: $e\n$s');
    return;
  }

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final enabled = doc.data()?['notificationsEnabled'] as bool? ?? true;
      if (!enabled) {
        debugPrint('[BackgroundHandler] Notifications disabled for user');
        return;
      }
    } catch (e) {
      debugPrint('[BackgroundHandler] Firestore check failed: $e');
    }
  } else {
    debugPrint('[BackgroundHandler] No user signed in — skipping notification');
    return;
  }

  final plugin = FlutterLocalNotificationsPlugin();

  // Create all notification channels
  final androidImpl = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (androidImpl != null) {
    for (final channel in NotificationConfig.all) {
      await androidImpl.createNotificationChannel(channel.toAndroidChannel());
    }
    debugPrint('[BackgroundHandler] All notification channels created');
  }

  await plugin.initialize(
    settings: InitializationSettings(
      android: AndroidInitializationSettings('ic_chat_message'),
    ),
  );

  final data = message.data;
  final sentBy = data['sentBy'] ?? 'unknown';
  final isGroup = data['chatType'] == 'group';
  debugPrint(
    '[BackgroundHandler] Notification sent by: $sentBy, isGroup=$isGroup',
  );

  String channelId;
  try {
    final prefs = await SharedPreferences.getInstance();
    String? groupChannel;
    if (isGroup) {
      groupChannel = prefs.getString('pref_group_channel');
    }
    if (groupChannel != null) {
      channelId = groupChannel;
    } else {
      channelId = prefs.getString('pref_dm_channel') ?? 'dm_default';
    }
  } catch (e) {
    debugPrint('[BackgroundHandler] SharedPreferences error: $e');
    channelId = isGroup ? 'group_default' : 'dm_default';
  }

  final iosSoundFilename = NotificationSound.iosSoundForChannel(channelId);
  bool backgroundVibration = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    backgroundVibration =
        prefs.getBool('notification_vibration_enabled') ?? true;
  } catch (_) {}

  await _showChatNotification(
    plugin: plugin,
    chatId: data['chatId'] ?? '',
    senderId: data['senderId'] ?? '',
    senderName: data['senderName'] ?? 'Someone',
    senderImageUrl: data['senderImageUrl'] ?? '',
    title: data['title'] ?? '',
    body: data['body'] ?? '',
    channelId: channelId,
    isGroup: isGroup,
    iosSoundFilename: iosSoundFilename,
    enableVibration: backgroundVibration,
  );
  debugPrint('[BackgroundHandler] Local notification shown successfully');
}

Future<void> _showChatNotification({
  required FlutterLocalNotificationsPlugin plugin,
  required String chatId,
  required String senderId,
  required String senderName,
  required String title,
  required String body,
  required String channelId,
  required bool isGroup,
  String? senderImageUrl,
  String? iosSoundFilename,
  bool enableVibration = true,
}) async {
  final channelName = isGroup ? 'Group Messages' : 'Direct Messages';
  final channelDescription = isGroup
      ? 'New group message notifications'
      : 'New direct message notifications';

  final currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? 'Unknown_id';

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
    body: '',
    payload: chatId,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        icon: 'ic_chat_message',
        importance: Importance.high,
        priority: Priority.high,
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
    debugPrint('[NotificationHandler] Initializing...');

    // 1. Create all notification channels
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      for (final channel in NotificationConfig.all) {
        await androidImpl.createNotificationChannel(channel.toAndroidChannel());
      }
      debugPrint('[NotificationHandler] All notification channels created');
    }

    // 2. setup the local notification plugin
    await _localNotifications.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings('ic_chat_message'),
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
    debugPrint('[NotificationHandler] Local notifications plugin initialized');

    // 3. Listen for foreground message
    _onMessageSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    debugPrint('[NotificationHandler] Foreground message listener registered');

    // 4. Listen for background tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTapped);
    debugPrint('[NotificationHandler] Background tap listener registered');

    // 5. Check if the app is opened via notification (from killed state)
    final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMsg != null) {
      debugPrint(
        '[NotificationHandler] App opened from killed state via notification',
      );
      _handleNotificationTapped(initialMsg);
    } else {
      debugPrint('[NotificationHandler] No initial notification message');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[ForegroundHandler] Received FCM data: ${message.data}');
    final sentBy = message.data['sentBy'] ?? 'unknown';
    debugPrint('[ForegroundHandler] Notification sent by: $sentBy');

    final incomingChatId = message.data['chatId'];
    final activeChatId = _ref.read(activeChatIdProvider);

    if (incomingChatId != null && incomingChatId == activeChatId) {
      debugPrint('[ForegroundHandler] Suppressed — chat is currently active');
      return;
    }

    final enabled = await _areNotificationsEnabled();
    if (!enabled) {
      debugPrint('[ForegroundHandler] Notifications disabled');
      return;
    }

    try {
      await _showLocalNotification(message);
      debugPrint('[ForegroundHandler] Local notification displayed');
    } catch (e) {
      debugPrint('[ForegroundHandler] Failed to show notification: $e');
    }

    if (incomingChatId != null && incomingChatId.isNotEmpty) {
      try {
        // Route through the coordinator so the lightweight sync goes
        // through the bounded queue. The coordinator decides whether
        // to enqueue an immediate `fetchMissedMessages` job.
        _ref
            .read(chatSyncCoordinatorProvider)
            .onNotificationReceived(incomingChatId);
        debugPrint('[ForegroundHandler] Synced messages for $incomingChatId');
      } catch (e) {
        debugPrint('[ForegroundHandler] Sync failed for $incomingChatId: $e');
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

  String _resolveChannel({bool isGroup = false}) {
    final prefs = _ref.read(prefsServiceProvider);
    if (isGroup) {
      final groupId = prefs.groupChannelId;
      if (groupId != null) return groupId;
    }
    return prefs.dmChannelId;
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final data = message.data;
    final chatId = data['chatId'] ?? '';
    final senderName = data['senderName'] ?? 'Someone';
    final senderId = data['senderId'] ?? '';
    final body = data['body'] ?? '';
    final title = data['title'] ?? 'New message';
    final senderImageUrl = data['senderImageUrl'];
    final isGroup = data['chatType'] == 'group';

    String channelId;
    try {
      channelId = _resolveChannel(isGroup: isGroup);
    } catch (_) {
      channelId = isGroup ? 'group_default' : 'dm_default';
    }

    final iosSoundFilename = NotificationSound.iosSoundForChannel(channelId);
    final vibration = _ref
        .read(prefsServiceProvider)
        .notificationVibrationEnabled;

    await _showChatNotification(
      plugin: _localNotifications,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderImageUrl: senderImageUrl,
      title: title,
      body: body,
      channelId: channelId,
      isGroup: isGroup,
      iosSoundFilename: iosSoundFilename,
      enableVibration: vibration,
    );
  }

  // Tap in a local notification (foreground)
  void _onNotificationTapped(NotificationResponse response) {
    final chatId = response.payload;
    debugPrint(
      '[NotificationHandler] Foreground notification tapped, chatId=$chatId',
    );
    if (chatId == null || chatId.isEmpty) return;
    _navigateToChat(chatId);
  }

  // Tap a system notification (background/terminated)
  void _handleNotificationTapped(RemoteMessage message) {
    final chatId = message.data['chatId'];
    final sentBy = message.data['sentBy'] ?? 'unknown';
    debugPrint(
      '[NotificationHandler] Background notification tapped, chatId=$chatId, sentBy=$sentBy',
    );
    if (chatId != null) {
      _navigateToChat(chatId);
    }
  }

  void _navigateToChat(String chatId) {
    router.push('/chats/$chatId');
  }
}

final notificationHandlerProvider = Provider<NotificationHandler>((ref) {
  debugPrint('[Provider] notificationHandlerProvider creating...');
  try {
    final fcmService = ref.read(fcmServiceProvider);
    fcmService.initialize();
    debugPrint('[Provider] fcmService.initialize() called');
  } catch (e, s) {
    debugPrint('[Provider] fcmService.initialize() FAILED: $e\n$s');
  }
  try {
    final handler = NotificationHandler(ref);
    handler.initialize();
    debugPrint('[Provider] NotificationHandler.initialize() called');
    ref.onDispose(handler.dispose);
    return handler;
  } catch (e, s) {
    debugPrint('[Provider] NotificationHandler creation FAILED: $e\n$s');
    rethrow;
  }
});
