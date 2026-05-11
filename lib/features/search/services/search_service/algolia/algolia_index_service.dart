import 'package:algoliasearch/algoliasearch.dart';
import 'package:flutter/rendering.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/search/services/search_service/algolia/algolia_config.dart';

class AlgoliaIndexService {
  final SearchClient _client;
  final ChatService _chatService;

  AlgoliaIndexService(this._client, this._chatService);

  Future<void> indexAllMessages({
    required String currentUid,
    required List<ChatModel> chatRooms,
  }) async {
    await _configureIndex();

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

        await _client.batch(
          indexName: AlgoliaConfig.indexName,
          batchWriteParams: BatchWriteParams(
            requests: docs
                .map((doc) => BatchRequest(action: Action.addObject, body: doc))
                .toList(),
          ),
        );

        totalIndexed += docs.length;
        debugPrint('☁️ Indexed ${docs.length} messages from ${chat.id}');
      } catch (e) {
        debugPrint('☁️ Index failed for ${chat.id}: $e');
      }
    }

    debugPrint('☁️ Indexing complete! Total: $totalIndexed');
  }

  Future<void> _configureIndex() async {
    await _client.setSettings(
      indexName: AlgoliaConfig.indexName,
      indexSettings: IndexSettings(
        searchableAttributes: ['messageText', 'senderName'],
        attributesForFaceting: [
          'filterOnly(chatRoomId)',
          'filterOnly(senderId)',
        ],
      ),
    );
    debugPrint('☁️ Index settings configured');
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
