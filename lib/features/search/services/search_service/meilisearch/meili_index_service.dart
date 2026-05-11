import 'package:flutter/rendering.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/search/services/search_service/meilisearch/meili_config.dart';
import 'package:meilisearch/meilisearch.dart';

class MeiliIndexService {
  final MeiliSearchClient _client;
  final ChatService _chatService;

  MeiliIndexService(this._client, this._chatService);

  Future<void> configureIndex() async {
    final index = _client.index(MeiliConfig.indexName);

    // Tell meili which to sort
    await index.updateFilterableAttributes(['chatRoomId', 'senderId']);
    await index.updateSortableAttributes(['sentAt']);

    await index.updateSearchableAttributes(['messageText', 'senderName']);

    debugPrint('🔎 Meilisearch index configured');
  }

  Future<void> indexAllMessages({
    required String currentUid,
    required List<ChatModel> chatRooms,
  }) async {
    await configureIndex();

    int totalIndexed = 0;

    for (final chat in chatRooms) {
      try {
        final messages = await _chatService.fetchMessagesSince(
          chat.id,
          since: DateTime(2020),
        );

        if (messages.isEmpty) continue;

        final docs = messages
            .where((m) => !m.isDeleted)
            .map((m) => _toDocument(m, chat.id))
            .toList();

        await _client
            .index(MeiliConfig.indexName)
            .addDocuments(docs, primaryKey: 'id');
        totalIndexed += docs.length;
        debugPrint('🔎 Indexed ${docs.length} messages from ${chat.id}');
      } catch (e) {
        debugPrint('🔎 Index failed for ${chat.id}: $e');
      }

      debugPrint('🔎 Indexing complete! Total: $totalIndexed');
    }
  }

  Map<String, dynamic> _toDocument(MessageModel msg, String chatRoomId) => {
    'id': msg.id,
    'messageText': msg.text,
    'chatRoomId': chatRoomId,
    'senderId': msg.senderId,
    'senderName': msg.senderName,
    'sentAt': msg.sentAt.millisecondsSinceEpoch,
  };
}
