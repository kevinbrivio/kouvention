import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/services/search_service.dart';
import 'package:kouvention/features/search/services/search_service/meilisearch/meili_config.dart';
import 'package:meilisearch/meilisearch.dart';

final meiliSearchServiceProvider = Provider<MeiliSearchService>((ref) {
  final client = MeiliConfig.createClient();
  return MeiliSearchService(client);
});

class MeiliSearchService implements SearchService {
  final MeiliSearchClient _client;

  MeiliSearchService(this._client);

  @override
  Future<List<SearchResultModel>> searchMessages({
    required String query,
    required String currentUid,
    required List<ChatModel> chatRooms,
    int limit = 10,
  }) async {
    final chatRoomFilter = chatRooms
        .map((c) => 'chatRoomId = "${c.id}"')
        .join(' OR ');

    debugPrint('🟦🔵 Meili searching working');
    final sw = Stopwatch()..start();

    final result = await _client
        .index(MeiliConfig.indexName)
        .search(
          query,
          SearchQuery(
            filter: [chatRoomFilter],
            sort: ['sentAt:desc'],
            limit: limit,
          ),
        );

  debugPrint('${result.hits.length}');
    
    final hits = result.hits;
    sw.stop();
    debugPrint('🔎 Meilisearch took: ${sw.elapsedMilliseconds}ms');
    debugPrint('🔎 Results found: ${hits.length}');

    return hits
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
