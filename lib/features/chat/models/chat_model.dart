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
  final Map<String, String>? createdBy;

  // Denormalized message preview
  final LastMessage? lastMessage;

  final Map<String, int> unreadCount;

  final List<String> typingUsers;
  final List<String> pinnedBy;

  // Check message sent status
  final Map<String, DateTime> lastReadAt;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? deletedBy;

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
    required this.pinnedBy,
    this.deletedBy,
    this.lastReadAt = const {},
  });

  ChatModel copyWith({
    String? id,
    String? type,
    List<String>? members,
    Map<String, MemberInfo>? memberInfo,
    String? Function()? memberHash,
    String? Function()? groupName,
    String? Function()? groupPhotoUrl,
    Map<String, String>? Function()? createdBy,
    LastMessage? Function()? lastMessage,
    Map<String, int>? unreadCount,
    List<String>? typingUsers,
    List<String>? pinnedBy,
    Map<String, DateTime>? lastReadAt,
    DateTime? createdAt,
    DateTime? Function()? updatedAt,
    Map<String, dynamic>? Function()? deletedBy,
  }) => ChatModel(
    id: id ?? this.id,
    type: type ?? this.type,
    members: members ?? this.members,
    memberInfo: memberInfo ?? this.memberInfo,
    memberHash: memberHash != null ? memberHash() : this.memberHash,
    groupName: groupName != null ? groupName() : this.groupName,
    groupPhotoUrl: groupPhotoUrl != null ? groupPhotoUrl() : this.groupPhotoUrl,
    createdBy: createdBy != null ? createdBy() : this.createdBy,
    lastMessage: lastMessage != null ? lastMessage() : this.lastMessage,
    unreadCount: unreadCount ?? this.unreadCount,
    typingUsers: typingUsers ?? this.typingUsers,
    pinnedBy: pinnedBy ?? this.pinnedBy,
    lastReadAt: lastReadAt ?? this.lastReadAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
    deletedBy: deletedBy != null ? deletedBy() : this.deletedBy,
  );

  bool get isDirect => type == 'direct';
  bool isPinnedBy(String uid) => pinnedBy.contains(uid);

  bool isDeletedBy(String uid) {
    if (deletedBy == null || !deletedBy!.containsKey(uid)) return false;
    final rawVal = deletedBy![uid];
    if (rawVal == null) return true;
    DateTime? deletedAt;
    if (rawVal is Timestamp) {
      deletedAt = rawVal.toDate();
    } else if (rawVal is DateTime) {
      deletedAt = rawVal;
    } else if (rawVal is int) {
      deletedAt = DateTime.fromMillisecondsSinceEpoch(rawVal);
    }
    if (deletedAt == null) return false;
    final lastSentAt = lastMessage?.sentAt;
    if (lastSentAt != null && lastSentAt.isAfter(deletedAt)) return false;

    return true;
  }

  /// Returns the other user's UID in a direct chat.
  String otherMemberUid(String currentUid) =>  members.firstWhere(
    (uid) => uid != currentUid,
    orElse: () => '',
  );


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
      createdBy: data['createdBy'] != null 
          ? Map<String, String>.from(data['createdBy']) 
          : null,
      lastMessage: data['lastMessage'] != null
          ? LastMessage.fromFirestore(data['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: parsedUnread,
      typingUsers: List<String>.from(data['typingUsers'] ?? []),
      pinnedBy: List<String>.from(data['pinnedBy'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      deletedBy: data['deletedBy'] as Map<String, dynamic>?,
      lastReadAt: (data['lastReadAt'] as Map<String, dynamic>? ?? {}).map(
        (uid, ts) => MapEntry(
          uid,
          (ts as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ),
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
    required String createdByUid,
    required String createdByName,
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
      'createdBy': {'uid': createdByUid, 'name': createdByName},
      'lastMessage': {
        'text': '',
        'sentAt': FieldValue.serverTimestamp(),
        'senderId': createdByUid,
      },
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
  
  factory LastMessage.fromJson(Map<String, dynamic> data) => LastMessage(
    text: data['text'] as String? ?? '',
    sentBy: data['sentBy'] as String? ?? '',
    sentAt: data['sentAt'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(data['sentAt'] as int)
        : DateTime.now(),
    type: data['type'] as String? ?? 'text',
  );

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'sentBy': sentBy,
      'sentAt': sentAt.millisecondsSinceEpoch, 
      'type': type,
    };
  }

  factory LastMessage.fromFirestore(Map<String, dynamic> data) => LastMessage(
    text: data['text'] as String? ?? '',
    sentBy: data['sentBy'] as String? ?? '',
    sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    type: data['type'] as String? ?? 'text',
  );


  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'sentBy': sentBy,
      'sentAt': Timestamp.fromDate(sentAt),
      'type': type,
    };
  }
}
