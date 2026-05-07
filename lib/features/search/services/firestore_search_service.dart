import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/services/search_service.dart';

final firestoreSearchServiceProvider = Provider<FirestoreSearchService>(
  (ref) => FirestoreSearchService(),
);

class FirestoreSearchService extends SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<SearchResultModel>> searchMessages({
    required String query,
    required String currentUid,
    required List<ChatModel> chatRooms,
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // Query every chat room in parallel
    final futures = chatRooms.map(
      (c) => _searchInChatRoom(
        query: trimmed,
        chatRoomId: c.id,
        currentUid: currentUid,
        limit: limit,
      ),
    );

    final resultPerChat = await Future.wait(futures);

    return resultPerChat.expand((list) => list).toList();
  }

  Future<List<SearchResultModel>> _searchInChatRoom({
    required String query,
    required String chatRoomId,
    required String currentUid,
    required int limit,
  }) async {
    try {
      debugPrint('chat room id: $chatRoomId');
      debugPrint('query: $query');
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .where('text', isGreaterThanOrEqualTo: query)
          .where('text', isLessThanOrEqualTo: '$query\uf8ff')
          .orderBy('text')
          .limit(limit)
          .get();

      return snapshot.docs
          .where((doc) {
            // filter deleted message
            final deletedFor = List<String>.from(
              doc.data()['deletedFor'] ?? [],
            );

            return !deletedFor.contains(currentUid);
          })
          .map(
            (doc) => SearchResultModel(
              messageId: doc.id,
              chatRoomId: chatRoomId,
              messageText: doc.data()['text'] ?? '',
              senderId: doc.data()['senderId'] ?? '',
              senderName: doc.data()['senderName'] ?? '',
              sentAt:
                  (doc.data()['sentAt'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('error in searching firestore: $e');
      return [];
    }
  }

  @override
  void cancelSearch() {
    /// Firestore .get() cannot be cancelled. This is the limitations :(
  }

  @override
  void dispose() {
    // Nothing to clean up
  }
}
