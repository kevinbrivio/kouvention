# Chat Scaling Roadmap

This roadmap keeps the current Firestore collection design unchanged and focuses on sync behavior, local caching, pagination, and cost control.

## Scale Target

- Support 20,000+ chats for one account.
- Assume each chat can contain roughly 500+ messages.
- Avoid syncing the full remote archive to the device.
- Keep Firestore reads and writes bounded by user-visible activity.

## Current Firestore Design

Keep the existing collection structure:

- `users/{uid}`
- `chats/{chatId}`
- `chats/{chatId}/messages/{messageId}`

Do not add a multi-channel read model yet. The project should first prove that the single-channel mobile chat core is stable, bounded, and cost-aware.

## Core Sync Rule

- Login syncs chat metadata only.
- Messages sync only when a chat is opened, receives a notification, or is explicitly requested.
- Drift is the mobile source of truth for visible UI state.
- Firestore is the remote source of truth, not a dataset the app scans.
- The device caches message windows, not the full message archive.

## Hard Sync Invariant

Message identity is idempotent; all chat metadata side effects must also be idempotent or transaction-guarded; never use `FieldValue.serverTimestamp()` or `FieldValue.increment()` on a retry path without existence-checking first.

## Pending Message Conflict Policy

Offline/pending messages must use deterministic identity and deterministic side effects.

- Generate `messageId` on the client before inserting into Drift.
- Generate `sentAt` on the client before inserting into Drift.
- Insert the local Drift message with `syncStatus = pending`.
- Use the same `messageId` as the Firestore document ID.
- Use the same `sentAt` for the Firestore message and `chat.lastMessage.sentAt`.
- Retry with the exact same payload.
- Treat a realtime server echo with the same `messageId` as an acknowledgement.
- Stop retrying once the local row becomes `sent`.

The flush path should use a transaction:

1. Read `chats/{chatId}/messages/{messageId}`.
2. If it already exists, mark the local pending row as sent and skip side effects.
3. If it does not exist, write the message, update `lastMessage`, and increment unread counts.

This prevents duplicate message bubbles, double unread increments, stale retry timestamps, and ghost pending rows.

## Revised Implementation Order

### 1. Fix Message Sync Cursor Semantics

Do this before UI pagination so the list is not built on broken sync assumptions.

- Stop treating one `lastSyncTimestamp` as proof that all older messages are locally complete.
- Track separate local sync state:
  - `latestSeenRemoteAt`
  - `oldestCachedAt`
  - `hasMoreOlderRemote`
  - `hasLocalGap`
- Fetch missed newer messages in pages until caught up.
- Do not advance the newest cursor after only one limited page if more remote messages may exist.
- Keep Firestore schema unchanged; store this state in Drift only.

### 2. Define Pending Message Conflict Resolution

- Apply the pending message policy above.
- Make queued sends idempotent.
- Ensure retries do not duplicate messages or corrupt chat metadata.
- Ensure realtime echoes reconcile with pending Drift rows by `messageId`.

### 3. Fix High-Frequency And Duplicate Writes

- Merge `resetUnreadCount` and `markChatAsRead` into one chat update.
- Fix typing indicator writes so typing does not write repeatedly on every keystroke.
- Consider disabling typing indicators for probation if cost/stability is the priority.
- Collapse duplicated chat metadata updates in send paths into one deterministic update map.
- Avoid retrying write batches that contain non-idempotent increments without a transaction.

### 4. Add Local Paged Chat List

- Replace unbounded local chat watching with paged Drift queries.
- Move filtering and sorting into SQL instead of Dart list transforms.
- Keep only a visible chat window in provider state.
- Load the next local page only when the user scrolls.
- Keep the Firestore realtime chat listener limited to the top 20-50 chats.

### 5. Add Remote Older-Message Pagination

- When opening a chat, show the latest local message window first.
- Fetch latest remote messages only for that chat if local data is empty or stale.
- On scroll up, load older local messages first.
- If local older messages are exhausted and `hasMoreOlderRemote` is true, fetch one older Firestore page.
- Persist the page to Drift and render from Drift.

### 6. Add Sync Coordinator And Queue

Create one owner for sync behavior so view models do not coordinate remote/local state directly.

Suggested files:

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

### 7. Add Performance Fixtures

- Seed or mock 20,000 chats.
- Seed or mock 500 messages per selected test chat.
- Verify login does not sync all messages.
- Verify chat list renders from a bounded local page.
- Verify opening one chat reads only that chat's message page.
- Verify pending offline sends reconcile without duplicates.

## Target Runtime Behavior

### Login

1. Show first local chat page from Drift immediately.
2. Start Firestore listener for only the top 20-50 chats.
3. Fetch one bounded remote chat metadata page.
4. Upsert Drift chat rows.
5. Do not sync messages for all chats.

### Open Chat

1. Load latest 50-100 local messages from Drift.
2. Fetch missed newer messages for this chat in bounded pages.
3. Attach one realtime listener for the active chat.
4. Load older messages only when the user scrolls.
5. Fetch older remote pages only when local cache is exhausted.

### Send Message

1. Generate client `messageId` and `sentAt`.
2. Insert pending Drift row.
3. Flush through the sync queue.
4. Transaction-check message existence before writing side effects.
5. Reconcile realtime echo by `messageId`.

## Cost Budget

Target per active user session:

- Login: 20-50 chat reads.
- Open chat: 50-100 message reads.
- Scroll older: 50 message reads per page.
- Send message: one message write plus one transaction-guarded chat metadata update.
- Typing: near-zero writes.

## Probation Positioning

The project intentionally does not clone the full Kouventa multi-channel system yet. It proves the mobile chat core first:

- Current Firestore schema is preserved.
- Reads are bounded.
- Writes are idempotent or transaction-guarded.
- Drift handles local-first UI state.
- The data model can later support multi-channel fields without rewriting the core sync architecture.
