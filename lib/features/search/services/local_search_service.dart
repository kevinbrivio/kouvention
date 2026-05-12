import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/services/databases/search_database.dart';
import 'package:kouvention/features/search/services/search_service.dart';

final localSearchServiceProvider = Provider<LocalSearchService>((ref) {
  final db = ref.read(searchDatabaseProvider);
  return LocalSearchService(db);
});

class LocalSearchService implements SearchService {
  final SearchDatabase _db;

  // For tracking down the SQL execution
  bool _isCancelled = false;

  LocalSearchService(this._db);

  @override
  Future<List<SearchResultModel>> searchMessages({
    required String query,
    required String currentUid,
    required List<ChatModel> chatRooms,
    int limit = 10,
  }) async {
    _isCancelled = false;

    final chatRoomIds = chatRooms.map((chat) => chat.id).toList();

    final rows = await _db.searchMessages(
      query: query,
      chatRoomIds: chatRoomIds,
      limit: limit,
    );

    print(rows);

    // If user is typing another query, return empty array
    if (_isCancelled) return [];

    return rows.map(_toResultModel).toList();
  }

  /// Convert from database to result model
  SearchResultModel _toResultModel(CachedMessage row) => SearchResultModel(
    messageId: row.id,
    chatRoomId: row.chatRoomId,
    messageText: row.messageText,
    senderId: row.senderId,
    senderName: row.senderName,
    sentAt: DateTime.fromMillisecondsSinceEpoch(row.sentAt),
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
