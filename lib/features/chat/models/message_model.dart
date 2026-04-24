import 'package:cloud_firestore/cloud_firestore.dart';

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

  const MessageModel({
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

  factory MessageModel.fromMap(String docId, Map<String, dynamic> data) =>
      MessageModel(
        id: docId,
        senderId: data['senderId'] as String,
        text: data['text'] as String? ?? '',
        type: data['type'] as String? ?? 'text',
        sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        mediaUrl: data['mediaUrl'] as String?,
        fileName: data['fileName'] as String?,
        fileSizeBytes: (data['fileSizeBytes'] as num?)?.toInt(),
      );

  static Map<String, dynamic> toNewMessageMap({
    required String senderId,
    required String text,
  }) {
    return {
      'senderId': senderId,
      'text': text,
      'type': 'text',
      'sentAt': FieldValue.serverTimestamp(),
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
        'sentAt': FieldValue.serverTimestamp(),
        'type': 'text',
      },
    };
  }
}
