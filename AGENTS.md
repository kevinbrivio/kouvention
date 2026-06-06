# AGENTS.md

> Operational guide for AI coding agents working on this Flutter project.
> Read this before touching any chat-related code.
> Source of truth for constraints and architecture: [`docs/chat_scaling_roadmap.md`](docs/chat_scaling_roadmap.md).

---

## 1. TL;DR for the agent

This is a **Flutter mobile chat app** modeled after Kouventa's shared-inbox UI, but operating as a **single-account, single-channel personal chat**. Target scale: **20,000+ chats per user, 500+ messages per chat**. Drift is the local source of truth for the visible UI. Firestore is the remote source of truth, **not** a dataset the app scans. Before changing any chat code, read §3 (constraints), §6 (sync invariant), and §9 (anti-patterns).

---

## 2. Project context

| | |
|---|---|
| App type | Mobile chat app (Flutter, iOS + Android) |
| Auth model | Single-account per device (one logged-in user at a time) |
| Channels | Single channel (direct + group chat); no WhatsApp/IG/FB integration yet |
| Tenant model | Single tenant; no `organizationId` scoping yet |
| AI / agents | None. Do not add. |
| Backend | Firebase (Firestore + Cloud Functions + FCM) |
| Local DB | Drift (SQLite), encrypted with `sqlite3mc` |
| State | Riverpod (`ChangeNotifierProvider`, `StreamProvider`, `StateProvider`) |
| User base | Indonesian market; Bahasa Indonesia is a first-class language |

The project is intentionally **not** cloning the full Kouventa multi-channel system. It proves the mobile chat core first, while leaving room for multi-channel fields later without rewriting the core sync architecture.

---

## 3. Scale target & hard constraints

### Scale target

- 20,000+ chats per user account
- 500+ messages per chat (per roadmap assumption; some chats may have 1,000+)
- Multiple devices per user, with offline-first behavior
- Avoid syncing the full remote archive to the device

### Hard constraints (do not violate)

1. **Reads are bounded by user-visible activity.** Login reads chat metadata only. Messages are read only when a chat is opened, a notification fires, or the user explicitly requests more.
2. **Drift is the local source of truth for visible UI state.** The UI never reads directly from Firestore in the render path.
3. **Firestore is the remote source of truth, not a dataset the app scans.** No "fetch all then filter" patterns.
4. **The device caches message windows, not the full message archive.** Pagination is mandatory.
5. **The Firestore realtime chat listener is limited to the top 20-50 chats** (current code uses 20; the cap is 50).
6. **Writes are idempotent or transaction-guarded.** Retries must not duplicate messages, unread counts, or chat metadata.
7. **Firestore schema is locked** (§5). Do not add new collections, subcollections, or top-level fields without an explicit ADR.

---

## 4. Current architecture map

```
lib/features/chat/
├── models/                          ← data classes (no I/O, no logic)
│   ├── chat_model.dart
│   ├── message_model.dart
│   ├── message_status.dart
│   ├── message_type.dart
│   ├── reply_to_model.dart
│   ├── bubble_color_scheme.dart
│   ├── sticker_model.dart
│   └── upload_result_model.dart
│
├── services/                        ← I/O and external integrations
│   ├── chat_service.dart            ← Firestore reads/writes for chats + messages
│   ├── wallpaper_service.dart
│   ├── sticker_service.dart
│   ├── media/                       ← cloud_media_service, media_picker
│   └── databases/
│       ├── message_database.dart    ← Drift schema, queries, FTS5
│       └── *.g.dart                 ← generated; do not edit by hand
│
├── viewmodel/                       ← Riverpod ChangeNotifiers
│   ├── chat_list_viewmodel.dart     ← global state for the chat list
│   ├── chat_room_viewmodel.dart     ← per-chat state
│   ├── chat_selection_viewmodel.dart
│   ├── chat_profile_viewmodel.dart
│   ├── new_chat_viewmodel.dart
│   ├── new_group_chat_viewmodel.dart
│   ├── recent_users_provider.dart
│   ├── wallpaper_provider.dart
│   ├── bubble_scheme_provider.dart
│   ├── audio_manager.dart
│   └── media/                       ← media_picker_helper, media_preview_viewmodel
│
├── views/                           ← Screens (full pages)
│   ├── chat_list_view.dart
│   ├── chat_room_view.dart
│   ├── chat_profile_view.dart
│   ├── new_chat_view.dart
│   ├── new_group_chat_view.dart
│   ├── group_setup_view.dart
│   └── media_preview_view.dart
│
├── widgets/                         ← Reusable UI components
│   ├── chatList/                    ← chat_list_item, chat_header, skeleton
│   ├── chatRoom/                    ← message_bubble, chat_room_appbar, media_*
│   ├── preview/                     ← image/video/audio/document previews
│   ├── selection_app_bar.dart
│   ├── recent_users_list.dart
│   └── sticker_picker.dart
│
└── utils/
    └── message_label.dart
```

### Data flow (current)

```
Firestore
  ↓ streamChatList(uid, limit: 20)
realtimeChatSyncProvider (lives in MainShell)
  ↓ db.upsertChatRooms()
Drift: Chats table
  ↓ watchChatRooms()  ← UNBOUNDED query, returns every row
localChatListFromStreamProvider
  ↓ maps drift rows → ChatModel
filteredChatListProvider
  ↓ .map() + .where() + .sort() in Dart   ← O(n log n) per emit
ChatListView → ListView.builder
```

