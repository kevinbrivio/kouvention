class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String type; // "text" for now, "image" | "file" | "video" later
  final DateTime sentAt;

  // FUTURE CASES
  final String? mediaUrl;
  final String? fileName;
  final int? fileSizeBytes;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = 'text',
    required this.sentAt,
    this.mediaUrl,
    this.fileName,
    this.fileSizeBytes,
  });

  bool get hasMedia => mediaUrl != null;

  factory MessageModel.fromJson(String docId, Map<String, dynamic> data) =>
      MessageModel(
        id: docId,
        senderId: data['senderId'] as String,
        text: data['text'] as String? ?? '',
        type: data['type'] as String? ?? 'text',
        sentAt: DateTime.parse(data['sentAt'] as String),
        mediaUrl: data['mediaUrl'] as String?,
        fileName: data['fileName'] as String?,
        fileSizeBytes: data['fileSizeBytes'] as int?,
      );

  static Map<String, dynamic> toNewMessageMap({
    required String senderId,
    required String text,
  }) {
    return {
      'senderId': senderId,
      'text': text,
      'type': 'text',
      'sentAt': DateTime.now(),
    };
  }

  static Map<String, dynamic> toLastMessageMap({
    required String senderId,
    required String text,
  }) {
    return {
      'lastMessage': {
        'text': text,
        'sentBy': senderId,
        'sentAt': DateTime.now(),
        'type': 'text',
      },
    };
  }
}
