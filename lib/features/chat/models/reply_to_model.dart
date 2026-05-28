import 'package:cloud_firestore/cloud_firestore.dart';

class ReplyToModel {
  final String messageId;
  final String text;
  final String senderId;
  final String senderName;
  final DateTime sentAt;

  // Media
  final String? mediaUrl;
  final String? mediaType;

  ReplyToModel({
    required this.messageId,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.sentAt,
    this.mediaUrl,
    this.mediaType
  });

  factory ReplyToModel.fromMap(Map<String, dynamic> map) => ReplyToModel(
    messageId: map['messageId'] ?? '',
    text: map['text'] ?? '',
    senderId: map['senderId'] ?? '',
    senderName: map['senderName'] ?? '',
    sentAt: (map['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    mediaUrl: map['mediaUrl'],
    mediaType: map['mediaType'],
  );

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'text': text,
    'senderId': senderId,
    'senderName': senderName,
    'sentAt': sentAt,
    'mediaUrl': mediaUrl,
    'mediaType': mediaType,
  };
}
