import 'package:algoliasearch/algoliasearch.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/services/search_service.dart';
import 'package:kouvention/features/search/services/search_service/algolia/algolia_config.dart';

final algoliaSearchServiceProvider = Provider<AlgoliaSearchService>((ref) {
  final client = AlgoliaConfig.searchClient;
  return AlgoliaSearchService(client);
});

class AlgoliaSearchService implements SearchService {
  final SearchClient _client;

  AlgoliaSearchService(this._client);

  @override
  Future<List<SearchResultModel>> searchMessages({
    required String query,
    required String currentUid,
    required List<ChatModel> chatRooms,
    int limit = 10,
  }) async {
    final chatRoomFilter = chatRooms
        .map((c) => 'chatRoomId:"${c.id}"')
        .join(' OR ');

    final sw = Stopwatch()..start();
    final result = await _client.searchSingleIndex(
      indexName: AlgoliaConfig.indexName,
      searchParams: SearchParamsObject(
        query: query,
        filters: chatRoomFilter,
        hitsPerPage: limit,
      ),
    );

    sw.stop();
    debugPrint('☁️ Algolia search took: ${sw.elapsedMilliseconds}ms');
    debugPrint('☁️ Results found: ${result.nbHits}');

    return result.hits
        .map(
          (hit) => SearchResultModel(
            messageId: hit['id'] as String,
            chatRoomId: hit['chatRoomId'] as String,
            messageText: hit['messageText'] as String,
            senderId: hit['senderId'] as String,
            senderName: hit['senderName'] as String,
            sentAt: DateTime.fromMillisecondsSinceEpoch(hit['sentAt'] as int),
          ),
        )
        .toList();
  }

  @override
  void cancelSearch() {}

  @override
  void dispose() {}
}
