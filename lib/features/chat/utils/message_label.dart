import 'package:kouvention/features/chat/models/message_type.dart';

/// Label for chat list (with emoji)
String lastMessageLabel(String text, MessageType type, String fileName) {
  if (text.isNotEmpty) return text;
  switch (type) {
    case MessageType.image:
      return '📷 Photo';
    case MessageType.video:
      return '🎥 $fileName';
    case MessageType.audio:
      return '🎵 $fileName';
    case MessageType.file:
      return '📎 $fileName';
    case MessageType.sticker:
      return 'Sticker';
    default:
      return '';
  }
}

/// Label for FCM push notificaitons (no emoji)
String fcmLabel(
  String caption,
  MessageType type, {
  int mediaCount = 1,
  String fileName = '',
}) {
  if (mediaCount > 1) {
    return '$mediaCount ${_pluralLabel(type)}';
  }
  if (caption.isNotEmpty) return caption;
  return _singleLabel(type, fileName);
}

String _singleLabel(MessageType type, String fileName) {
  switch (type) {
    case MessageType.image:
      return 'Photo';
    case MessageType.video:
      return 'Video';
    case MessageType.audio:
      return 'Audio';
    case MessageType.file:
      return 'File';
    case MessageType.sticker:
      return 'Sticker';
    default:
      return '';
  }
}

/// Resolves a video URL to its Cloudinary thumbnail (jpg)
String getCloudinaryThumbnail(String videoUrl) {
  if (videoUrl.isEmpty) return '';
  return videoUrl.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
}

String _pluralLabel(MessageType type) {
  switch (type) {
    case MessageType.image:
      return 'Photos';
    case MessageType.video:
      return 'Videos';
    case MessageType.audio:
      return 'Audio';
    case MessageType.file:
      return 'Files';
    case MessageType.sticker:
      return 'Stickers';
    default:
      return '';
  }
}
