import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/user/models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore;

  // In prod pass FirebaseFirestore.instance
  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _userRef =>
      _firestore.collection('users');

  // --- READ -----------------------------
  // Stream a single user data in real-time
  Stream<UserModel?> streamUser(String uid) {
    return _userRef.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserModel.fromMap(snapshot.data()!);
    });
  }

  /// One-shot read a user -> Didn't automatically live updates.
  /// e.g. building memberInfo when creating a new chat
  Future<UserModel?> getUser(String uid) async {
    final snapshot = await _userRef.doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return UserModel.fromMap(snapshot.data()!);
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
    if (displayName != null) updates['displayName'] = displayName;
    if (photoURL != null) updates['photoURL'] = photoURL;
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
    await updateUser(uid, {'notificatonsEnabled': enabled});
  }
}

final userServiceProvider = Provider<UserService>((ref) => UserService());
