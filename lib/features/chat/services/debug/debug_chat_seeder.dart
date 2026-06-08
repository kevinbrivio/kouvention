import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';

/// One-shot debug helper that creates a direct chat pre-populated with N
/// messages, so older-message pagination (AGENTS.md §5 / §11.2) can be
/// exercised on a real device with a real chat.
///
/// **Only callable in debug builds.** Every public method asserts
/// [kDebugMode] at the top. Production code should not import this file
/// at all — it lives under `services/debug/` to make the intent obvious.
class DebugChatSeeder {
  DebugChatSeeder({
    required FirebaseFirestore firestore,
    required ChatService chatService,
    required SyncService syncService,
    required MessageDatabase db,
  }) : _firestore = firestore,
       _chatService = chatService,
       _syncService = syncService,
       _db = db;

  // Kept in case future versions need the logged-in uid for stamping
  // sync state on the seeded chat. Not currently used.
  // ignore: unused_field
  final SyncService _syncService;
  final FirebaseFirestore _firestore;
  final ChatService _chatService;
  final MessageDatabase _db;

  /// Stable fake uid used as the "other" member of every seeded chat. The
  /// user does not need to exist in `users/` for the chat to render.
  static const String debugBotUid = 'debug_bot_0001';

  /// Firestore batch write limit. Below the 500 cap with margin.
  static const int _batchSize = 450;

  /// Creates a new direct chat between [currentUid] and the debug bot,
  /// pre-populated with [messageCount] messages spaced 1 minute apart
  /// ending at `now`. Yields progress as `(seeded, total)` so the UI
  /// can show a progress indicator.
  ///
  /// Uses `Firestore.batch()` to write 450 messages per batch, then
  /// updates `lastMessage` + `unreadCount` + `updatedAt` in a final
  /// batch. This bypasses the per-message `sendMessage` transaction
  /// because we are seeding, not sending — but the resulting chat
  /// looks identical to one that grew organically.
  Stream<({int seeded, int total, String? chatId})> seedChat({
    required String currentUid,
    required int messageCount,
  }) async* {
    assert(kDebugMode, 'DebugChatSeeder is only available in debug builds');

    final now = DateTime.now();
    final chatRef = _firestore.collection('chats').doc();

    final memberInfo = <String, Map<String, dynamic>>{
      currentUid: {
        'displayName': 'You',
        'photoUrl': null,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      debugBotUid: {
        'displayName': 'Debug Bot',
        'photoUrl': null,
        'lastSeen': FieldValue.serverTimestamp(),
      },
    };

    yield (seeded: 0, total: messageCount, chatId: null);

    // 1. Create the chat doc.
    await chatRef.set({
      'type': 'direct',
      'members': [currentUid, debugBotUid],
      'memberInfo': memberInfo,
      'memberHash': _hash([currentUid, debugBotUid]),
      'groupName': null,
      'groupPhotoUrl': null,
      'pinnedBy': [currentUid],
      'lastMessage': null,
      'unreadCount': {currentUid: 0, debugBotUid: 0},
      'typingUsers': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    yield (seeded: 0, total: messageCount, chatId: chatRef.id);

    // 2. Write messages in batches.
    //
    // NOTE: Firestore security rules require `senderId == request.auth.uid`
    // on message creates, so all seeded messages must come from
    // [currentUid]. The two-member chat is still useful for unreadCount
    // semantics on the bot's side, but every message visually belongs to
    // the logged-in user. The "Debug Bot" still appears in the chat
    // metadata so a recipient would see it as a real conversation.
    int seeded = 0;
    String? lastText;
    int? lastSentAt;

    while (seeded < messageCount) {
      final batch = _firestore.batch();
      final end = (seeded + _batchSize).clamp(0, messageCount);
      final messagesRef = chatRef.collection('messages');

      for (var i = seeded; i < end; i++) {
        // Space messages 1 minute apart, oldest first, ending at `now`.
        final ageMinutes = (messageCount - 1 - i);
        final sentAt = now.subtract(Duration(minutes: ageMinutes));
        final sentAtMs = sentAt.millisecondsSinceEpoch;

        final msgRef = messagesRef.doc('$sentAtMs-$i');
        batch.set(msgRef, {
          'senderId': currentUid,
          'senderName': 'You',
          'text': 'Debug message #$i',
          'type': 'text',
          'isDeleted': false,
          'deletedFor': [],
          'sentAt': Timestamp.fromMillisecondsSinceEpoch(sentAtMs),
          'updatedAt': Timestamp.fromMillisecondsSinceEpoch(sentAtMs),
        });

        lastText = 'Debug message #$i';
        lastSentAt = sentAtMs;
      }

      await batch.commit();
      seeded = end;

      yield (seeded: seeded, total: messageCount, chatId: chatRef.id);
    }

    // 3. Finalize: update lastMessage + updatedAt.
    if (lastText != null && lastSentAt != null) {
      await chatRef.update({
        'lastMessage': {
          'text': lastText,
          'sentBy': currentUid,
          'senderName': 'You',
          'sentAt': Timestamp.fromMillisecondsSinceEpoch(lastSentAt),
          'type': 'text',
        },
        'unreadCount.${debugBotUid}': messageCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 4. Mirror to local Drift so the chat is visible in the chat list
    //    without waiting for the realtime subscription to catch up.
    final remote = await _chatService.getChat(chatRef.id);
    if (remote != null) {
      await _db.upsertChatRooms([
        SyncService.chatToCompanion(remote),
      ]);
    }

    yield (seeded: messageCount, total: messageCount, chatId: chatRef.id);
  }

  /// Soft-deletes every chat that includes the debug bot as a member.
  ///
  /// [currentUid] is the logged-in user; their `deletedBy` entry is
  /// stamped on the local Drift row so `ChatModel.isDeletedBy(uid)`
  /// returns true and the chat list filter (`!c.isDeletedBy(currentUid)`
  /// in `filteredChatListProvider`) hides the chat from the UI.
  ///
  /// **Firestore docs are NOT removed.** The `chats` collection has
  /// `allow delete: if false;` in `firestore.rules` (line 52), and
  /// lifting that for the debug seeder would weaken production
  /// security. If you need a real wipe, run a Cloud Function with
  /// admin privileges or clean up manually from the Firebase console.
  /// Repeated soft-deletes are safe — `markChatDeletedLocally` is
  /// idempotent.
  Future<int> deleteDebugChats({required String currentUid}) async {
    assert(kDebugMode, 'DebugChatSeeder is only available in debug builds');

    final chatsRef = _firestore.collection('chats');
    final query = await chatsRef
        .where('members', arrayContains: debugBotUid)
        .get();

    var softDeleted = 0;
    for (final doc in query.docs) {
      await _db.markChatDeletedLocally(doc.id, currentUid);
      softDeleted++;
    }

    return softDeleted;
  }

  String _hash(List<String> uids) {
    final sorted = [...uids]..sort();
    return sorted.join('|');
  }
}

final debugChatSeederProvider = Provider<DebugChatSeeder>((ref) {
  return DebugChatSeeder(
    firestore: FirebaseFirestore.instance,
    chatService: ref.watch(chatServiceProvider),
    syncService: ref.watch(syncServiceProvider),
    db: ref.watch(messageDatabaseProvider),
  );
});
