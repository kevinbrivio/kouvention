import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/services/search_service.dart';

final searchServiceProvider = Provider<SearchService>(
  (ref) => FirestoreSearchService(),
);

class FirestoreSearchService implements SearchService {
  @override
  Future<List<SearchResultModel>> searchMessages({
    required String query,
    required String currentUid,
    required List<ChatModel> chatRooms,
    int limit = 10,
  }) {
    // TODO: implement searchMessages
    throw UnimplementedError();
  }

  @override
  void cancelSearch() {
    // TODO: implement cancelSearch
  }

  @override
  void dispose() {
    // TODO: implement dispose
  }
}