This pipeline is the root cause of the 20K-chat crash. See §9.4 and the 7-phase plan in §10.

---

## 5. Firestore schema (locked)

Do not add, rename, or restructure these collections or fields without an ADR.

```
users/{uid}                                    ← auth profile
  displayName, photoUrl, lastSeen, ...

chats/{chatId}                                 ← one per conversation
  type: "direct" | "group"
  members: string[]                            ← array-contains used for queries
  memberInfo: { uid: { displayName, photoUrl } }
  memberHash?: string                          ← sorted UIDs, for direct chats
  groupName?, groupPhotoUrl?
  lastMessage: { text, sentBy, sentAt, type }   ← denormalized preview
  unreadCount: { uid: int }
  typingUsers: string[]
  pinnedBy: string[]
  lastReadAt: { uid: Timestamp }
  createdAt: Timestamp
  updatedAt: Timestamp
  deletedBy: { uid: Timestamp }

chats/{chatId}/messages/{messageId}            ← one per message
  senderId, senderName
  text
  type: "text" | "image" | "video" | "document" | "sticker" | "audio"
  mediaUrls?, mediaCaptions?, mediaGroupId?, mediaDuration?
  mimeType?, fileName?, fileSizeBytes?
  replyToId?, replyToText?, replyToSenderName?, replyToSentAt?,
    replyToMediaUrl?, replyToMediaType?
  isDeleted: bool
  deletedFor: string[]
  sentAt, updatedAt
```

### Compound indexes (`firestore.indexes.json`)

Required for current queries:

- `chats`: `members` (array-contains) + `lastMessage.sentAt` (desc) — for chat list query
- `chats`: `members` (array-contains) + `updatedAt` (desc) — for alternate sort
- `messages`: `chatRoomId` + `sentAt` (desc) — for message history pagination

Add new compound indexes via `firestore.indexes.json` only. Do not add single-field exemptions without a reason in the ADR.

---

## 6. The hard sync invariant

> Message identity is idempotent; all chat metadata side effects must also be idempotent or transaction-guarded; never use `FieldValue.serverTimestamp()` or `FieldValue.increment()` on a retry path without existence-checking first.

### What this means in practice

| Operation | Wrong | Right |
|---|---|---|
| Send a message | Write the message + `lastMessage` + `unreadCount++` in a non-atomic batch | Use a transaction: read `messages/{messageId}` first; if exists, mark local `sent` and skip; else write atomically |
| Update chat timestamp | `updatedAt: FieldValue.serverTimestamp()` inside a retry loop | Set `updatedAt` to the original `sentAt` value (already in the message) on every retry; never re-fetch server time |
| Mark as read | `resetUnreadCount` + `markChatAsRead` as two separate writes | Merge into a single chat update: `{ unreadCount.uid: 0, lastReadAt.uid: now }` |
| Increment unread | `FieldValue.increment(1)` on a retry | Transaction-guarded, keyed on `messageId` existence check |

The "retry" path is critical. The offline-pending flush (§7) WILL retry. Every write on that path must produce the same result whether it runs once or twenty times.

---

## 7. Pending message policy

> Offline/pending messages must use deterministic identity and deterministic side effects.

### The 5 rules

1. Generate `messageId` on the client before inserting into Drift.
2. Generate `sentAt` on the client before inserting into Drift.
3. Insert the local Drift message with `syncStatus = pending`.
4. Use the same `messageId` as the Firestore document ID.
5. Use the same `sentAt` for the Firestore message AND `chat.lastMessage.sentAt`.
6. Retry with the exact same payload.
7. Treat a realtime server echo with the same `messageId` as an acknowledgement.
8. Stop retrying once the local row becomes `sent`.

### The flush path (transaction-guarded)

```dart
Future<void> flushPending(Message msg) async {
  await _firestore.runTransaction((tx) async {
    final ref = _messagesRef(msg.chatId).doc(msg.id);
    final existing = await tx.get(ref);

    if (existing.exists) {
      // Server already has it (our retry, or echo arrived). Mark local sent.
      await db.updateMessageStatus(msg.id, SyncStatus.sent);
      return;
    }

    // Fresh write: message + chat metadata + unread bump in one atomic tx.
    // sentAt is the CLIENT value, never serverTimestamp, to stay deterministic.
    tx.set(ref, {
      ...msg.toMap(),
      'sentAt': msg.sentAt,
      'updatedAt': msg.sentAt,
    });
    tx.update(_chatsRef.doc(msg.chatId), {
      'lastMessage': msg.toLastMessageMap(),
      'updatedAt': msg.sentAt,                    // ← deterministic, not server time
      for (final uid in msg.memberUids)
        if (uid != msg.senderId) 'unreadCount.$uid': FieldValue.increment(1),
    });
  });
}
```

This prevents: duplicate message bubbles, double unread increments, stale retry timestamps, ghost pending rows.

---

## 8. Cursor semantics

> Stop treating one `lastSyncTimestamp` as proof that all older messages are locally complete.

### The 4-field local sync state

Stored in Drift only (not in Firestore). Add to the `Chats` table or a per-chat sync-state table:

| Field | Meaning |
|---|---|
| `latestSeenRemoteAt` | Highest `sentAt` the client has confirmed from the server. |
| `oldestCachedAt` | Lowest `sentAt` present in the local message cache. |
| `hasMoreOlderRemote` | True if the server has messages older than `oldestCachedAt`. |
| `hasLocalGap` | True if a partial range was received and a follow-up fetch is needed. |

### Rules

