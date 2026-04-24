import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id; // the Firestore document ID
  final String type; // "direct" or "group"
  final List<String> members;
  final Map<String, MemberInfo> memberInfo;
  final String? memberHash; // sorted UIDs for direct chats only

  // Group-specific fields
  final String? groupName;
  final String? groupPhotoUrl;
  final String? createdBy;

  // Denormalized message preview
  final LastMessage? lastMessage;

  final Map<String, int> unreadCount;

  final List<String> typingUsers;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const ChatModel({
    required this.id,
    required this.type,
    required this.members,
    required this.memberInfo,
    this.memberHash,
    this.groupName,
    this.groupPhotoUrl,
    this.createdBy,
    this.lastMessage,
    this.unreadCount = const {},
    this.typingUsers = const [],
    required this.createdAt,
    this.updatedAt,
  });

  bool get isDirect => type == 'direct';

  /// Returns the other user's UID in a direct chat.
  String otherMemberUid(String currentUid) {
    assert(isDirect, 'otherMemberUid() is only valid for direct chats');
    return members.firstWhere((uid) => uid != currentUid);
  }

  /// Returns the display name for this chat.
  String displayName(String currentUid) {
    if (isDirect) {
      final otherUid = otherMemberUid(currentUid);
      return memberInfo[otherUid]?.displayName ?? 'Unknown';
    }
    return groupName ?? 'Unnamed Group';
  }

  /// Returns each members name
  String memberNameText(String currentUid) {
    final others = memberInfo.entries
        .where((e) => e.key != currentUid)
        .map((e) => e.value.displayName)
        .toList();
    if (others.isEmpty) return '';
    
    return others.join(', ');
  }

  /// Returns the photo URL for this chat.
  String? displayPhotoUrl(String currentUid) {
    if (isDirect) {
      final otherUid = otherMemberUid(currentUid);
      return memberInfo[otherUid]?.photoUrl;
    }
    return groupPhotoUrl;
  }

  /// Returns unread count for a specific user.
  int unreadCountFor(String uid) => unreadCount[uid] ?? 0;

  /// Generates a memberHash from two UIDs.
  static String generateMemberHash(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}__${sorted[1]}';
  }

  factory ChatModel.fromMap(String docId, Map<String, dynamic> data) {
    // Parse memberInfo: { uid: { displayName, photoUrl } }
    final rawMemberInfo = data['memberInfo'] as Map<String, dynamic>? ?? {};
    final parsedMemberInfo = rawMemberInfo.map(
      (uid, value) =>
          MapEntry(uid, MemberInfo.fromMap(value as Map<String, dynamic>)),
    );

    // Parse unreadCount: { uid: int }
    final rawUnread = data['unreadCount'] as Map<String, dynamic>? ?? {};
    final parsedUnread = rawUnread.map(
      (uid, count) => MapEntry(uid, (count as num?)?.toInt() ?? 0),
    );

    return ChatModel(
      id: docId,
      type: data['type'] as String? ?? 'direct',
      members: List<String>.from(data['members'] ?? []),
      memberInfo: parsedMemberInfo,
      memberHash: data['memberHash'] as String?,
      groupName: data['groupName'] as String?,
      groupPhotoUrl: data['groupPhotoUrl'] as String?,
      createdBy: data['createdBy'] as String?,
      lastMessage: data['lastMessage'] != null
          ? LastMessage.fromMap(data['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: parsedUnread,
      typingUsers: List<String>.from(data['typingUsers'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// For creating a new direct chat.
  static Map<String, dynamic> toNewDirectChatMap({
    required String currentUid,
    required String otherUid,
    required Map<String, MemberInfo> memberInfo,
  }) {
    final members = [currentUid, otherUid];
    return {
      'type': 'direct',
      'members': members,
      'memberInfo': memberInfo.map((uid, info) => MapEntry(uid, info.toMap())),
      'memberHash': generateMemberHash(currentUid, otherUid),
      'groupName': null,
      'groupPhotoUrl': null,
      'createdBy': null,
      'lastMessage': null,
      'unreadCount': {currentUid: 0, otherUid: 0},
      'typingUsers': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// For creating a new group chat.
  static Map<String, dynamic> toNewGroupChatMap({
    required String createdBy,
    required List<String> members,
    required Map<String, MemberInfo> memberInfo,
    required String groupName,
    String? groupPhotoUrl,
  }) {
    return {
      'type': 'group',
      'members': members,
      'memberInfo': memberInfo.map((uid, info) => MapEntry(uid, info.toMap())),
      'memberHash': null,
      'groupName': groupName,
      'groupPhotoUrl': groupPhotoUrl,
      'createdBy': createdBy,
      'lastMessage': null,
      'unreadCount': {for (final uid in members) uid: 0},
      'typingUsers': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class MemberInfo {
  final String displayName;
  final String? photoUrl;

  const MemberInfo({required this.displayName, this.photoUrl});

  factory MemberInfo.fromMap(Map<String, dynamic> data) {
    return MemberInfo(
      displayName: data['displayName'] as String? ?? 'Unknown',
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {'displayName': displayName, 'photoUrl': photoUrl};
  }
}

class LastMessage {
  final String text;
  final String sentBy;
  final DateTime sentAt;
  final String type;

  const LastMessage({
    required this.text,
    required this.sentBy,
    required this.sentAt,
    this.type = 'text',
  });

  factory LastMessage.fromMap(Map<String, dynamic> data) {
    return LastMessage(
      text: data['text'] as String? ?? '',
      sentBy: data['sentBy'] as String? ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] as String? ?? 'text',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'sentBy': sentBy,
      'sentAt': Timestamp.fromDate(sentAt),
      'type': type,
    };
  }
}
