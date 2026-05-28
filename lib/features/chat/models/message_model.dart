import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final MessageType type;
  final DateTime sentAt;
  final ReplyToModel? replyTo;
  final bool isDeleted;
  final List<String> deletedFor;
  final DateTime updatedAt;

  final String? mimeType;
  final int? mediaDuration;

  final SyncStatus syncStatus;

  // MEDIA
  final List<dynamic>? mediaUrls;
  final String? fileName;
  final int? fileSizeBytes;
  final String? mediaGroupId;

  bool get hasMedia => mediaUrls != null;
  bool get isImage => type == MessageType.image;
  bool get isVideo => type == MessageType.video;
  bool get isAudio => type == MessageType.audio;
  bool get isFile => type == MessageType.file;

  List<dynamic> get allMediaUrls {
    if (mediaUrls != null && mediaUrls!.isNotEmpty) return mediaUrls!;
    return [];
  }

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.type = MessageType.text,
    required this.sentAt,
    this.replyTo,
    required this.syncStatus,
    this.mimeType,
    this.mediaDuration,
    this.mediaUrls = const [],
    this.fileName,
    this.fileSizeBytes,
    this.isDeleted = false,
    this.deletedFor = const [],
    required this.updatedAt,
    this.mediaGroupId,
  });

  factory MessageModel.fromMap(String docId, Map<String, dynamic> data) => MessageModel(
        id: docId,
        senderId: data['senderId'] as String,
        senderName: data['senderName'] as String,
        text: data['text'] as String? ?? '',
        type: MessageType.fromString(data['type'] as String? ?? 'text'),
        sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: data['updatedAt'] != null 
            ? (data['updatedAt'] as Timestamp).toDate() 
            : (data['sentAt'] as Timestamp).toDate(),
        replyTo: (data['replyTo'] != null)
            ? ReplyToModel.fromMap(data['replyTo'])
            : null,
        syncStatus: data['sync_status'] != null
          ? SyncStatus.values.firstWhere(
            (e) => e.name == data['sync_status'],
            orElse: () => SyncStatus.sent,
          )
          : SyncStatus.sent,
        mediaUrls: data['mediaUrls'] as List<dynamic>?,
        fileName: data['fileName'] as String?,
        mimeType: data['mimeType'] as String?,
        mediaDuration: (data['mediaDuration'] as num?)?.toInt(),
        fileSizeBytes: (data['fileSizeBytes'] as num?)?.toInt(),
        isDeleted: data['isDeleted'] ?? false,
        deletedFor: List<String>.from(data['deletedFor'] ?? []),
      );

  static Map<String, dynamic> toNewMessageMap({
    required String senderId,
    required String senderName,
    required String text,
    MessageType type = MessageType.text,
    ReplyToModel? replyTo,
    // Media files
    List<String>? mediaUrls,
    String? fileName,
    int? fileSizeBytes,
    String? mimeType,
    int? mediaDuration,
  }) {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': type.name,
      if (replyTo != null) 'replyTo': replyTo.toMap(),
      if (mediaUrls != null) 'mediaUrls': mediaUrls,
      if (fileName != null) 'fileName': fileName,
      if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
      if (mimeType != null) 'mimeType': mimeType,
      if (mediaDuration != null) 'mediaDuration': mediaDuration,
      'sentAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> toLastMessageMap({
    required String senderId,
    required String senderName,
    required String text,
    MessageType type = MessageType.text,
    ReplyToModel? replyTo,
  }) {
    return {
      'lastMessage': {
        'text': text,
        'sentBy': senderId,
        'senderName': senderName,
        if (replyTo != null) 'replyTo': replyTo.toMap(),
        'sentAt': FieldValue.serverTimestamp(),
        'type': type.name,
      },
    };
  }
}
