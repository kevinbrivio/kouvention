import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String type; // "text" for now, "image" | "file" | "video" later
  final DateTime sentAt;
  final ReplyToModel? replyTo;

  // FUTURE CASES
  final String? mediaUrl;
  final String? fileName;
  final int? fileSizeBytes;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.type = 'text',
    required this.sentAt,
    this.replyTo,
    this.mediaUrl,
    this.fileName,
    this.fileSizeBytes,
  });

  bool get hasMedia => mediaUrl != null;

  factory MessageModel.fromMap(String docId, Map<String, dynamic> data) =>
      MessageModel(
        id: docId,
        senderId: data['senderId'] as String,
        senderName: data['senderName'] as String,
        text: data['text'] as String? ?? '',
        type: data['type'] as String? ?? 'text',
        sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        replyTo: (data['replyTo'] != null)
            ? ReplyToModel.fromMap(data['replyTo'])
            : null,
        mediaUrl: data['mediaUrl'] as String?,
        fileName: data['fileName'] as String?,
        fileSizeBytes: (data['fileSizeBytes'] as num?)?.toInt(),
      );

  static Map<String, dynamic> toNewMessageMap({
    required String senderId,
    required String senderName,
    required String text,
    ReplyToModel? replyTo,
  }) {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': 'text',
      if (replyTo != null) 'replyTo': replyTo.toMap(),
      'sentAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> toLastMessageMap({
    required String senderId,
    required String senderName,
    required String text,
    ReplyToModel? replyTo,
  }) {
    return {
      'lastMessage': {
        'text': text,
        'sentBy': senderId,
        'senderName': senderName,
        if (replyTo != null) 'replyTo': replyTo.toMap(),
        'sentAt': FieldValue.serverTimestamp(),
        'type': 'text',
      },
    };
  }
}
