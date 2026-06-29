import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/utils/profile_staleness.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/cores/utils/log.dart';
import 'package:kouvention/features/user/services/user_service.dart';

class UserProfileRepository {
  final UserService _userService;
  final MessageDatabase _db;

  UserProfileRepository({
    required UserService userService,
    required MessageDatabase db,
  }) : _userService = userService,
       _db = db;

  /// Drift stream for the visible UID set. Used in resolver providers.
  Stream<List<UserProfile>> watchProfileByIds(Set<String> uids) =>
      _db.watchProfileByIds(uids);

  /// Chunk whereIn, upsert into Drift, returns full result.
  Future<List<UserProfile>> fetchProfileByIds(Set<String> uids) async {
    if (uids.isEmpty) return [];

    final chunks = _chunk(uids.toList(), kProfileWhereInChunkSize);
    final fetched = <UserModel>[];

    for (final chunk in chunks) {
      try {
        final batch = await _userService.fetchUserByUids(chunk);
        fetched.addAll(batch);
      } catch (e) {
        eLog('[UserProfileRepository] fetchProfileByIds error: $e');
      }
    }

    if (fetched.isEmpty) {
      return _db.fetchProfileByIds(uids);
    }

    // Upsert to Drift
    final now = DateTime.now().millisecondsSinceEpoch;
    final companions = fetched.map((c) => _toCompanion(c, now)).toList();

    await _db.upsertUserProfiles(companions);

    return _db.fetchProfileByIds(uids);
  }

  /// Refresh rows that are either missing or older than the staleness threshold.
  Future<void> refreshStaleAndMissing(Set<String> uids, {DateTime? now}) async {
    if (uids.isEmpty) return;

    final cutoff = (now ?? DateTime.now())
        .subtract(kProfileStalenessWindow)
        .millisecondsSinceEpoch;

    final cached = await _db.fetchProfileByIds(uids);
    final cachedUids = cached.map((c) => c.uid).toSet();

    final missing = uids.where((u) => !cachedUids.contains(u)).toSet();
    final stale = cached
        .where((p) => p.updatedAt < cutoff)
        .map((p) => p.uid)
        .toSet();

    final toFetch = {...missing, ...stale};
    if (toFetch.isEmpty) return;

    await fetchProfileByIds(toFetch);
  }

  /// Force refresh for network resume. Reads all cached UIDs from Drift,
  /// then re-fetches them from Firestore. Bypasses staleness check.
  Future<void> refreshAll() async {
    final uids = await _db.fetchAllProfileIds();
    if (uids.isEmpty) return;

    await fetchProfileByIds(uids);
  }

  /// Force-refresh profiles whose cached displayName differs from the
  /// chat row's [memberInfo] snapshot. Catches manual Firestore edits
  /// (e.g. changing `displayName` in `chats/{chatId}/memberInfo/{uid}`
  /// or `users/{uid}`) that would otherwise be invisible until the
  /// staleness window expires.
  ///
  /// Only profiles already present in the cache are compared — missing
  /// profiles are handled by [refreshStaleAndMissing]. This is a cheap
  /// operation when all cached names match: one local SQL read, no
  /// Firestore reads.
  Future<void> refreshOnMismatch({
    required Map<String, MemberInfo> memberInfo,
    required Iterable<String> otherUids,
  }) async {
    final uidSet = otherUids.toSet();
    if (uidSet.isEmpty) return;

    final cached = await _db.fetchProfileByIds(uidSet);
    final cachedByUid = {for (final p in cached) p.uid: p};

    final mismatched = <String>{};
    for (final uid in uidSet) {
      final memberDisplayName = memberInfo[uid]?.displayName;
      if (memberDisplayName == null) continue;
      final cachedProfile = cachedByUid[uid];
      if (cachedProfile == null) {
        continue; // missing → handled by refreshStaleAndMissing
      }
      if (memberDisplayName != cachedProfile.displayName) {
        mismatched.add(uid);
      }
    }

    if (mismatched.isNotEmpty) {
      wLog(
        'memberInfo mismatch for ${mismatched.length} uid(s): $mismatched',
      );
      await fetchProfileByIds(mismatched);
    }
  }

  /// Fetch only display name from Database for showing into message bubble
  Future<String> fetchUserDisplayName({required String uid}) =>
      _db.fetchProfileDisplayName(uid);

  // ----- Helpers ---------------------------
  static UserProfilesCompanion _toCompanion(UserModel u, int fetchedAtMs) =>
      UserProfilesCompanion(
        uid: Value(u.uid),
        displayName: Value(u.displayName),
        photoUrl: Value(u.photoUrl),
        lastSeen: Value(u.lastSeen?.millisecondsSinceEpoch),
        updatedAt: Value(fetchedAtMs),
      );

  /// Splits [list] into chunks of at most [size].
  static List<List<String>> _chunk(List<String> list, int size) {
    final chunks = <List<String>>[];
    for (var i = 0; i < list.length; i += size) {
      final end = (i + size > list.length) ? list.length : i + size;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final userService = ref.read(userServiceProvider);
  final db = ref.read(messageDatabaseProvider);

  return UserProfileRepository(userService: userService, db: db);
});
