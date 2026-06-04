class NotificationSound {
  final String id;
  final String displayName;
  final String? androidResource;
  final String? iosFilename;
  final String? assetPath;

  const NotificationSound({
    required this.id,
    required this.displayName,
    this.androidResource,
    this.iosFilename,
    this.assetPath,
  });

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

  static const String systemId = 'system';

  static NotificationSound? fromId(String id) {
    try {
      return bundled.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static String channelIdForSound(String soundId, {required bool isGroup}) {
    final prefix = isGroup ? 'group_' : 'dm_';
    if (soundId == systemId) return '${prefix}custom_system';
    return '$prefix$soundId';
  }

  static String displayNameForChannel(String channelId) {
    if (channelId.endsWith('_custom_system')) return 'System Ringtone';
    final soundId = channelId.replaceFirst(RegExp(r'^(dm|group)_'), '');
    final sound = NotificationSound.fromId(soundId);
    return sound?.displayName ?? 'Default';
  }

  static String? iosSoundForChannel(String channelId) {
    if (channelId.endsWith('_custom_system')) return null;
    final soundId = channelId.replaceFirst(RegExp(r'^(dm|group)_'), '');
    final sound = NotificationSound.fromId(soundId);
    return sound?.iosFilename;
  }

  static String soundIdFromChannelId(String channelId) {
    if (channelId.endsWith('_custom_system')) return systemId;
    return channelId.replaceFirst(RegExp(r'^(dm|group)_'), '');
  }
}
