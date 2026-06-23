import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/repositories/user_profile_repository.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/utils/display_name_resolver.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart'
    show chatMetadataStreamProvider;

/// Scoped profile stream for a single chat room. Derives the visible
/// UID set from [chatMetadataStreamProvider] (the Firestore-backed
/// chat model the room already watches), refreshes stale/missing
/// rows, then yields a Drift watch of those profiles.
///
/// Re-runs when the chat metadata changes (member list updated, etc).
/// After the staleness check, also force-refreshes any profile whose
/// displayName in the Firestore chat row's `memberInfo` differs from
/// the cached profile.
final chatRoomProfilesProvider = StreamProvider.autoDispose
    .family<Map<String, UserProfile>, String>((ref, chatId) async* {
  final repo = ref.watch(userProfileRepositoryProvider);
  final chat = ref.watch(chatMetadataStreamProvider(chatId)).valueOrNull;
  final me = ref.watch(currentUidProvider);

  if (chat == null || me == null) {
    yield const {};
    return;
  }

  final uids = chat.members.where((u) => u != me).toSet();

  if (uids.isNotEmpty) {
    await repo.refreshStaleAndMissing(uids);

    // Force-refresh profiles whose memberInfo displayName doesn't
    // match the cached profile. Catches manual Firestore edits.
    await repo.refreshOnMismatch(
      memberInfo: chat.memberInfo,
      otherUids: uids,
    );
  }

  yield* repo
      .watchProfileByIds(uids)
      .map((rows) => {for (final r in rows) r.uid: r});
});

/// Resolver provider for a single chat room scope.
final chatRoomProfileResolverProvider = Provider.autoDispose
    .family<UserProfileResolver, String>((ref, chatId) {
  final map =
      ref.watch(chatRoomProfilesProvider(chatId)).valueOrNull ?? const {};
  return UserProfileResolver(map);
});