- Fetch missed newer messages in **pages** until caught up. Do not advance `latestSeenRemoteAt` after only one limited page if more remote messages may exist.
- On chat open: fetch missed newer messages bounded by `latestSeenRemoteAt` and the current remote latest.
- On scroll up: load older local messages first; only fetch a remote older page if `hasMoreOlderRemote` is true AND the local cache is exhausted.
- Persist this state in Drift. Firestore schema stays unchanged.

---

## 9. Anti-patterns (DO NOT)

These are concrete things the agent must not do. Each has a current code:line reference.

### 9.1 Do not mirror 20K chats into Drift

Sorting the in-memory list on every Drift emit blocks the UI thread.

- ❌ `localChatListFromStreamProvider` watching every Drift row via `watchChatRooms()` — `lib/features/chat/services/databases/message_database.dart:325`
- ✅ Replace with paged Drift queries (§14.1). Eviction policy caps local cache at **200 chats** (aggressive, low memory).

### 9.2 Do not keep a global stream listener in `MainShell`

A `Provider` that listens forever defeats `autoDispose` and re-emits on every typing toggle.

- ❌ `ref.watch(realtimeChatSyncProvider)` in `lib/cores/widgets/main_shell.dart:23`
- ✅ Move the first-page stream into a screen-scoped `StreamProvider.autoDispose` (§10.4).

### 9.3 Do not use `lastSyncTimestamp` as the only cursor

A single timestamp lies when intermediate messages are missing, deleted, or partially synced.

- ❌ The legacy `lastSyncTimestamp` column in `lib/features/chat/services/databases/message_database.dart:60` (read-only, slated for v3 removal)
- ✅ Use the 4-field local sync state from §8: `latestSeenRemoteAt`, `oldestCachedAt`, `hasMoreOlderRemote`, `hasLocalGap`. All Phase 1 call sites in `lib/features/shared/services/sync_service.dart` (`syncInitialChatRooms`, `chatToCompanion`, `fetchMissedMessagesBounded`, `streamFirestoreMessages`) and view-model call sites in `chat_list_viewmodel.dart` and `chat_room_viewmodel.dart` now use this state.

### 9.4 Do not sort/filter the chat list in Dart

`.sort()` is O(n log n) on every Drift emit. With 20K chats and 10 emits/min, this is millions of comparisons on the UI thread per minute.

- ❌ `filteredChatListProvider` in `lib/features/chat/viewmodel/chat_list_viewmodel.dart:341-385`
- ✅ Move sort and filter into Drift (SQL) using `select(chats)..orderBy(...)..where(...)`. The provider receives the paged result and passes it to the UI.

### 9.5 Do not use `FieldValue.serverTimestamp()` on a retry path

Server time can drift between retries; ordering breaks and idempotency is lost.

- ❌ Legacy: `'updatedAt': FieldValue.serverTimestamp()` inside the message-send transaction. Old line refs (pre-Phase 1): `lib/features/chat/services/chat_service.dart:163,226,348,361,380,390`. The current send transaction at `chat_service.dart:208-242` uses the **client** `sentAt` and never `serverTimestamp()`.
- ❌ Legacy: `'sentAt': FieldValue.serverTimestamp()` in `lib/features/chat/models/message_model.dart:133-134`. `MessageModel.toNewMessageMap` now writes the client `sentAt` only.
- ✅ Use the client-generated `sentAt` from the pending message (§7). On creation paths where server time is acceptable, document the exception in a comment.
- Remaining `FieldValue.serverTimestamp()` uses (all non-retry paths, all semantically correct):
  - `chat_service.dart:407` — `deleteChat` (`deletedBy.$uid` = "when the user deleted this"; re-tap updates the timestamp, which is the intended behavior).
  - `chat_service.dart:420` — `deleteMessageForMe` (`updatedAt` ordering, not safety-critical).
  - `chat_service.dart:439` — `deleteMessageForEveryone` (same as above).
  - `chat_service.dart:449` — `markChatAsRead` (`lastReadAt.$uid` = "latest time the user read this"; a re-open should advance the timestamp).

### 9.6 Do not use `FieldValue.increment()` without a transaction

A retried batch will double-increment.

- ✅ Done. Both unread bumps (`chat_service.dart:227, 287`) sit inside `runTransaction` blocks that read `messages/{messageId}` first and short-circuit on `existing.exists` (§7). The remaining `FieldValue.increment()` callers (none in `lib/`) would also need a transaction.

### 9.7 Do not stream typing on every keystroke

Every keystroke currently fires a write (`setTyping`). At human typing speed (~5 keys/sec) this is 5 writes/sec/chat, easily amplifying to thousands of writes/day per active chat.

- ✅ Done. `onTextChanged` in `lib/features/chat/viewmodel/chat_room_viewmodel.dart:305-322` coalesces keystrokes via a 2-second trailing-edge `_typingDebounce`, gates the write on a `_isTyping` flag so the burst produces one `setTyping` write, and pairs it with a 10-second `_typingTimer` that calls `clearTyping` on idle. See §14.5. Probation build option to disable typing indicators entirely remains open.
- Old (broken) refs: `lib/features/chat/viewmodel/chat_room_viewmodel.dart:311-316` — superseded.

### 9.8 Do not merge `resetUnreadCount` and `markChatAsRead` into two separate writes

Two writes = two reads on the listener, and on a retry, double-fire is possible.

