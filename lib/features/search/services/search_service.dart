import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';

abstract class SearchService {
  Future<List<SearchResultModel>> searchMessages({
    required String query,
    required String currentUid,
    required List<ChatModel> chatRooms,
    int limit = 10,
  });

  void cancelSearch();

  void dispose();
}
