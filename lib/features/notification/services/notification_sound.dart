import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationSound {
  final String id;
  final String displayName;
  final bool isSystemRingtone;
  final String? androidResource;
  final String? androidUri;
  final String? iosFilename;
  final String? assetPath;

  const NotificationSound({
    required this.id,
    required this.displayName,
    this.isSystemRingtone = false,
    this.androidResource,
    this.androidUri,
    this.iosFilename,
    this.assetPath,
  });

  factory NotificationSound.systemRingtone({
    required String uri,
    required String name,
  }) {
    return NotificationSound(
      id: 'system',
      displayName: name,
      isSystemRingtone: true,
      androidUri: uri,
    );
  }

  static const defaultSound = NotificationSound(
    id: 'default',
    displayName: 'Default',
    androidResource: 'chat_message_sound',
    iosFilename: 'chat_message_sound.wav',
    assetPath: 'sounds/chat_message_sound.wav',
  );

  static const sneeze = NotificationSound(
    id: 'sneeze',
    displayName: 'Sneeze',
    androidResource: 'chat_sound_sneeze',
    iosFilename: 'chat_sound_sneeze.wav',
    assetPath: 'sounds/chat_sound_sneeze.wav',
  );

  static const sms = NotificationSound(
    id: 'sms',
    displayName: 'SMS',
    androidResource: 'chat_sound_sms',
    iosFilename: 'chat_sound_sms.wav',
    assetPath: 'sounds/chat_sound_sms.wav',
  );

  static const carLock = NotificationSound(
    id: 'car_lock',
    displayName: 'Car Lock',
    androidResource: 'chat_sound_car_lock',
    iosFilename: 'chat_sound_car_lock.wav',
    assetPath: 'sounds/chat_sound_car_lock.wav',
  );

  static const List<NotificationSound> bundled = [
    defaultSound,
    sneeze,
    sms,
    carLock,
  ];

  static const String defaultId = 'default';
  static const String systemId = 'system';

  static NotificationSound? fromId(String id) {
    if (id == systemId) return null;
    try {
      return bundled.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  AndroidNotificationSound? toAndroidNotificationSound() {
    if (isSystemRingtone && androidUri != null) {
      return UriAndroidNotificationSound(androidUri!);
    }
    if (androidResource != null) {
      return RawResourceAndroidNotificationSound(androidResource!);
    }
    return null;
  }
}