- ✅ Done. `markChatAsRead` in `lib/features/chat/services/chat_service.dart:447-452` writes both `unreadCount.$uid = 0` and `lastReadAt.$uid = FieldValue.serverTimestamp()` in a single `update()`. There is no separate `resetUnreadCount` method anywhere in the codebase; the only call site is `lib/features/chat/viewmodel/chat_room_viewmodel.dart:125` and it is wrapped in a `try`/`catch` so a transient offline failure does not block chat open.
- Old (broken) refs: `lib/features/chat/viewmodel/chat_room_viewmodel.dart:123-124`, `chat_service.dart:261`, `chat_service.dart:388` — superseded.

### 9.9 Do not read all 1000 messages of a chat on open

`fetchMessages` currently has a fixed `limit: 20` but the API allows unbounded reads.

- ❌ `fetchMessages` in `lib/features/chat/services/chat_service.dart:90-104` if called without `lastSyncTimestamp` (or with a stale one) — pre-Phase 5
- ✅ Phase 5: `chat_service.dart` exposes `fetchOlderMessagesPage` (remote, `startAfter` on `sentAt DESC`); `sync_service.dart` orchestrates it as `fetchOlderMessages`. `chat_room_viewmodel.loadOlderMessages` consults `hasMoreOlderRemote` and falls back to a remote page only when the local cache is exhausted. The latest message window is 50 rows (`watchMessages` limit = 50). Page size 50.

### 9.10 Do not call `db.getChatById` per-row in a paginated batch

`fetchOlderChats` does N sequential SQLite reads per page just to look up `lastSyncTimestamp` — see `lib/features/chat/viewmodel/chat_list_viewmodel.dart:170-178`. With 50 rows per page, that's 50 awaits per scroll event.

- ✅ Use a single `select(chats)..where(id.isIn([...]))` to fetch the existing rows in one SQL call.

---

## 10. The 7-phase implementation order

> Do not reorder. Phases 1 and 2 establish the correctness foundation; everything else is performance.

### Phase 1 — Fix message sync cursor semantics [DONE 2026-06-05]

> **Do this before** any UI pagination work, so the list is not built on broken sync assumptions.

- Add the 4-field local sync state from §8.
- Stop using a single `lastSyncTimestamp` as proof of full sync.
- Fetch missed newer messages in pages until caught up.
- Keep Firestore schema unchanged; store new state in Drift only.

**Completed 2026-06-05:** `lastSyncTimestamp` is no longer read as a cursor anywhere. The
4-field state (`latestSeenRemoteAt`, `oldestCachedAt`, `hasMoreOlderRemote`,
`hasLocalGap`) is the sole cursor in `SyncService.fetchMissedMessagesBounded` and
`SyncService.streamFirestoreMessages`. `SyncService.chatToCompanion` no longer
writes to `lastSyncTimestamp`. Dead `MessageDatabase.updateChatLastSync` deleted;
the `lastSyncTimestamp` column is now read-only and marked for removal in v3.

### Phase 2 — Define pending message conflict resolution [DONE 2026-06-05]

- Apply the policy in §7.
- Make queued sends idempotent.
- Ensure retries do not duplicate messages or corrupt chat metadata.
- Ensure realtime echoes reconcile with pending Drift rows by `messageId`.

**Completed 2026-06-05:** Pending-message policy from §7 is now enforced
end-to-end. `ChatService.sendMessage` and `ChatService.sendMediaMessage`
are transaction-guarded (existence check + atomic write), and the
`SyncService.flushPendingMessage` re-flush path reuses the same
`messageId` + `sentAt` so the transaction is a no-op on the retry.
`SyncService.retryStuckMessages` sweeps the local queue and is fired by
`networkAutoSyncProvider` on both the initial mount and the
offline→online transition. The realtime-echo path (`streamFirestoreMessages`)
upserts echoes with `syncStatus = sent`, so a pending row whose
`messageId` arrives in the live stream is reconciled automatically. The
`getStuckPendingMessages` filter now includes `failed` status.

### Phase 3 — Fix high-frequency and duplicate writes [DONE 2026-06-05]

- Merge `resetUnreadCount` + `markChatAsRead` into one update (§9.8).
- Fix typing writes (§9.7). Consider disabling typing for the cost-sensitive probation build.
- Collapse duplicate chat metadata updates in send paths into one deterministic update map.
- Avoid retrying write batches with non-idempotent increments without a transaction.

**Completed 2026-06-05:** All four items were already satisfied by earlier
work; this phase now documents the line refs in §9.5 / §9.7 / §9.8.

- `markChatAsRead` (`chat_service.dart:447-452`) is a single `update()` that
  writes `unreadCount` and `lastReadAt` together; `resetUnreadCount` does
  not exist. §9.8.
- Typing writes are coalesced in `chat_room_viewmodel.dart:305-322` with
  a 2-second trailing-edge debounce + `_isTyping` guard, paired with a
  10-second `clearTyping` timer. §9.7. The probation-build "disable
  typing" toggle is left open in §16.
- The send-path transactions (`chat_service.dart:208-242`,
  `chat_service.dart:268-308`) collapse message + lastMessage + unread
  bump + `updatedAt` into one `tx.set` and one `tx.update` map. §9.5.
- All `FieldValue.increment()` callers in `lib/` are inside
  `runTransaction` blocks that read `messages/{messageId}` first. §9.6.
- The four remaining `FieldValue.serverTimestamp()` call sites
  (`chat_service.dart:407,420,439,449`) are on non-retry paths and are
  semantically correct (they record "when the user did X" timestamps). §9.5.

### Phase 4 — Add local paged chat list [DONE 2026-06-05]

