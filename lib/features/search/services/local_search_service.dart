import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/databases/cached_messages.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/services/search_service.dart';

final localSearchServiceProvider = Provider<LocalSearchService>((ref) {
  final db = ref.read(messageDatabaseProvider);
  return LocalSearchService(db);
});

class LocalSearchService implements SearchService {
  final MessageDatabase _db;

  // For tracking down the SQL execution
  bool _isCancelled = false;

  LocalSearchService(this._db);

  @override
  Future<List<SearchResultModel>> searchMessages({
    required String query,
    required String currentUid,
    required List<ChatModel> chatRooms,
    int limit = 50,
  }) async {
    _isCancelled = false;

    final chatRoomIds = chatRooms.map((chat) => chat.id).toList();

    final rows = await _db.searchMessages(
      query: query,
      chatRoomIds: chatRoomIds,
      // limit: limit,
    );

    // If user is typing another query, return empty array
    if (_isCancelled) return [];

    return rows.map(_toResultModel).toList();
  }

  /// Convert from database to result model
  SearchResultModel _toResultModel(
    ({CachedMessage message, String chatName}) row,
  ) => SearchResultModel(
    messageId: row.message.id,
    chatRoomId: row.message.chatRoomId,
    chatName: row.chatName,
    messageText: row.message.messageText,
    senderId: row.message.senderId,
    senderName: row.message.senderName,
    sentAt: DateTime.fromMillisecondsSinceEpoch(row.message.sentAt),
  );

  @override
  void cancelSearch() {
    _isCancelled = true;
  }

  @override
  void dispose() {
    // Nothing to do
  }
}
