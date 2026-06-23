# Chat scaling — build summary (Phases 3, 5, 6, 7)

Build date: 2026-06-05.
Source roadmap: [`docs/chat_scaling_roadmap.md`](chat_scaling_roadmap.md).
Source of truth for constraints: [`AGENTS.md`](../AGENTS.md).

---

## What shipped

- **Phase 3** — High-frequency / duplicate writes: documented line refs for `markChatAsRead` (single-write merge at `chat_service.dart:447-452`), typing debounce (`chat_room_viewmodel.dart:305-322`), transaction-guarded `FieldValue.increment()` (none outside transactions), and the four non-retry `serverTimestamp()` call sites. Cleaned misleading comment at `chat_room_viewmodel.dart:127`.
- **Phase 5** — Remote older-message pagination end-to-end:
  - `chat_service.dart:170-201` — `fetchOlderMessagesPage` (Firestore `startAfter` on `sentAt DESC`, reversed to ASC).
  - `sync_service.dart:233-301` — `fetchOlderMessages` orchestrator: bounded `maxPages=4`, flips `hasMoreOlderRemote` off on short/empty page, returns a typed result.
  - `chat_room_viewmodel.dart:192-264` — `loadOlderMessages` now consults the 4-field state, **appends** pages to `_loadedOlderMessages` (was overwriting), fixed `_hasMoreMessages` self-overwrite bug.
  - `chat_room_viewmodel.dart:549-561` — `watchMessages` / `watchMessagesAround` limit bumped 10 → 50.
- **Phase 6** — Sync coordinator + repositories. Four new files; `ChatListVM` and `ChatRoomVM` migrated to use them; no view model imports `ChatService` or `SyncService` directly anymore.
  - `repositories/chat_repository.dart` — `ChatRepository` + provider. Exposes `watchChat`, `getChat`, `firstPageStream`, `fetchOlderChatsPage`, pin/unpin/delete. Preserves per-row `latestSeenRemoteAt`.
  - `repositories/message_repository.dart` — `MessageRepository` + provider. Exposes read window, fetch missed / older / around, realtime subscription, send (text/sticker/media), mark-as-read, typing, delete.
  - `services/sync/chat_sync_queue.dart` — Bounded-concurrency FIFO (default 4 in flight) with broadcast `inFlightLabels` stream and `drain()`.
  - `services/sync/chat_sync_coordinator.dart` — `ChatSyncCoordinator` + provider + `networkResumeAutoSyncProvider`. Hooks: `onLogin`, `onChatOpened`, `onChatClosed`, `onNotificationReceived`, `onNetworkResumed`.
  - `shared/viewmodel/connectivity_viewmodel.dart` — re-exports `networkResumeAutoSyncProvider` as `networkAutoSyncProvider` (backward-compatible with `main.dart:182`).
  - `notification/services/notification_handler.dart` — foreground sync routes through `chatSyncCoordinatorProvider.onNotificationReceived(chatId)`.
- **Phase 7** — Performance fixtures.
  - `message_database.dart` — added `MessageDatabase.forExecutor(QueryExecutor)` `@visibleForTesting` constructor; fixed `recomputeLocalMessageBounds` so it always returns `hasMoreOlderRemote: true` (the fetch loop is the verdict, not the recompute function).
  - `test/chat_list_paging_test.dart` (3 tests) — LRU cap of 200, SQL sort order (pinned first → `updated_at DESC, id DESC`), no-op eviction below cap.
  - `test/sync_cursor_test.dart` (5 tests) — 4-field cursor writes, `recomputeLocalMessageBounds` math, local `fetchOlderMessages` ordering, `getChatById` null path.
  - `test/chat_open_budget_test.dart` (4 tests) — 250-chat and 20K-chat LRU caps, 500-message open budget (`watchMessages` first emit ≤ 50 rows DESC), older-page fetch (50 rows DESC strictly older than cursor). Seeds are inlined; no separate `integration_test/` directory.
  - `AGENTS.md` §15.1 — validation checklist for the three test files; §10 Phase 7 marked `[DONE 2026-06-05]`.

## Verification