- Replace the unbounded `watchChatRooms()` (§9.1) with paged Drift queries.
- Move filtering and sorting into SQL (§9.4, §14.1).
- Keep only a visible chat window in provider state.
- Load the next local page only when the user scrolls.
- Keep the Firestore realtime chat listener limited to the top 20-50 chats.
- Cap the local cache at **200 chats** (aggressive, low memory); evict by oldest `updatedAt`.

**Completed 2026-06-05:** Paged Drift queries, screen-scoped listener,
SQL sort/filter, and 200-chat LRU eviction shipped in one pass. The
realtime listener moved out of `MainShell` into
`inboxFirstPageProvider` (StreamProvider.autoDispose, top 50 chats).
The chat list view model uses `pagedChatListRowsProvider` →
`pagedChatListProvider` → `filteredChatListProvider`; Dart sort/filter
is gone. `fetchOlderChats` reads sync state via a single
`getChatsByIds` call (no more N+1 per-row reads, §9.10). LRU eviction
is triggered after every page fetch via `evictOldestChats(keep: 200)`.
The legacy `realtimeChatSyncProvider` watch in `main_shell.dart:23` is
removed.

### Phase 5 — Add remote older-message pagination [DONE 2026-06-05]

- On open: show the latest local message window first.
- Fetch latest remote messages only for that chat if local data is empty or stale.
- On scroll up: load older local messages first.
- If local older messages are exhausted and `hasMoreOlderRemote` is true, fetch one older Firestore page.
- Persist the page to Drift; render from Drift.

**Completed 2026-06-05:** Per-chat older-message pagination shipped end-to-end.

- `ChatService.fetchOlderMessagesPage` (`chat_service.dart:170-201`) is a
  single Firestore `startAfter` query on `sentAt DESC`, then reversed to
  chronological order so the caller can append directly to a local list.
- `SyncService.fetchOlderMessages` (`sync_service.dart:233-301`) is the
  orchestration: reads the 4-field state, exits early if
  `hasMoreOlderRemote == false`, fetches up to `maxPages = 4` pages,
  upserts each, and flips `hasMoreOlderRemote` off the moment the
  server returns a short or empty page.
- `ChatRoomVM.loadOlderMessages` (`chat_room_viewmodel.dart:192-264`) now
  consults `hasMoreOlderRemote` and falls back to a remote page when
  the local cache is short. Pages are **appended** to
  `_loadedOlderMessages` (the previous version overwrote them, losing
  the scroll history). The `_hasMoreMessages` self-overwrite bug is
  fixed.
- The latest local window is bumped from 10 to 50 rows
  (`chatMessagesStreamProvider` in `chat_room_viewmodel.dart:557-561,
  549-553`), matching the AGENTS.md §11.2 budget.
- No Firestore schema change; the 4-field state is still Drift-only.

### Phase 6 — Add sync coordinator and queue [DONE 2026-06-05]

Create one owner for sync behavior so view models do not coordinate remote/local state directly.

Suggested new files:

- `lib/features/chat/services/sync/chat_sync_coordinator.dart`
- `lib/features/chat/services/sync/chat_sync_queue.dart`
- `lib/features/chat/repositories/chat_repository.dart`
- `lib/features/chat/repositories/message_repository.dart`

Responsibilities:

- Login chat metadata sync.
- Active chat message sync.
- Pending message flush and retry.
- Notification-triggered lightweight sync.
- Connectivity resume handling.
- Bounded concurrency for remote operations.

**Completed 2026-06-05:** Four new files added; `ChatListVM` and
`ChatRoomVM` migrated to use the new repositories; `connectivity_viewmodel`
and `notification_handler` route through the coordinator.

- `chat_sync_queue.dart` is a bounded-concurrency FIFO (default 4 in flight)
  with a broadcast `inFlightLabels` stream for observability.
- `chat_sync_coordinator.dart` exposes `onLogin`, `onChatOpened`,
  `onChatClosed`, `onNotificationReceived`, `onNetworkResumed` hooks. Each
  hook enqueues a labelled job on the queue.
- `chat_repository.dart` wraps `ChatService` + `MessageDatabase` for
  chat-list / chat-room I/O. View models no longer touch `ChatService`
  directly.
- `message_repository.dart` wraps `SyncService` + `ChatService` +
  `MessageDatabase` for message-level I/O (read, send, realtime,
  read-receipts, typing).
- `chat_list_viewmodel.dart`: `pinChat`/`unpinChat`/`deleteChat` and
  `fetchOlderChats`/`inboxFirstPageProvider` go through `ChatRepository`.
  The local-Drift `_persistChats` helper is gone.
- `chat_room_viewmodel.dart`: `init()`, `sendMessage`, `sendSticker`,
  `sendMediaMessageDirect`, `loadOlderMessages`, `fetchMessagesAround`,
  typing indicator, and `markChatAsRead` all go through the repositories.
  The `chatMetadataStreamProvider` watches `ChatRepository.watchChat`.
- `connectivity_viewmodel.networkAutoSyncProvider` is now a re-export of
  `networkResumeAutoSyncProvider` from the coordinator. The old
  `Future.microtask` chain that bypassed the queue is removed.
- `notification_handler` foreground handler now calls
  `chatSyncCoordinatorProvider.onNotificationReceived(chatId)` instead
  of `syncService.fetchMessages` directly.
- `ChatService` and `SyncService` remain the I/O layer. View models
  never import them.

### Phase 7 — Add performance fixtures [DONE 2026-06-05]

