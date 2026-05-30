import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/services/search_service.dart';

final localSearchServiceProvider = Provider<LocalSearchService>((ref) {
  final db = ref.read(messageDatabaseProvider);
  return LocalSearchService(db);
});

class LocalSearchService implements SearchService {
  final MessageDatabase _db;

  LocalSearchService(this._db);

  @override
  Future<List<SearchResultModel>> searchMessages({
    required String query,
    required String currentUid,
    required List<ChatModel> chatRooms,
    int limit = 50,
  }) async {
    final s0 = DateTime.now();
    final messages = await _db.searchMessages(query, currentUid, limit: limit);
    final s1 = DateTime.now();
    debugPrint('🥷 SQL query only: ${s1.difference(s0).inMilliseconds}ms');

    final chatMap = {for (final c in chatRooms) c.id: c};
    final s2 = DateTime.now();
    debugPrint('🥷 chatMap build: ${s2.difference(s1).inMilliseconds}ms');

    final resultList = messages.map((msg) {
      final chat = chatMap[msg.chatRoomId];
      return SearchResultModel(
        messageId: msg.id,
        chatRoomId: msg.chatRoomId,
        chatName: chat?.displayName(currentUid) ?? 'Unknown',
        senderId: msg.senderId,
        messageText: msg.textContent,
        senderName: msg.senderName,
        sentAt: DateTime.fromMillisecondsSinceEpoch(msg.sentAt),
        messageType: msg.type,
        mediaUrls: msg.mediaUrls,
        mimeType: msg.mimeType,
        fileName: msg.fileName,
        fileSizeBytes: msg.fileSizeBytes,
      );
    }).toList();
    final s3 = DateTime.now();
    debugPrint('🥷 model mapping: ${s3.difference(s2).inMilliseconds}ms');
    return resultList;
  }

  @override
  void cancelSearch() {
  }

  @override
  void dispose() {
    // Nothing to do
  }
}
