import 'package:flutter/cupertino.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/search/services/search_service/typesense/typesense_config.dart';
import 'package:typesense/typesense.dart';

class TypesenseIndexService {
  final Client _client;
  final ChatService _chatService;

  TypesenseIndexService(this._client, this._chatService);

  // Create message collection only in setup
  Future<void> createCollection() async {
    try {
      await _client.collection(TypesenseConfig.collectionName).retrieve();
      debugPrint('🔍 Collection already exists');
      return;
    } catch (_) {}

    final schema = Schema(
      TypesenseConfig.collectionName,
      {
        // Searchable text
        Field('messageText', type: Type.string),
        Field('senderName', type: Type.string),

        // Filterable fields
        Field('chatRoomId', type: Type.string, isFacetable: true),
        Field('senderId', type: Type.string),

        // Sortable fields
        Field('sentAt', type: Type.int64, sort: true),
      },
      defaultSortingField: Field('sentAt', type: Type.int64),
    );

    await _client.collections.create(schema);
    debugPrint('🔍 Collection created');
  }

  // Indexes all messages from chat room for Typesense
  Future<void> indexAllMessages({
    required String currentUid,
    required List<ChatModel> chatRooms,
  }) async {
    int totalIndexed = 0;

    await createCollection();

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
            .collection(TypesenseConfig.collectionName)
            .documents
            .importDocuments(docs, options: {'action': 'upsert'});

        totalIndexed += docs.length;
        debugPrint('🔍 Indexed ${docs.length} messages from ${chat.id}');
      } catch (e) {
        debugPrint('🔍 Index failed for ${chat.id}: $e');
      }
    }
    debugPrint('🔍 Indexing complete! Total: $totalIndexed');
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
