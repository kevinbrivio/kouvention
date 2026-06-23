import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  static NotificationChannelConfig _dmChannel(
    String id, {
    String? soundFilename,
  }) =>
      NotificationChannelConfig(
        id: id,
        name: 'Direct Messages',
        description: 'New direct message notifications',
        importance: Importance.high,
        priority: Priority.high,
        soundFilename: soundFilename,
        iconDrawable: 'ic_chat_message',
      );

  static NotificationChannelConfig _groupChannel(
    String id, {
    String? soundFilename,
  }) =>
      NotificationChannelConfig(
        id: id,
        name: 'Group Messages',
        description: 'New group message notifications',
        importance: Importance.high,
        priority: Priority.high,
        soundFilename: soundFilename,
        iconDrawable: 'ic_chat_message',
      );

  // --- DM channels ---
  static final dmDefault = _dmChannel('dm_default', soundFilename: 'chat_message_sound');
  static final dmSneeze = _dmChannel('dm_sneeze', soundFilename: 'chat_sound_sneeze');
  static final dmSms = _dmChannel('dm_sms', soundFilename: 'chat_sound_sms');
  static final dmCarLock = _dmChannel('dm_car_lock', soundFilename: 'chat_sound_car_lock');
  static final dmCustomSystem = _dmChannel('dm_custom_system');

  // --- Group channels ---
  static final groupDefault = _groupChannel('group_default', soundFilename: 'chat_message_sound');
  static final groupSneeze = _groupChannel('group_sneeze', soundFilename: 'chat_sound_sneeze');
  static final groupSms = _groupChannel('group_sms', soundFilename: 'chat_sound_sms');
  static final groupCarLock = _groupChannel('group_car_lock', soundFilename: 'chat_sound_car_lock');
  static final groupCustomSystem = _groupChannel('group_custom_system');

  // --- Other ---
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

  static List<NotificationChannelConfig> get allDmChannels => [
    dmDefault,
    dmSneeze,
    dmSms,
    dmCarLock,
    dmCustomSystem,
  ];

  static List<NotificationChannelConfig> get allGroupChannels => [
    groupDefault,
    groupSneeze,
    groupSms,
    groupCarLock,
    groupCustomSystem,
  ];

  static List<NotificationChannelConfig> get all => [
    ...allDmChannels,
    ...allGroupChannels,
    incomingCall,
    appUpdate,
  ];
}
