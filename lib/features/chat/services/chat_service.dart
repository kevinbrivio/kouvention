import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/utils/message_label.dart';

/// Compound cursor for chat list pagination.
///
/// `(lastMessage.sentAt, chatId)` gives a stable tie-breaker so two chats
/// with the same `sentAt` (a server-timestamp batch) don't get skipped or
/// duplicated on pagination.
typedef ChatCursor = ({DateTime lastActivityAt, String chatId});

class ChatService {
  final FirebaseFirestore _firestore;

  ChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chatsRef =>
      _firestore.collection('chats');

  // Return a specific chat related subcollection message
  CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) =>
      _chatsRef.doc(chatId).collection('messages');

  // --- CHAT LIST -------------------------------
  /// Stream all chats the current user is member of
  /// Ordering from the most recent.
  /// This stream will fires every time:
  /// - a new chat is created
  /// - a chat is updated (e.g. a new message is added)
  /// unreadCount changes, typingUsers changes
  Stream<List<ChatModel>> streamChatList(String currentUid, {int? limit}) {
    var query = _chatsRef
        .where('members', arrayContains: currentUid)
        .orderBy('lastMessage.sentAt', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatModel.fromMap(doc.id, doc.data()))
              .where((chat) => !chat.isDeletedBy(currentUid))
              .toList(),
        );
  }

  /// Stream a single chat room
  /// Used in a chat room screen for typing and metadata
  Stream<ChatModel?> streamChat(String chatId) {
    return _chatsRef.doc(chatId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return ChatModel.fromMap(snapshot.id, snapshot.data()!);
    });
  }

  // --- MESSAGES --------------------------------
  ///  Streams the most recent messages in a chat
  /// [limit] controls the page size. Start with 20.
  /// This stream is for the FIRST page only — it stays live
  /// so new incoming messages appear instantly.
  Stream<List<MessageModel>> streamMessagesSince(String chatId, DateTime lastSyncAt) =>
      _messagesRef(chatId)
          .where('updatedAt', isGreaterThan: lastSyncAt)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
                .toList(),
          );

  Future<List<ChatModel>> fetchChatRooms(
    String currentUid, {
    int limit = 20,
    DateTime? startAfter,
  }) async {
    var query = _chatsRef
      .where('members', arrayContains: currentUid)
      .orderBy('lastMessage.sentAt', descending: true);

    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs
        .map((doc) => ChatModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// One-shot, paged fetch with a stable compound cursor.
  ///
  /// Ordering: `lastMessage.sentAt DESC, __name__ DESC`. The chatId tie-breaker
  /// is required for stable pagination across writes that batch the same
  /// timestamp. Requires the compound index
  /// `(members array-contains, lastMessage.sentAt desc, __name__ desc)`.
  Future<List<ChatModel>> fetchChatRoomsPage({
    required String currentUid,
    required int limit,
    ChatCursor? cursor,
  }) async {
    var query = _chatsRef
        .where('members', arrayContains: currentUid)
        .orderBy('lastMessage.sentAt', descending: true)
        .orderBy('__name__', descending: true);

    if (cursor != null) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.lastActivityAt),
        cursor.chatId,
      ]);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs
        .map((doc) => ChatModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Stream variant of [fetchChatRoomsPage]. The initial cursor lets callers
  /// resume from a specific page after a hot restart.
  Stream<List<ChatModel>> streamChatListPage({
    required String currentUid,
    required int limit,
    ChatCursor? cursor,
  }) {
    var query = _chatsRef
        .where('members', arrayContains: currentUid)
        .orderBy('lastMessage.sentAt', descending: true)
        .orderBy('__name__', descending: true)
        .limit(limit);

    if (cursor != null) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.lastActivityAt),
        cursor.chatId,
      ]);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatModel.fromMap(doc.id, doc.data()))
              .where((chat) => !chat.isDeletedBy(currentUid))
              .toList(),
        );
  }

  /// Fetches message after specific timestamp
  Future<List<MessageModel>> fetchMessages(
    String chatId, {
    required DateTime lastSyncTimestamp,
    int limit = 20,
  }) async {
    final snapshot = await _messagesRef(
      chatId,
    )
    .where('sentAt', isGreaterThan: lastSyncTimestamp)
    .orderBy('sentAt', descending: true).limit(limit).get();

    return snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<MessageModel>> fetchMessageAround(
    String chatId, {
    required DateTime aroundTimestamp,
    int limit = 50,
  }) async {
    final timestamp = Timestamp.fromDate(aroundTimestamp);
    final halfLimit = limit ~/ 2;

    final olderSnap = await _messagesRef(chatId)
        .orderBy('sentAt', descending: true)
        .where('sentAt', isLessThanOrEqualTo: timestamp)
        .limit(halfLimit)
        .get();

    final newerSnap = await _messagesRef(chatId)
        .orderBy('sentAt')
        .where('sentAt', isGreaterThan: timestamp)
        .limit(halfLimit)
        .get();

    final allDocs = [...newerSnap.docs.reversed, ...olderSnap.docs];

    return allDocs
        .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Fetches a single page of messages OLDER than [beforeSentAt]
  /// (millisecondsSinceEpoch) for [chatId], ordered chronologically
  /// (oldest first) so the caller can append the result directly to a
  /// local list. Returns up to [limit] rows.
  ///
  /// Implementation: one Firestore query, `orderBy('sentAt', desc)`
  /// + `startAfter(Timestamp.fromMillis(beforeSentAt))` + `limit`,
  /// then reverse the docs in memory to chronological order.
  ///
  /// `beforeSentAt <= 0` is treated as "no lower bound" (Firestore
  /// startAfter rejects sentinel timestamps). `limit <= 0` is also
  /// short-circuited so we never issue a zero-page query.
  Future<List<MessageModel>> fetchOlderMessagesPage({
    required String chatId,
    required int beforeSentAt,
    int limit = 50,
  }) async {
    if (limit <= 0 || beforeSentAt <= 0) return const [];
    final snap = await _messagesRef(chatId)
        .orderBy('sentAt', descending: true)
        .startAfter([Timestamp.fromMillisecondsSinceEpoch(beforeSentAt)])
        .limit(limit)
        .get();
    final docs = snap.docs.reversed.toList();
    return docs
        .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // --- Send Messages --------------------------------
  Future<void> sendMessage({
    required String chatId,
    required String messageId,
    required String senderId,
    required String senderName,
    required String text,
    required DateTime sentAt,
    required List<String> memberUids,
    ReplyToModel? replyTo,
  }) async {
    await _firestore.runTransaction((tx) async {
      final msgRef = _messagesRef(chatId).doc(messageId);
      final existing = await tx.get(msgRef);
      if (existing.exists) return;

      tx.set(
        msgRef,
        MessageModel.toNewMessageMap(
          senderId: senderId,
          senderName: senderName,
          text: text,
          sentAt: sentAt,
          replyTo: replyTo,
        ),
      );

      final chatRef = _chatsRef.doc(chatId);
      final unreadUpdates = <String, dynamic>{
        for (final uid in memberUids)
          if (uid != senderId) 'unreadCount.$uid': FieldValue.increment(1),
      };
      tx.update(chatRef, {
        ...MessageModel.toLastMessageMap(
          senderId: senderId,
          senderName: senderName,
          text: text,
          sentAt: sentAt,
          replyTo: replyTo,
        ),
        'updatedAt': Timestamp.fromDate(sentAt),
        ...unreadUpdates,
      });
    });
  }

  // --- SEND MEDIA MESSAGE ---------------------
  Future<void> sendMediaMessage({
    required String chatId,
    required String messageId,
    required String senderId,
    required String senderName,
    required String text,
    required MessageType type,
    required List<String> mediaUrls,
    required DateTime sentAt,
    List<String>? mediaCaptions,
    required String fileName,
    required int fileSizeBytes,
    required String mimeType,
    int? mediaDuration,
    required List<String> memberUids,
    ReplyToModel? replyTo,
  }) async {
    await _firestore.runTransaction((tx) async {
      final msgRef = _messagesRef(chatId).doc(messageId);
      final existing = await tx.get(msgRef);
      if (existing.exists) return;

      tx.set(
        msgRef,
        MessageModel.toNewMessageMap(
          senderId: senderId,
          senderName: senderName,
          text: text,
          sentAt: sentAt,
          type: type,
          replyTo: replyTo,
          mediaUrls: mediaUrls,
          mediaCaptions: mediaCaptions,
          fileName: fileName,
          fileSizeBytes: fileSizeBytes,
          mimeType: mimeType,
          mediaDuration: mediaDuration,
        ),
      );

      final chatRef = _chatsRef.doc(chatId);
      final unreadUpdates = <String, dynamic>{
        for (final uid in memberUids)
          if (uid != senderId) 'unreadCount.$uid': FieldValue.increment(1),
      };
      tx.update(chatRef, {
        ...MessageModel.toLastMessageMap(
          senderId: senderId,
          senderName: senderName,
          text: text.isNotEmpty ? text : lastMessageLabel(text, type, fileName),
          sentAt: sentAt,
          type: type,
          replyTo: replyTo,
        ),
        'updatedAt': Timestamp.fromDate(sentAt),
        ...unreadUpdates,
      });
    });
  }

  // --- GET CHATS --------------------------------
  /// Get chat detail
  Future<ChatModel?> getChat(String chatId) async {
    final doc = await _chatsRef.doc(chatId).get();
    return doc.exists ? ChatModel.fromMap(doc.id, doc.data()!) : null;
  }

  /// Get other user group in common
  Future<List<ChatModel>> getGroupInCommon(String currentUid, otherUid) async {
    final doc = await _chatsRef
        .where('type', isEqualTo: 'group')
        .where('members', arrayContains: currentUid)
        .get();

    return doc.docs
        .map((d) => ChatModel.fromMap(d.id, d.data()))
        .where((chat) => chat.members.contains(otherUid))
        .toList();
  }

  // --- UNREAD COUNT --------------------------------
  // Removed: resetUnreadCount. The single markChatAsRead() call below
  // writes both unreadCount.$uid = 0 and lastReadAt.$uid in one update
  // (AGENTS.md §9.8). Keeping a separate resetUnreadCount would
  // double-fire on retry.

  // --- Typing Indicators ----------------------------
  /// Adds user to TypingUsers array
  Future<void> setTyping(String chatId, String uid) async {
    await _chatsRef.doc(chatId).update({
      'typingUsers': FieldValue.arrayUnion([uid]),
    });
  }

  // Remove user from TypingUsers array
  Future<void> clearTyping(String chatId, String uid) async {
    await _chatsRef.doc(chatId).update({
      'typingUsers': FieldValue.arrayRemove([uid]),
    });
  }

  // --- Create Chat -----------------------------
  /// Creates a new chat for 1-on-1
  Future<String> createDirectChat({
    required String currentUid,
    required String otherUid,
    required Map<String, MemberInfo> memberInfo,
  }) async {
    final hash = ChatModel.generateMemberHash(currentUid, otherUid);
    final existing = await _chatsRef
        .where('memberHash', isEqualTo: hash)
        .where('members', arrayContains: currentUid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final docRef = await _chatsRef.add(
      ChatModel.toNewDirectChatMap(
        currentUid: currentUid,
        otherUid: otherUid,
        memberInfo: memberInfo,
      ),
    );

    return docRef.id;
  }

  Future<String> createGroupChat({
    required String createdByUid,
    required String createdByName,
    required List<String> members,
    required Map<String, MemberInfo> memberInfo,
    required String groupName,
    String? groupPhotoUrl,
  }) async {
    final docRef = await _chatsRef.add(
      ChatModel.toNewGroupChatMap(
        createdByUid: createdByUid,
        createdByName: createdByName,
        members: members,
        memberInfo: memberInfo,
        groupName: groupName,
        groupPhotoUrl: groupPhotoUrl,
      ),
    );

    return docRef.id;
  }

  // ------ PIN CHAT ----------
  Future<void> pinChat(String uid, chatId) async {
    debugPrint('Pinning chat: $chatId for user: $uid');
    debugPrint('Path: ${_chatsRef.doc(chatId).path}');
    await _chatsRef.doc(chatId).update({
      'pinnedBy': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> unpinChat(String uid, chatId) async {
    await _chatsRef.doc(chatId).update({
      'pinnedBy': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> deleteChat(String uid, String chatId) async {
    await _chatsRef.doc(chatId).update({
      'deletedBy.$uid': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessageForMe({
    required String uid,
    required String chatId,
    required List<String> messageIds,
  }) async {
    final batch = _firestore.batch();
    for (final msgId in messageIds) {
      batch.update(_messagesRef(chatId).doc(msgId), {
        'deletedFor': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> deleteMessageForEveryone(
    String chatId,
    List<String> messageIds,
  ) async {
    // final batch = _messagesRef(chatId).firestore.batch();
    final batch = _firestore.batch();

    for (final msgId in messageIds) {
      batch.update(_messagesRef(chatId).doc(msgId), {
        'isDeleted': true,
        'text': '',
        'replyTo': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ---- CHECK MESSAGE STATUS ------------------
  Future<void> markChatAsRead(String chatId, uid) async {
    await _chatsRef.doc(chatId).update({
      'lastReadAt.$uid': FieldValue.serverTimestamp(),
      'unreadCount.$uid': 0,
    });
  }
}

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());