- Seed or mock 20,000 chats.
- Seed or mock 500 messages per selected test chat.
- Verify login does not sync all messages.
- Verify chat list renders from a bounded local page.
- Verify opening one chat reads only that chat's message page.
- Verify pending offline sends reconcile without duplicates.

**Completed 2026-06-05:** Three test files in `test/`, using a new
`MessageDatabase.forExecutor(NativeDatabase.memory())` test-only
constructor. All 12 tests pass on a desktop test runner.

- `test/chat_list_paging_test.dart` — 3 tests: 250→200 LRU cap, SQL
  sort order (pinned first, then `updated_at DESC, id DESC`), no-op
  eviction when below cap.
- `test/sync_cursor_test.dart` — 5 tests: 4-field cursor writes,
  `recomputeLocalMessageBounds` math, `fetchOlderMessages` ordering,
  `getChatById` null path.
- `test/chat_open_budget_test.dart` — 4 tests with printed timings:
  - 20K chats → 200 cap in 550ms.
  - 500-message chat seeded in 33ms.
  - `watchMessages(limit: 50).first` emits 50 rows in 13ms.
  - `fetchOlderMessages(limit: 50)` returns 50 rows in 1ms.

`recomputeLocalMessageBounds` was also fixed during this phase:
previously it set `hasMoreOlderRemote = count > 0`, which short-circuited
the "first open of an empty chat" case to `false` and hid older
messages from the user. It now always returns `true`; the
`SyncService.fetchOlderMessages` loop is the one that flips the flag
off when the server returns a short or empty page.

---

## 11. Target runtime behavior

These are the exact step sequences the implementation must produce. Use them as acceptance criteria.

### 11.1 Login

1. Show first local chat page from Drift immediately.
2. Start Firestore listener for **only the top 20-50 chats** (top 50 with live updates per locked decision).
3. Fetch one bounded remote chat metadata page.
4. Upsert Drift chat rows.
5. Do not sync messages for all chats.

### 11.2 Open chat

1. Load latest 50-100 local messages from Drift.
2. Fetch missed newer messages for this chat in bounded pages.
3. Attach one realtime listener for the active chat.
4. Load older messages only when the user scrolls.
5. Fetch older remote pages only when local cache is exhausted and `hasMoreOlderRemote` is true.

### 11.3 Send message

1. Generate client `messageId` and `sentAt`.
2. Insert pending Drift row.
3. Flush through the sync queue.
4. Transaction-check message existence before writing side effects.
5. Reconcile realtime echo by `messageId`.

---

## 12. Cost budget

Target per active user session:

| Event | Budget |
|---|---|
| Login | 20-50 chat reads |
| Open chat | 50-100 message reads |
| Scroll older | 50 message reads per page |
| Send message | 1 message write + 1 transaction-guarded chat metadata update |
| Typing | near-zero writes (debounced) |

If a code change is observed to exceed these numbers in a single user action, it is a regression. Surface it.

---

## 13. File index

One-line purpose for every chat file. Keep this in sync when adding files.

### Models (`lib/features/chat/models/`)

| File | Purpose |
|---|---|
| `chat_model.dart` | `ChatModel` + `MemberInfo` + `LastMessage`. Used everywhere a chat is rendered. |
| `message_model.dart` | `MessageModel`. Holds text, media, reply, sync state. Contains `toMap()` and factory `fromMap()`. |
| `message_status.dart` | Enum: pending, sent, delivered, read, failed. |
| `message_type.dart` | Enum: text, image, video, document, sticker, audio. |
| `reply_to_model.dart` | Denormalized reply-to reference. |
| `bubble_color_scheme.dart` | Per-chat bubble theming. |
| `sticker_model.dart` | Sticker asset reference. |
| `upload_result_model.dart` | Result of a media upload (used by the send-media path). |

### Services (`lib/features/chat/services/`)

| File | Purpose |
|---|---|
| `chat_service.dart` | **All** Firestore reads/writes for chats and messages. The only file that should import `cloud_firestore` in the chat feature. |
| `wallpaper_service.dart` | Per-chat wallpaper asset. |
| `sticker_service.dart` | Sticker pack metadata. |
| `databases/message_database.dart` | Drift schema, queries, FTS5, message-window pagination. |
| `databases/message_database.g.dart` | Generated; do not edit. |
| `databases/cached_messages.g.dart` | Generated; do not edit. |
| `media/cloud_media_service.dart` | Cloud upload of media. |
| `media/media_picker_service.dart` | Device gallery picker. |
| `sync/chat_sync_queue.dart` | Bounded-concurrency FIFO queue. Default 4 jobs in flight, broadcast `inFlightLabels` stream. |
| `sync/chat_sync_coordinator.dart` | Single owner of "what needs to sync when". Exposes `onLogin`, `onChatOpened`, `onChatClosed`, `onNotificationReceived`, `onNetworkResumed` hooks. Owns the queue and the two repositories. |

### Repositories (`lib/features/chat/repositories/`)

| File | Purpose |
|---|---|
| `chat_repository.dart` | View-model-facing wrapper over `ChatService` + `MessageDatabase` for chat-list / chat-room I/O (first-page stream, older-page fetch, pin/unpin/delete, get-chat). |
| `message_repository.dart` | View-model-facing wrapper over `SyncService` + `ChatService` + `MessageDatabase` for message-level I/O (read, send, realtime, read-receipts, typing, delete). |

### View models (`lib/features/chat/viewmodel/`)

