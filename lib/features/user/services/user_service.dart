import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/cores/utils/log.dart';

class UserService {
  final FirebaseFirestore _firestore;

  // In prod pass FirebaseFirestore.instance
  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _userRef =>
      _firestore.collection('users');

  // --- READ -----------------------------
  // Stream a single user data in real-time
  Stream<UserModel?> streamUser(String uid) =>
      _userRef.doc(uid).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return UserModel.fromMap(snapshot.data()!);
      });

  // --- Stream user when creating new chat
  ///Saved the streamed user in a state, then proceed search later.
  ///Due to Firestore unable to search substring
  // Stream<List<UserModel>> streamAllUser() => _userRef
  //   .snapshots()
  //   .map((snapshot) => snapshot.docs
  //     .map((doc) => UserModel.fromMap(doc.data()))
  //   .toList());
  Stream<List<UserSearchModel>> streamAllUser() => _userRef
  .snapshots()
  .map((snapshot) => snapshot.docs.map((doc) {
      try {
        return UserSearchModel.fromMap(doc.data());
      } catch (e) {
        eLog('ERROR parsing user: $e');
        rethrow;
      }
    }).toList(),
  );

  /// One-shot read a user -> Didn't automatically live updates.
  /// e.g. building memberInfo when creating a new chat
  Future<UserModel?> getUser(String uid) async {
    final snapshot = await _userRef.doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return UserModel.fromMap(snapshot.data()!);
  }

  /// Search user (case insensitive)
  /// Excludes the current user from search
  Future<List<UserModel>> searchUsers({
    required String query,
    required String currentUid,
  }) async {
    final lowerQuery = query.trim().toLowerCase();
    if (lowerQuery.isEmpty) return [];

    final snapshot = await _userRef
        .orderBy('displayNameLower')
        .startAt([query])
        .startAt(['$query\uf8ff'])
        // .where('displayNameLower', isGreaterThanOrEqualTo: lowerQuery)
        // .where('displayNameLower', isLessThanOrEqualTo: lowerQuery + '\uf8ff')
        // .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .where((user) => user.uid != currentUid)
        .toList();
  }

  /// Check if users doc already exists in users/{uid}
  Future<bool> userDocExists(String uid) async {
    final doc = await _userRef.doc(uid).get();
    return doc.exists;
  }

  Future<bool> userEmailExists(String email) async {
    final doc = await _userRef.where('email', isEqualTo: email).limit(1).get();
    return doc.docs.isNotEmpty;
  }

  // --- WRITE ----------------------------
  /// Create a user after signup -> Right after FirebaseAuth creates an account (only once)
  Future<void> createUser({
    required String uid,
    required String displayName,
    required String email,
    String? photoURL,
  }) async {
    await _userRef
        .doc(uid)
        .set(
          UserModel.toNewUserMap(
            uid: uid,
            displayName: displayName,
            email: email,
            photoUrl: photoURL,
          ),
        );
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _userRef.doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoURL,
    String? bio,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) {
      updates['displayName'] = displayName;
      updates['displayNameLower'] = displayName.toLowerCase();
    }
    if (photoURL != null) updates['photoUrl'] = photoURL;
    if (bio != null) updates['bio'] = bio;

    if (updates.isNotEmpty) {
      await updateUser(uid, updates);
    }
  }

  // --- PRESENCE ----------------------------
  // Call when app comes to foreground
  Future<void> setOnline(String uid) async {
    await updateUser(uid, {'isOnline': true});
  }

  Future<void> setOffline(String uid) async {
    await updateUser(uid, {
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // --- Profile Chunks -----------------------
  Future<List<UserModel>> fetchUserByUids(List<String> uids) async {
    if (uids.isEmpty) return [];
    final snapshot = await _userRef
        .where(FieldPath.documentId, whereIn: uids)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
  }

  // --- FCM Token ----------------------------
  // Called on app startup or whenever the token refreshes
  Future<void> updateFcmToken(String uid, String token) async {
    await updateUser(uid, {'fcmToken': token});
  }

  // --- Privacy & Settings ----------------------------
  Future<void> updatePrivacy(String uid, PrivacySettings settings) async {
    await updateUser(uid, {'privacy': settings.toMap()});
  }

  Future<void> updateNotificationsEnabled(String uid, bool enabled) async {
    await updateUser(uid, {'notificationsEnabled': enabled});
  }
}

final userServiceProvider = Provider<UserService>((ref) => UserService());
