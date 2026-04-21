import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? bio;

  // Presence
  final bool isOnline;
  final DateTime? lastSeen;

  // Push notifications
  final String? fcmToken;
  final bool notificationsEnabled;

  // Privacy
  final PrivacySettings privacy;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.bio,
    this.isOnline = false,
    this.lastSeen,
    this.fcmToken,
    this.notificationsEnabled = true,
    this.privacy = const PrivacySettings(),
    required this.createdAt,
    this.updatedAt,
  });

  /// Converts a Firestore document snapshot into a UserModel.
  ///
  /// Why [data] and not the snapshot directly? Because this keeps
  /// the model unaware of Firestore — you could feed it a map
  /// from anywhere (tests, cache, etc).
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] as String,
      displayName: data['displayName'] as String,
      email: data['email'] as String,
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String?,
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      fcmToken: data['fcmToken'] as String?,
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      privacy: data['privacy'] != null
          ? PrivacySettings.fromMap(data['privacy'] as Map<String, dynamic>)
          : const PrivacySettings(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Converts to a map for writing to Firestore.
  ///
  /// Notice: createdAt uses FieldValue.serverTimestamp() only on create,
  /// not here. This toMap is for the "shape" of the data.
  /// The service layer decides when to use serverTimestamp().
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'fcmToken': fcmToken,
      'notificationsEnabled': notificationsEnabled,
      'privacy': privacy.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// For creating a brand new user doc after signup.
  static Map<String, dynamic> toNewUserMap({
    required String uid,
    required String displayName,
    required String email,
    String? photoUrl,
  }) {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'bio': null,
      'isOnline': true,
      'lastSeen': null,
      'fcmToken': null,
      'notificationsEnabled': true,
      'privacy': const PrivacySettings().toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
    String? fcmToken,
    bool? notificationsEnabled,
    PrivacySettings? privacy,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email, // immutable — comes from Auth
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      fcmToken: fcmToken ?? this.fcmToken,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      privacy: privacy ?? this.privacy,
      createdAt: createdAt, // immutable
      updatedAt: DateTime.now(),
    );
  }
}

class PrivacySettings {
  final bool showOnlineStatus;
  final bool showLastSeen;

  const PrivacySettings({
    this.showOnlineStatus = true,
    this.showLastSeen = true,
  });

  factory PrivacySettings.fromMap(Map<String, dynamic> data) {
    return PrivacySettings(
      showOnlineStatus: data['showOnlineStatus'] as bool? ?? true,
      showLastSeen: data['showLastSeen'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {'showOnlineStatus': showOnlineStatus, 'showLastSeen': showLastSeen};
  }
}
