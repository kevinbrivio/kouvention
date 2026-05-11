import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/search/services/search_service/typesense/typesense_config.dart';
import 'package:typesense/typesense.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/services/search_service.dart';

final typesenseSearchServiceProvider = Provider<TypesenseSearchService>((ref) {
  final client = TypesenseConfig.createClient();
  return TypesenseSearchService(client);
});

class TypesenseSearchService implements SearchService {
  final Client _client;

  TypesenseSearchService(this._client);

  @override
  Future<List<SearchResultModel>> searchMessages({
    required String query,
    required String currentUid,
    required List<ChatModel> chatRooms,
    int limit = 10,
  }) async {
    // Build filter: only search in user's chat room
    final chatRoomFilter = chatRooms
        .map((c) => 'chatRoomId:=${c.id}')
        .join(' || ');

    final searchParams = {
      'q': query,
      'query_by': 'messageText,senderName',
      'filter_by': chatRoomFilter,
      'sort_by': 'sentAt:desc',
      'per_page': '$limit',
      'num_typos': '2', // typo-tolerance
      'typo_tokens_threshold': '1',
    };

    final sw = Stopwatch()..start();
    debugPrint('🟢🟩 Typsense searching working');

    final response = await _client
        .collection(TypesenseConfig.collectionName)
        .documents
        .search(searchParams);

    sw.stop();
    debugPrint('🔍 Typesense search took: ${sw.elapsedMilliseconds}ms');
    // for (final r in results) {
    //   debugPrint('🔍 ${r.senderName}: ${r.messageText}');
    // }

    final hits = response['hits'] as List<dynamic>? ?? [];

    return hits.map((hit) {
      final doc = hit['document'] as Map<String, dynamic>;

      return SearchResultModel(
        messageId: doc['id'] as String,
        chatRoomId: doc['chatRoomId'] as String,
        messageText: doc['messageText'] as String,
        senderId: doc['senderId'] as String,
        senderName: doc['senderName'] as String,
        sentAt: DateTime.fromMillisecondsSinceEpoch(doc['sentAt'] as int),
      );
    }).toList();
  }

  @override
  void cancelSearch() {
    // Typesense HTTP client doesn't expose cancel
  }

  @override
  void dispose() {
    // Nothing to dispose
  }
}
