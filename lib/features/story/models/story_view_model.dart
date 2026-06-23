import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';

class StoryViewModel {
  final String storyId;
  final String viewerUid;
  final DateTime viewedAt;
  final SyncStatus syncStatus;
  final int retryCount;

  const StoryViewModel({
    required this.storyId,
    required this.viewerUid,
    required this.viewedAt,
    required this.syncStatus,
    required this.retryCount,
  });

  factory StoryViewModel.fromFirestore({
    required String storyId,
    required String viewerUid,
    required Map<String, dynamic> data,
  }) => StoryViewModel(
    storyId: storyId,
    viewerUid: viewerUid,
    viewedAt: (data['viewedAt'] as Timestamp).toDate(),
    syncStatus: SyncStatus.sent,
    retryCount: 0,
  );

  factory StoryViewModel.fromDrift(StoryView row) => StoryViewModel(
    storyId: row.storyId,
    viewerUid: row.viewerUid,
    viewedAt: DateTime.fromMillisecondsSinceEpoch(row.viewedAt),
    syncStatus: row.syncStatus,
    retryCount: row.retryCount,
  );

  Map<String, dynamic> toFirestoreMap() => {
    'viewerUid': viewerUid,
    'viewedAt': Timestamp.fromDate(viewedAt),
  };

  StoryViewsCompanion toCompanion() => StoryViewsCompanion(
    storyId: Value(storyId),
    viewerUid: Value(viewerUid),
    viewedAt: Value(viewedAt.millisecondsSinceEpoch),
    syncStatus: Value(syncStatus),
    retryCount: Value(retryCount),
  );
}
