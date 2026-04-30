import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';

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
  Stream<List<ChatModel>> streamChatList(String currentUid) {
    return _chatsRef
        .where('members', arrayContains: currentUid)
        .orderBy('lastMessage.sentAt', descending: true)
        .snapshots()
        .map(
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
  Stream<List<MessageModel>> streamMessages(String chatId, {int limit = 20}) {
    return _messagesRef(chatId)
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Fetches older messages for pagination
  Future<List<MessageModel>> fetchOlderMesages(
    String chatId, {
    required DocumentSnapshot lastDocument,
    int limit = 20,
  }) async {
    final snapshot = await _messagesRef(chatId)
        .orderBy('sentAt', descending: true)
        .startAfterDocument(lastDocument)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchRawMesages(
    String chatId, {
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _messagesRef(
      chatId,
    ).orderBy('sentAt', descending: true).limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.get();
  }

  // --- Send Messages --------------------------------
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    required List<String> memberUids,
  }) async {
    final batch = _firestore.batch();

    final msgRef = _messagesRef(chatId).doc();
    batch.set(
      msgRef,
      MessageModel.toNewMessageMap(senderId: senderId, text: text),
    );

    final chatRef = _chatsRef.doc(chatId);
    batch.update(chatRef, {
      ...MessageModel.toLastMessageMap(senderId: senderId, text: text),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final unreadUpdates = <String, dynamic>{};
    for (final uid in memberUids) {
      if (uid != senderId) {
        unreadUpdates['unreadCount.$uid'] = FieldValue.increment(1);
      }
    }
    batch.update(chatRef, unreadUpdates);

    await batch.commit();
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
  Future<void> resetUnreadCount(String chatId, String uid) async {
    await _chatsRef.doc(chatId).update({'unreadCount.$uid': 0});
  }

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
  
  // ---- CHECK MESSAGE STATUS ------------------
  Future<void> markChatAsRead(String chatId, uid) async {
    await _chatsRef.doc(chatId).update({
      'lastReadAt.$uid': FieldValue.serverTimestamp(),
      'unreadCount.$uid': 0,
    });
  }
}

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());
