class SearchResultModel {
  final String messageId;
  final String chatRoomId;
  final String chatName;
  final String senderId;
  final String messageText;
  final String senderName;
  final DateTime sentAt;
  final String messageType;
  final List<String>? mediaUrls;
  final String? mimeType;
  final String? fileName;
  final int? fileSizeBytes;

  SearchResultModel({
    required this.messageId,
    required this.chatRoomId,
    required this.chatName,
    required this.senderId,
    required this.messageText,
    required this.senderName,
    required this.sentAt,
    required this.messageType,
    this.mediaUrls,
    this.mimeType,
    this.fileName,
    this.fileSizeBytes,
  });

  SearchResultModel copyWith({String? senderName}) => SearchResultModel(
    messageId: messageId,
    chatRoomId: chatRoomId,
    chatName: chatName,
    senderId: senderId,
    messageText: messageText,
    senderName: senderName ?? this.senderName,
    sentAt: sentAt,
    messageType: messageType,
    mediaUrls: mediaUrls,
    mimeType: mimeType,
    fileName: fileName,
    fileSizeBytes: fileSizeBytes,
  );

  bool get hasMedia => mediaUrls != null && mediaUrls!.isNotEmpty;
  bool get isImage => messageType == 'image';
  bool get isVideo => messageType == 'video';
  bool get isFile => messageType == 'file';

  List<String>? get thumbnailUrls {
    if (mediaUrls == null) return null;
    return mediaUrls!.map((url) {
      final lower = url.toLowerCase();
      if (lower.endsWith('.pdf') || lower.endsWith('.mp4') ||
          lower.endsWith('.mov') || lower.endsWith('.avi') ||
          lower.endsWith('.mkv') || lower.endsWith('.webm')) {
        final dot = url.lastIndexOf('.');
        return '${url.substring(0, dot)}.jpg';
      }
      return url;
    }).toList();
  }
}