- `flutter test test/chat_list_paging_test.dart test/sync_cursor_test.dart test/chat_open_budget_test.dart` — **12/12 pass**.
- `flutter analyze` — **0 errors**, 3 pre-existing unused-field warnings (`new_chat_viewmodel.dart:28`, `new_group_chat_viewmodel.dart:28`, `search_overlay.dart:25`).
- Phase 7 timings on the desktop runner (printed by the test):
  - 20K chats seeded + 200-cap eviction: **550ms**
  - 500-message chat seeded: **33ms**
  - `watchMessages(limit: 50).first` emit: **13ms**
  - `fetchOlderMessages(limit: 50)`: **1ms**

## Key design decisions

- **View models no longer touch I/O services directly.** `ChatListVM` and `ChatRoomVM` import only the two repositories. `ChatService` and `SyncService` are the I/O layer, hidden from the UI.
- **`MessageRepository` deliberately wraps both `SyncService` and `ChatService`.** Sync handles writes (transaction-guarded), Chat handles typing + read-receipts. The repository is the single import surface.
- **`networkAutoSyncProvider` kept as a re-export.** `main.dart:182` still wires it; the implementation is now the coordinator's `networkResumeAutoSyncProvider`. The old `Future.microtask` chain is gone.
- **`recomputeLocalMessageBounds` always returns `hasMoreOlderRemote: true`.** The previous `count > 0` short-circuited the empty-chat case to `false` and hid older messages forever. The fetch loop is the only place that flips the flag to `false`.
- **Tests live in `test/`, not `integration_test/`.** The build host has no connected device; the in-memory `MessageDatabase` makes the fixtures deterministic without one. Migration to a device suite is trivial later by adding an `integration_test/` runner that imports the same seed helpers.

## Constraints respected

- No `FieldValue.serverTimestamp()` on retry paths; all four remaining call sites are on non-retry paths and are semantically correct.
- No `FieldValue.increment()` outside a transaction.
- Drift sort/filter still in SQL; no Dart `.sort()` on chat lists.
- Realtime listener still `autoDispose`, still screen-scoped, still top 50.
- `realtimeChatSyncProvider` is gone from `MainShell`.

## Open follow-ups (not in scope this build)

- `SyncService.syncInitialChatRooms` is dead code (no callers in `lib/`). Safe to delete; left in to keep the diff small.
- §16 probation-build "disable typing" toggle still open.
- `ChatService.fetchMessages` parameter `lastSyncTimestamp` could be renamed to `sinceSentAt` for clarity (callers already use the 4-field state).
- `MessageDatabase.forExecutor` could move to a dedicated test-only factory file if the production class grows further.

## Files touched this build

- `lib/features/chat/services/chat_service.dart` — added `fetchOlderMessagesPage`.
- `lib/features/shared/services/sync_service.dart` — added `fetchOlderMessages`.
- `lib/features/chat/services/databases/message_database.dart` — `recomputeLocalMessageBounds` fix, `forExecutor` test constructor.
- `lib/features/chat/repositories/chat_repository.dart` — **new**.
- `lib/features/chat/repositories/message_repository.dart` — **new**.
- `lib/features/chat/services/sync/chat_sync_queue.dart` — **new**.
- `lib/features/chat/services/sync/chat_sync_coordinator.dart` — **new**.
- `lib/features/chat/viewmodel/chat_list_viewmodel.dart` — migrated to `ChatRepository`.
- `lib/features/chat/viewmodel/chat_room_viewmodel.dart` — migrated to both repositories; `loadOlderMessages` rewrite; limit bumps.
- `lib/features/shared/viewmodel/connectivity_viewmodel.dart` — re-exports coordinator provider.
- `lib/features/notification/services/notification_handler.dart` — foreground sync via coordinator.
- `test/chat_list_paging_test.dart` — **new**.
- `test/sync_cursor_test.dart` — **new**.
- `test/chat_open_budget_test.dart` — **new**.
- `AGENTS.md` — §9.5/§9.7/§9.8/§9.9 updated, §10 Phases 5/6/7 marked `[DONE 2026-06-05]`, §13 file index updated, §15.1 performance checklist added.
