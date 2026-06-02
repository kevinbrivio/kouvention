import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationSound {
  final String id;
  final String displayName;
  final bool isSystemRingtone;
  final String? androidResource;
  final String? androidUri;
  final String? iosFilename;

  const NotificationSound({
    required this.id,
    required this.displayName,
    this.isSystemRingtone = false,
    this.androidResource,
    this.androidUri,
    this.iosFilename,
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
  );

  static const chime = NotificationSound(
    id: 'chime',
    displayName: 'Chime',
    androidResource: 'chat_sound_chime',
    iosFilename: 'chat_sound_chime.wav',
  );

  static const bell = NotificationSound(
    id: 'bell',
    displayName: 'Bell',
    androidResource: 'chat_sound_bell',
    iosFilename: 'chat_sound_bell.wav',
  );

  static const echo = NotificationSound(
    id: 'echo',
    displayName: 'Echo',
    androidResource: 'chat_sound_echo',
    iosFilename: 'chat_sound_echo.wav',
  );

  static const gentle = NotificationSound(
    id: 'gentle',
    displayName: 'Gentle',
    androidResource: 'chat_sound_gentle',
    iosFilename: 'chat_sound_gentle.wav',
  );

  static const List<NotificationSound> bundled = [
    defaultSound,
    chime,
    bell,
    echo,
    gentle,
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
