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
    throw UnimplementedError("INI BELUM DIIMPLEMENT");
  }

  @override
  void cancelSearch() {
  }

  @override
  void dispose() {
    // Nothing to do
  }
}
