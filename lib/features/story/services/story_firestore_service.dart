import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/models/story_page.dart';
import 'package:kouvention/features/story/models/story_view_model.dart';

class StoryFirestoreService {
  static const int maxFeedPageSize = 50;

  final FirebaseFirestore _firestore;

  StoryFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _storiesRef =>
      _firestore.collection('stories');

  CollectionReference<Map<String, dynamic>> _storyViewsRef(String storyId) =>
      _storiesRef.doc(storyId).collection('views');

  Query<Map<String, dynamic>> _feedQuery({
    required String currentUid,
    required DateTime cutoff,
    required int limit,
    StoryCursor? cursor,
  }) {
    final pageSize = limit.clamp(1, maxFeedPageSize);

    Query<Map<String, dynamic>> query = _storiesRef
        .where('visibleTo', arrayContains: currentUid)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(pageSize);

    if (cursor != null) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.createdAt),
        cursor.storyId,
      ]);
    }

    return query;
  }

  Future<StoryPage> fetchFeedPage({
    required String currentUid,
    required DateTime cutoff,
    int limit = maxFeedPageSize,
    StoryCursor? cursor,
  }) async {
    final pageSize = limit.clamp(1, maxFeedPageSize);

    final snapshot = await _feedQuery(
      currentUid: currentUid,
      cutoff: cutoff,
      limit: limit,
      cursor: cursor,
    ).get();

    final stories = snapshot.docs
        .map((doc) => StoryModel.fromFirestore(doc.id, doc.data()))
        .toList();

    final lastStory = stories.isEmpty ? null : stories.last;

    return StoryPage(
      stories: stories,
      hasMore: snapshot.docs.length == pageSize,
      nextCursor: lastStory == null
          ? null
          : (createdAt: lastStory.createdAt, storyId: lastStory.id),
    );
  }

  Stream<List<StoryModel>> streamLatestFeed({
    required String currentUid,
    required DateTime cutoff,
    int limit = maxFeedPageSize,
  }) => _feedQuery(currentUid: currentUid, cutoff: cutoff, limit: limit)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => StoryModel.fromFirestore(doc.id, doc.data()))
            .toList(),
      );

  Future<void> createStory(StoryModel story) async {
    final ref = _storiesRef.doc(story.id);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) return;

      transaction.set(ref, story.toFirestoreMap());
    });
  }

  Future<void> softDeleteStory({
    required String storyId,
    required DateTime deletedAt,
  }) => _storiesRef.doc(storyId).update({
    'deletedAt': Timestamp.fromDate(deletedAt),
  });

  Future<void> markViewed(StoryViewModel view) => _storyViewsRef(
    view.storyId,
  ).doc(view.viewerUid).set(view.toFirestoreMap());
}

final storyFirestoreServicProvider = Provider<StoryFirestoreService>(
  (ref) => StoryFirestoreService(),
);
