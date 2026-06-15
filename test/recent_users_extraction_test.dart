import 'package:flutter_test/flutter_test.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/viewmodel/recent_users_provider.dart';

/// Pure-logic tests for [extractRecentUids].
///
/// The recent users list reads up to 20 chats from Drift, then maps each
/// chat to a single UID to look up:
///   * direct chats: `otherMemberUid(currentUid)`
///   * group chats:  `lastMessage.sentBy` (skip null/empty, skip self)
///
/// These tests pin that contract. The provider wires Drift + Firestore
/// around it; the resolver is the only place where the extraction
/// semantics live, so all the rules are testable in isolation.
void main() {
  const me = 'me';

  ChatModel _direct({
    required String id,
    required String otherUid,
    DateTime? updatedAt,
  }) {
    final updated = updatedAt ?? DateTime(2026, 1, 1);
    return ChatModel(
      id: id,
      type: 'direct',
      members: [me, otherUid],
      memberInfo: {
        me: const MemberInfo(displayName: 'Me'),
        otherUid: MemberInfo(displayName: 'User $otherUid'),
      },
      pinnedBy: const [],
      createdAt: updated,
      updatedAt: updated,
    );
  }

  ChatModel _group({
    required String id,
    required List<String> members,
    String? lastSentBy,
    DateTime? lastSentAt,
    DateTime? updatedAt,
  }) {
    final updated = updatedAt ?? DateTime(2026, 1, 1);
    return ChatModel(
      id: id,
      type: 'group',
      members: members,
      memberInfo: {
        for (final m in members) m: MemberInfo(displayName: 'User $m'),
      },
      pinnedBy: const [],
      createdAt: updated,
      updatedAt: updated,
      lastMessage: (lastSentBy != null && lastSentAt != null)
          ? LastMessage(text: 'hi', sentBy: lastSentBy, sentAt: lastSentAt)
          : null,
    );
  }

  group('extractRecentUids — direct chats', () {
    test('returns the other member uid from a direct chat', () {
      final chats = [_direct(id: 'c1', otherUid: 'alice')];

      final result = extractRecentUids(chats: chats, currentUid: me);

      expect(result, ['alice']);
    });

    test('preserves input order (recency)', () {
      final chats = [
        _direct(id: 'c1', otherUid: 'alice', updatedAt: DateTime(2026, 1, 3)),
        _direct(id: 'c2', otherUid: 'bob', updatedAt: DateTime(2026, 1, 2)),
        _direct(id: 'c3', otherUid: 'carol', updatedAt: DateTime(2026, 1, 1)),
      ];

      final result = extractRecentUids(chats: chats, currentUid: me);

      expect(result, ['alice', 'bob', 'carol']);
    });

    test('deduplicates when the same uid appears in multiple chats', () {
      final chats = [
        _direct(id: 'c1', otherUid: 'alice'),
        _direct(id: 'c2', otherUid: 'bob'),
        _direct(id: 'c3', otherUid: 'alice'), // duplicate
      ];

      final result = extractRecentUids(chats: chats, currentUid: me);

      expect(result, ['alice', 'bob']);
    });
  });

  group('extractRecentUids — group chats', () {
    test('uses lastMessage.sentBy for a group chat', () {
      final chats = [
        _group(
          id: 'g1',
          members: const [me, 'alice', 'bob', 'carol'],
          lastSentBy: 'bob',
          lastSentAt: DateTime(2026, 1, 1),
        ),
      ];

      final result = extractRecentUids(chats: chats, currentUid: me);

      expect(result, ['bob']);
    });

    test('skips group chats where lastMessage is null', () {
      final chats = [
        _group(
          id: 'g1',
          members: const [me, 'alice', 'bob'],
          // lastMessage intentionally null
        ),
      ];

      final result = extractRecentUids(chats: chats, currentUid: me);

      expect(result, isEmpty);
    });

    test('skips group chats where sentBy is the current user', () {
      final chats = [
        _group(
          id: 'g1',
          members: const [me, 'alice', 'bob'],
          lastSentBy: me, // I sent the last message
          lastSentAt: DateTime(2026, 1, 1),
        ),
      ];

      final result = extractRecentUids(chats: chats, currentUid: me);

      expect(result, isEmpty);
    });

    test('skips group chats where sentBy is empty string', () {
      final chats = [
        _group(
          id: 'g1',
          members: const [me, 'alice', 'bob'],
          lastSentBy: '',
          lastSentAt: DateTime(2026, 1, 1),
        ),
      ];

      final result = extractRecentUids(chats: chats, currentUid: me);

      expect(result, isEmpty);
    });
  });

  group('extractRecentUids — mixed and bounded', () {
    test('handles a mix of direct and group chats', () {
      final chats = [
        _direct(id: 'c1', otherUid: 'alice', updatedAt: DateTime(2026, 1, 5)),
        _group(
          id: 'g1',
          members: const [me, 'alice', 'bob'],
          lastSentBy: 'bob',
          lastSentAt: DateTime(2026, 1, 4),
          updatedAt: DateTime(2026, 1, 4),
        ),
        _direct(id: 'c2', otherUid: 'carol', updatedAt: DateTime(2026, 1, 3)),
        _group(
          id: 'g2',
          members: const [me, 'alice', 'dave'],
          lastSentBy: 'dave',
          lastSentAt: DateTime(2026, 1, 2),
          updatedAt: DateTime(2026, 1, 2),
        ),
      ];

      final result = extractRecentUids(chats: chats, currentUid: me);

      expect(
        result,
        ['alice', 'bob', 'carol', 'dave'],
        reason: 'order follows input (which is recency DESC); dedupe by uid',
      );
    });

    test('caps the result at the default limit of 20', () {
      final chats = [
        for (var i = 0; i < 30; i++)
          _direct(id: 'c$i', otherUid: 'u$i'),
      ];

      final result = extractRecentUids(chats: chats, currentUid: me);

      expect(result.length, 20);
    });

    test('respects a custom limit', () {
      final chats = [
        for (var i = 0; i < 10; i++) _direct(id: 'c$i', otherUid: 'u$i'),
      ];

      final result = extractRecentUids(
        chats: chats,
        currentUid: me,
        limit: 3,
      );

      expect(result, ['u0', 'u1', 'u2']);
    });

    test('returns empty when chat list is empty', () {
      final result = extractRecentUids(chats: const [], currentUid: me);

      expect(result, isEmpty);
    });

    test('silently skips a direct chat with fewer than 2 members (defensive)',
        () {
      // Edge case: a direct chat with only one member (just `me`) is
      // malformed — otherMemberUid() would assert on firstWhere. The
      // resolver pre-filters these so the New Chat screen never crashes
      // on a corrupted Drift row.
      final chats = [
        ChatModel(
          id: 'self',
          type: 'direct',
          members: const [me], // only me — malformed
          memberInfo: const {me: MemberInfo(displayName: 'Me')},
          pinnedBy: const [],
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

      final result = extractRecentUids(chats: chats, currentUid: me);

      expect(result, isEmpty,
          reason: 'malformed direct chat is silently skipped, not thrown');
    });

    test('silently skips a direct chat where currentUid is not a member',
        () {
      // Defensive: if the current user is missing from the members list,
      // otherMemberUid() would return the first other member (wrong).
      // The resolver pre-filters these rows.
      final chats = [
        ChatModel(
          id: 'orphan',
          type: 'direct',
          members: const ['alice', 'bob'], // me is missing
          memberInfo: const {
            'alice': MemberInfo(displayName: 'Alice'),
            'bob': MemberInfo(displayName: 'Bob'),
          },
          pinnedBy: const [],
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

      final result = extractRecentUids(chats: chats, currentUid: me);

      expect(result, isEmpty,
          reason: 'chat where current user is not a member is skipped');
    });
  });
}
