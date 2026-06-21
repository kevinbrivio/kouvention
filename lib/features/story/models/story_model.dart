import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';

enum StoryType { image, video, audio, text }

enum StorySyncStatus { pending, uploading, synced, failed, deleting }

class StoryModel {
  final String id;
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;
  final StoryType type;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? text;
  final String? caption;
  final int? backgroundColorArgb;
  final String? cloudinaryPublicId;
  final List<String> visibleTo;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? deletedAt;
  final String? localPath;
  final StorySyncStatus syncStatus;
  final int retryCount;

  const StoryModel({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorPhotoUrl,
    required this.type,
    this.mediaUrl,
    this.thumbnailUrl,
    this.text,
    this.caption,
    this.backgroundColorArgb,
    this.cloudinaryPublicId,
    required this.visibleTo,
    required this.createdAt,
    required this.expiresAt,
    this.deletedAt,
    this.localPath,
    required this.syncStatus,
    this.retryCount = 0,
  });

  factory StoryModel.fromFirestore(String id, Map<String, dynamic> data) =>
      StoryModel(
        id: id,
        authorUid: data['authorUid'] as String,
        authorName: data['authorName'] as String,
        authorPhotoUrl: data['authorPhotoUrl'] as String?,
        type: StoryType.values.byName(data['type'] as String),
        mediaUrl: data['mediaUrl'] as String?,
        thumbnailUrl: data['thumbnailUrl'] as String?,
        text: data['text'] as String?,
        caption: data['caption'] as String?,
        backgroundColorArgb: (data['backgroundColorArgb'] as num?)?.toInt(),
        cloudinaryPublicId: data['cloudinaryPublicId'] as String?,
        visibleTo: List<String>.from(data['visibleTo'] as List? ?? const []),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        expiresAt: (data['expiresAt'] as Timestamp).toDate(),
        deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
        localPath: null,
        syncStatus: StorySyncStatus.synced,
      );

  factory StoryModel.fromDrift(Story row) => StoryModel(
    id: row.id,
    authorUid: row.authorUid,
    authorName: row.authorName,
    authorPhotoUrl: row.authorPhotoUrl,
    type: row.type,
    mediaUrl: row.mediaUrl,
    thumbnailUrl: row.thumbnailUrl,
    text: row.textContent,
    caption: row.caption,
    backgroundColorArgb: row.backgroundColorArgb,
    cloudinaryPublicId: row.cloudinaryPublicId,
    visibleTo: row.visibleTo,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(row.expiresAt),
    deletedAt: row.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.deletedAt!),
    localPath: row.localPath,
    syncStatus: row.syncStatus,
    retryCount: row.retryCount,
  );

  Map<String, dynamic> toFirestoreMap() => {
    'storyId': id,
    'authorUid': authorUid,
    'authorName': authorName,
    if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
    'type': type.name,
    if (mediaUrl != null) 'mediaUrl': mediaUrl,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (text != null) 'text': text,
    if (caption != null) 'caption': caption,
    if (backgroundColorArgb != null) 'backgroundColorArgb': backgroundColorArgb,
    if (cloudinaryPublicId != null) 'cloudinaryPublicId': cloudinaryPublicId,
    'visibleTo': visibleTo,
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
    if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
  };

  StoriesCompanion toCompanion() => StoriesCompanion(
    id: Value(id),
    authorUid: Value(authorUid),
    authorName: Value(authorName),
    authorPhotoUrl: Value(authorPhotoUrl),
    type: Value(type),
    mediaUrl: Value(mediaUrl),
    thumbnailUrl: Value(thumbnailUrl),
    textContent: Value(text),
    caption: Value(caption),
    backgroundColorArgb: Value(backgroundColorArgb),
    cloudinaryPublicId: Value(cloudinaryPublicId),
    visibleTo: Value(visibleTo),
    createdAt: Value(createdAt.millisecondsSinceEpoch),
    expiresAt: Value(expiresAt.millisecondsSinceEpoch),
    deletedAt: Value(deletedAt?.millisecondsSinceEpoch),
    localPath: Value(localPath),
    syncStatus: Value(syncStatus),
    retryCount: Value(retryCount),
  );
}
