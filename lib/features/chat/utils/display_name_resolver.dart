import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';

/// Pure-data wrapper around the cached profile map. Lookups return null
class UserProfileResolver {
  final Map<String, UserProfile> _profiles;

  const UserProfileResolver(this._profiles);

  String? lookupDisplayName(String uid) => _profiles[uid]?.displayName;
  String? lookupPhotoUrl(String uid) => _profiles[uid]?.photoUrl;
}

/// Resolves the display name for a chat. Tries the fresh Drift cache
/// first (via [resolver]); falls back to the locked `memberInfo` field
/// on the chat row when the cache has no entry (cold start, evicted
/// row, or offline before first fetch).
String resolveDisplayName({
  required ChatModel chat,
  required String currentUid,
  required UserProfileResolver resolver,
}) {
  if (!chat.isDirect) return chat.displayName(currentUid);

  final otherUid = chat.otherMemberUid(currentUid);
  final fresh = resolver.lookupDisplayName(otherUid);
  if (fresh != null) return fresh;

  return chat.displayName(currentUid);
}

/// Same as [resolveDisplayName] but for photo URLs.
String? resolveDisplayPhotoUrl({
  required ChatModel chat,
  required String currentUid,
  required UserProfileResolver resolver,
}) {
  if (!chat.isDirect) return chat.displayPhotoUrl(currentUid);

  final otherUid = chat.otherMemberUid(currentUid);
  final fresh = resolver.lookupPhotoUrl(otherUid);
  if (fresh != null) return fresh;

  return chat.displayPhotoUrl(currentUid);
}
