# LRU Eviction for Local Chat Cache

## Decision

Replace the `updated_at`-based eviction order with a **true LRU eviction** using a dedicated `lastOpenedAt` column. The cap is raised from 200 to 500.

## Context

The chat list LRU eviction (`evictOldestChats`) was using `updated_at ASC` to decide which chats to delete when the local cache exceeded the cap. Problem: `updated_at` is polluted by system actions — `deleteMessageForMe`, `markChatAsRead`, `sendMessage` retries — that have nothing to do with user interest. This caused:

1. **Wrong eviction targets.** A chat the user has never opened but recently received a message was evicted ahead of a chat the user opened months ago but had a recent system-side `updated_at`.  
2. **Hardcoded cap.** `evictOldestChats(keep: 200)` ignored the `kChatListMaxCached` constant.  
3. **Cap conflated with UI window.** The test value (`kChatListMaxCached = 25`) was too low for production, and the production constant (`200`) was never actually wired to the eviction call.

## Design

### 1. New column: `lastOpenedAt`

- `IntColumn` in the `Chats` table (milliseconds since epoch).  
- Default: `0` (never opened).  
- Written only by `ChatRoomVM.init()` when the user opens a chat room.  
- NOT written by scroll position, read receipts, typing, or any other system action.

### 2. Eviction sort order

```
ORDER BY
  last_opened_at ASC,                  -- never-opened FIRST
  COALESCE(json_extract(last_message, '$.sentAt'), created_at) ASC,
  id ASC
```

| Key | Why |
|---|---|
| `last_opened_at ASC` | Primary LRU key. Opened chats are protected; never-opened chats are eviction candidates. |
| `COALESCE(json_extract(...), created_at) ASC` | Secondary key. Within the never-opened group, chats with no recent message activity are evicted first. Falls back to `created_at` when `lastMessage` is null. |
| `id ASC` | Stable tie-breaker. |

### 3. Viewport protection (`excludeIds`)

`evictOldestChats` accepts an optional `excludeIds` set. Chats in this set are never evicted, even if they rank lowest by the LRU order. This protects chats currently visible in the user's viewport during pagination.

The viewport set is tracked by a **debounced scroll listener** (`_ChatListViewState`, 250ms trailing edge) that writes the visible chat IDs to `visibleChatIdsProvider` (a `StateProvider`). The VM reads this provider when calling `fetchOlderChatsPage` and passes the IDs to the repository and then to the eviction call.

### 4. Schema migration (v2 → v3)

- Adds the `lastOpenedAt` column.  
- Backfills from `COALESCE(updated_at, created_at)` — an imperfect approximation (updated_at is polluted) but acceptable for a one-time migration. After migration, only `ChatRoomVM.init()` writes to this column.

### 5. Cap raised to 500

`kChatListMaxCached = 500` (from 200). The user can override this to 500 via the global constant. The 500-cap balances memory (~1 MB for 500 chat summaries) against the risk of evicting chats the user is actively scrolling through.

## Files changed

| File | Change |
|---|---|
| `lib/features/chat/services/databases/message_database.dart` | Added `lastOpenedAt` column, bumped schema v2→v3, new eviction query, `updateLastOpenedAt` method |
| `lib/features/chat/repositories/chat_repository.dart` | `fetchOlderChatsPage` accepts `excludeIds`, passes to eviction; `keep:200`→`kChatListMaxCached` |
| `lib/features/chat/viewmodel/chat_list_viewmodel.dart` | Added `visibleChatIdsProvider`; `fetchOlderChats` reads visible IDs and passes to repository |
| `lib/features/chat/views/chat_list_view.dart` | Debounced scroll listener tracks visible chat IDs |
| `lib/features/chat/viewmodel/chat_room_viewmodel.dart` | Calls `updateLastOpenedAt` on chat open |
| `test/chat_list_paging_test.dart` | Updated for cap=500 |
| `test/chat_open_budget_test.dart` | Uses `kChatListMaxCached` instead of hardcoded 200 |
| `docs/lru_eviction_local_cache_design.md` | This document |

## Consequences

### Positive

- Eviction now reflects actual user interest (opened chats survive, never-opened chats are candidates).  
- System-side `updated_at` pollution no longer distorts eviction.  
- Viewport protection prevents visible chats from disappearing during pagination.  
- Cap is a single source of truth via `kChatListMaxCached`.  

### Negative

- One-migration overhead (v2 → v3) for existing users.  
- `lastOpenedAt` is set only on explicit chat-room open, not on scroll past in the list. The viewport protection (`excludeIds`) fills this gap for the visible window.  
- Never-opened chats are fair game for eviction even if they appear in the top 50 Firestore feed — acceptable because the top 50 are the most recently active, and their `sentAt` values keep them above the eviction threshold in practice.

### Risks

- Scroll-based `excludeIds` uses estimated item heights (`_listItemHeight = 80.0px`). If chat list items vary significantly in height, the estimate may be off by 1-2 items. The 250ms debounce and the fact that `excludeIds` is a safety net (not the primary eviction mechanism) make this acceptable.
