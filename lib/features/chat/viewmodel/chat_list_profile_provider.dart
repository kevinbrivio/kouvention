import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/repositories/user_profile_repository.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/utils/display_name_resolver.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';

/// Scoped profile stream for the inbox. Derives the visible UID set
/// from [pagedChatListRowsProvider] (the Drift rows the chat list
/// already renders), refreshes stale/missing rows, then yields a
/// Drift watch of those profiles as a `Map<uid, UserProfile>`.
///
/// Re-runs whenever the inbox page changes (new chats loaded, filter
/// changed). The [refreshStaleAndMissing] call is a no-op when every
/// cached row is within the 5-minute staleness window.
///
/// After the staleness check, also force-refreshes any profile whose
/// displayName in the Drift chat row's `memberInfo` differs from the
/// cached profile. This catches manual Firestore edits that would
/// otherwise be invisible until the staleness window expires.
final chatListProfilesProvider =
    StreamProvider.autoDispose<Map<String, UserProfile>>((ref) async* {
  final repo = ref.watch(userProfileRepositoryProvider);
  final inbox =
      ref.watch(pagedChatListRowsProvider).valueOrNull ?? const [];
  final me = ref.watch(currentUidProvider);
  if (me == null) {
    yield const {};
    return;
  }

  final uids = <String>{};
  for (final chat in inbox) {
    uids.addAll(chat.members.where((u) => u != me));
  }

  if (uids.isNotEmpty) {
    await repo.refreshStaleAndMissing(uids);

    // Force-refresh profiles whose memberInfo displayName doesn't
    // match the cached profile. Catches manual Firestore edits.
    for (final chat in inbox) {
      await repo.refreshOnMismatch(
        memberInfo: chat.memberInfo,
        otherUids: chat.members.where((u) => u != me),
      );
    }
  }

  yield* repo
      .watchProfileByIds(uids)
      .map((rows) => {for (final r in rows) r.uid: r});
});

/// Resolver provider for the inbox scope. Wraps the profile map in a
/// [UserProfileResolver] so call sites can do `resolver.lookupDisplayName(uid)`
/// without touching the raw map.
final chatListProfileResolverProvider =
    Provider.autoDispose<UserProfileResolver>((ref) {
  final map = ref.watch(chatListProfilesProvider).valueOrNull ?? const {};
  return UserProfileResolver(map);
});