| File | Purpose |
|---|---|
| `chat_list_viewmodel.dart` | Global state for the chat list: filter, selection, pagination, pin/delete actions. **Highest-priority refactor target.** |
| `chat_room_viewmodel.dart` | Per-chat state: messages, typing, sending, selection. **Second refactor target** (cursor semantics + write coalescing). |
| `chat_selection_viewmodel.dart` | Multi-select mode for chat list. |
| `chat_profile_viewmodel.dart` | Chat detail / settings screen. |
| `new_chat_viewmodel.dart` | New direct chat flow. |
| `new_group_chat_viewmodel.dart` | New group chat flow. |
| `recent_users_provider.dart` | Recently contacted users. |
| `wallpaper_provider.dart` | Wallpaper selection state. |
| `bubble_scheme_provider.dart` | Bubble color scheme state. |
| `audio_manager.dart` | Audio message playback. |
| `media/media_picker_helper.dart` | UI-facing media picker. |
| `media/media_preview_viewmodel.dart` | Media preview state. |

### Views (`lib/features/chat/views/`)

| File | Purpose |
|---|---|
| `chat_list_view.dart` | Main inbox screen. Hosts the scroll listener, filter, and ListView. |
| `chat_room_view.dart` | Single chat screen. |
| `chat_profile_view.dart` | Chat info / settings. |
| `new_chat_view.dart` | New direct chat. |
| `new_group_chat_view.dart` | New group chat. |
| `group_setup_view.dart` | Group details after creation. |
| `media_preview_view.dart` | Full-screen media viewer. |

### Widgets (`lib/features/chat/widgets/`)

| File | Purpose |
|---|---|
| `chatList/chat_list_item.dart` | One row in the chat list. |
| `chatList/chat_header.dart` | Search + filter bar. |
| `chatList/chat_list_skeleton.dart` | Loading skeleton. |
| `chatRoom/message_bubble.dart` | Single message bubble. |
| `chatRoom/chat_room_appbar.dart` / `chat_room_appbar_skeleton.dart` | Chat header. |
| `chatRoom/chat_room_skeleton.dart` | Loading skeleton. |
| `chatRoom/media_bubble.dart` | Media message bubble. |
| `chatRoom/media_sheet.dart` | Media picker sheet. |
| `chatRoom/typing_dots.dart` | Typing indicator animation. |
| `chatRoom/bubble_tail_painter.dart` | CustomPainter for bubble tail. |
| `preview/image_preview.dart`, `video_preview.dart`, `audio_preview.dart`, `document_preview.dart` | Media previews. |
| `selection_app_bar.dart` | Multi-select app bar. |
| `recent_users_list.dart` | Recently contacted users list. |
| `sticker_picker.dart` | Sticker picker sheet. |

### Utils

| File | Purpose |
|---|---|
| `utils/message_label.dart` | Helpers for last-message preview text. |

---

## 14. Code patterns

Reference implementations. Copy-paste-safe as starting points; adapt to the actual repository conventions.

### 14.1 Paged Drift query (replaces the unbounded `watchChatRooms` + Dart sort)

```dart
// in message_database.dart
Stream<List<Chat>> watchPagedChats({
  required int limit,
  int offset = 0,
  Set<String> excludedIds = const {},
}) {
  final query = select(chats)
    ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])
    ..limit(limit, offset: offset);

  if (excludedIds.isNotEmpty) {
    query.where((c) => c.id.isNotIn(excludedIds));
  }
  return query.watch();
}

Future<int> getChatCount() async =>
    (selectOnly(chats)..addColumns([chats.id.count()])).get().then(
          (row) => row.read(chats.id.count()) ?? 0,
        );

Future<void> evictOldestChats({required int keep}) async {
  final count = await getChatCount();
  if (count <= keep) return;
  final toDelete = await (select(chats)
        ..orderBy([(c) => OrderingTerm.asc(c.updatedAt)])
        ..limit(count - keep))
      .get();
  if (toDelete.isEmpty) return;
  await (delete(chats)..where((c) => c.id.isIn(toDelete.map((c) => c.id)))).go();
}
```

### 14.2 Compound cursor for Firestore chat pagination

```dart
// in chat_service.dart
typedef ChatCursor = ({DateTime lastActivityAt, String chatId});

Future<List<ChatModel>> fetchChatRoomsPage({
  required String currentUid,
  required int limit,
  ChatCursor? cursor,
}) async {
  var q = _chatsRef
    .where('members', arrayContains: currentUid)
    .orderBy('lastMessage.sentAt', descending: true)
    .orderBy('__name__', descending: true);  // tie-breaker for stable cursor

  if (cursor != null) {
    q = q.startAfter([
      Timestamp.fromDate(cursor.lastActivityAt),
      cursor.chatId,
    ]);
  }

  final snap = await q.limit(limit).get();
  return snap.docs.map((d) => ChatModel.fromMap(d.id, d.data())).toList();
}
```

### 14.3 Screen-scoped first-page stream (replaces `realtimeChatSyncProvider` in `MainShell`)

```dart
// in chat_list_viewmodel.dart (or a new file)
final inboxFirstPageProvider = StreamProvider.autoDispose
  .<List<ChatModel>>((ref) async* {
  final uid = ref.watch(authServiceProvider).currentUser?.uid;
  if (uid == null) yield const <ChatModel>[];

  // 1. One-shot initial fetch (so the screen has data immediately)
  yield await ref.read(chatServiceProvider).fetchChatRoomsPage(
    currentUid: uid,
    limit: 50,
  );

  // 2. Live updates for ONLY this page
  yield* ref.read(chatServiceProvider)
      .streamChatList(uid, limit: 50);
});
```

