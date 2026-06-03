import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum NotificationChannelType {
  chatMessages,
  incomingCall,
  appUpdate,
}

class NotificationChannelConfig {
  final String id;
  final String name;
  final String description;
  final Importance importance;
  final Priority priority;
  final String? soundFilename;
  final String? iconDrawable;

  const NotificationChannelConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
    required this.priority,
    this.soundFilename,
    this.iconDrawable,
  });

  AndroidNotificationChannel toAndroidChannel() {
    return AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: importance,
      sound: soundFilename != null
          ? RawResourceAndroidNotificationSound(soundFilename!)
          : null,
    );
  }
}

class NotificationConfig {
  NotificationConfig._();

  static const chatMessages = NotificationChannelConfig(
    id: 'chat_messages_v2',
    name: 'Chat Messages',
    description: 'New message notifications',
    importance: Importance.high,
    priority: Priority.high,
    iconDrawable: 'ic_chat_message',
  );

  static const incomingCall = NotificationChannelConfig(
    id: 'incoming_call',
    name: 'Incoming Calls',
    description: 'Incoming call notifications',
    importance: Importance.max,
    priority: Priority.max,
    soundFilename: 'call_ringtone',
    iconDrawable: 'ic_call',
  );

  static const appUpdate = NotificationChannelConfig(
    id: 'app_updates',
    name: 'App Updates',
    description: 'Important app updates',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    iconDrawable: 'ic_notification',
  );

  static NotificationChannelConfig fromType(NotificationChannelType type) {
    switch (type) {
      case NotificationChannelType.chatMessages:
        return chatMessages;
      case NotificationChannelType.incomingCall:
        return incomingCall;
      case NotificationChannelType.appUpdate:
        return appUpdate;
    }
  }

  static List<NotificationChannelConfig> get all => [
    chatMessages,
    incomingCall,
    appUpdate,
  ];
}