### 14.4 Transaction-guarded message flush

See §7 for the full snippet. The contract is:

- Read `messages/{messageId}` first.
- If it exists, mark local `sent` and return (no writes).
- If not, write the message, update `lastMessage`, bump unread, all in one transaction.
- Use the **client** `sentAt` (not `serverTimestamp()`) to keep the operation deterministic across retries.

### 14.5 Debounced typing indicator

```dart
// in chat_room_viewmodel.dart
Timer? _typingDebounce;
static const _typingDebounceWindow = Duration(seconds: 2);

void onTypingChanged(String text) {
  if (text.isEmpty) {
    clearTyping();
    return;
  }
  // Coalesce rapid keystrokes into one write
  _typingDebounce?.cancel();
  _typingDebounce = Timer(_typingDebounceWindow, () {
    _chatService.setTyping(chatId, _currentUid);
  });
}
```

### 14.6 Single `markChatAsRead` write (merges reset + read)

```dart
// in chat_service.dart
Future<void> markChatAsRead(String chatId, String uid) async {
  // One write, two fields. Replaces resetUnreadCount + markChatAsRead.
  await _chatsRef.doc(chatId).update({
    'unreadCount.$uid': 0,
    'lastReadAt.$uid': FieldValue.serverTimestamp(),
  });
}
```

---

## 15. Validation checklist

Before merging any change that touches the chat sync path, verify all of these:

- [ ] Login does not sync all 20,000 chats' messages.
- [ ] Chat list renders from a bounded local page (≤ 200 chats in Drift).
- [ ] Opening one chat reads only that chat's message page (≤ 100 messages initially).
- [ ] Scrolling older loads one Firestore page (≤ 50 reads) at a time.
- [ ] Pending offline sends reconcile without duplicates after retry.
- [ ] A retried `sendMessage` does not double-increment `unreadCount`.
- [ ] A `markChatAsRead` retry does not double-write `lastReadAt`.
- [ ] Typing fires at most one write per ~2 seconds, not per keystroke.
- [ ] Drift sort/filter is in SQL, not in Dart.
- [ ] No `FieldValue.serverTimestamp()` on a retry path.
- [ ] No `FieldValue.increment()` outside a transaction.
- [ ] First-page Firestore listener is `autoDispose` and screen-scoped, not global.
- [ ] `realtimeChatSyncProvider` is no longer referenced from `MainShell`.

### 15.1 Performance fixtures (Phase 7)

- [ ] `test/chat_list_paging_test.dart` — 250 chats in, 200 chats after `evictOldestChats`; SQL order is `pinned_by DESC, updated_at DESC, id DESC`.
- [ ] `test/sync_cursor_test.dart` — 4-field cursor state machine: `updateChatSyncState` writes all four fields, `recomputeLocalMessageBounds` sets `oldestCachedAt` and keeps `hasMoreOlderRemote = true` even with 0 local messages.
- [ ] `test/chat_open_budget_test.dart` — Row-count assertions + printed timings:
  - 20K chats → 200 cap in < 1s on a desktop test runner.
  - 500-message chat → `watchMessages(limit: 50).first` returns exactly 50 rows.
  - 500-message chat → `fetchOlderMessages(limit: 50)` returns 50 rows in single-digit ms.

Run with:
```bash
flutter test test/chat_list_paging_test.dart \
            test/sync_cursor_test.dart \
            test/chat_open_budget_test.dart
```

---

## 16. Open questions / deferred (do not work on these)

These are explicitly **out of scope** for the current scaling effort. Do not start work on them. If a task requires them, flag it and ask.

- **Multi-tenant / `organizationId` scoping** — Deferred. The app is single-account per device.
- **Multi-channel (WhatsApp, Instagram, Facebook)** — Deferred. The Firestore schema will support adding channel fields later, but no integration work is in scope.
- **AI / agent responders** — Not in scope. Do not add LLM, Cloud Function AI pipelines, or confidence-based hand-off.
- **`hasReachedBeginning` field on the `Chats` table** — Already defined in the Drift schema but never read. Wire it up only if it survives the paged-list refactor; otherwise remove it.
- **Postgres / Algolia / Meilisearch migration** — Premature. Drift + Firestore are sufficient to 100K chats.
- **Postgres-style relational queries (assignments, joins, analytics)** — Premature.
- **Cross-region replication** — Not needed at current scale.
- **Schema rename `chats` → `conversations`** — Deferred. Not a perf bottleneck.

---

## 17. How to update this file

This file is the operational contract for AI agents. When modifying it:

1. **Every rule must trace to either `docs/chat_scaling_roadmap.md` or a `file:line` reference in the current repo.** No invented constraints.
2. **When you add a new constraint, link the source.** If the constraint is from a code review, an incident, or a new ADR, link that.
3. **When a phase from §10 is completed, mark it `[DONE yyyy-mm-dd]` and link the PR.** Do not delete completed phases; future agents need the history.
4. **When you add a new file under `lib/features/chat/`, update §13.**
5. **When you add a new anti-pattern, add a row to §9 with a `file:line` reference and a one-line fix.**
6. **When you defer something, add it to §16 with a one-line reason.** If it later becomes in-scope, move it to §3.
7. **The 7-phase order in §10 is not a suggestion.** Reorder only via an ADR in `docs/`.

If a task asks you to violate §3, §6, §7, or §9, stop and ask. The constraints exist because of real production failures (see the 10K-chat crash history).
