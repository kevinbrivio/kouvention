import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/repositories/chat_repository.dart';
import 'package:kouvention/features/chat/repositories/message_repository.dart';
import 'package:kouvention/features/chat/repositories/user_profile_repository.dart';
import 'package:kouvention/features/chat/services/sync/chat_sync_queue.dart';
import 'package:kouvention/features/shared/viewmodel/connectivity_viewmodel.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';

/// Single owner of "what needs to sync when" for the chat feature.
///
/// All chat-related sync decisions (login refresh, chat open, chat
/// close, notification received, network resume) flow through this
/// coordinator. View models and connectivity providers no longer
/// orchestrate remote/local state directly — they call into the
/// coordinator, which enqueues the actual work on a bounded-concurrency
/// [ChatSyncQueue].
///
/// Why a coordinator at all?
///   * Centralizes the policy "what runs when, in what order, with what
///     cap on concurrency" so it's reviewable in one place.
///   * Keeps the I/O layer (`ChatRepository`, `MessageRepository`) free
///     of state machines; they stay thin.
///   * Makes the failure mode obvious: an enqueued job either completes
///     or surfaces a `Completer` error to the caller. There is no
///     "wonder if it ran" — the queue records labels and emits the
///     in-flight set on a broadcast stream.
class ChatSyncCoordinator {
  ChatSyncCoordinator({
    required ChatRepository chatRepository,
    required MessageRepository messageRepository,
    required UserProfileRepository userProfileRepository,
    required SyncService syncService,
    ChatSyncQueue? queue,
  }) : _chatRepository = chatRepository,
       _messageRepository = messageRepository,
       _userProfileRepository = userProfileRepository,
       _syncService = syncService,
       _queue = queue ?? ChatSyncQueue() {
    _queue.inFlightLabels.listen((labels) {
      if (labels.isEmpty) return;
      debugPrint('📡 [ChatSyncCoordinator] in-flight: $labels');
    });
  }

  final ChatRepository _chatRepository;
  final MessageRepository _messageRepository;
  final UserProfileRepository _userProfileRepository;
  final SyncService _syncService;
  final ChatSyncQueue _queue;

  /// Reactive view of the in-flight job labels. Useful for a UI surface
  /// like a small "Syncing N items…" pill.
  Stream<List<String>> get inFlightLabels => _queue.inFlightLabels;

  bool get isIdle => _queue.isIdle;

  // --- Hooks -----------------------------------------

  /// Called once on login. Seeds the first page of the inbox and
  /// flushes any pending messages from a previous session.
  void onLogin(String uid) {
    _queue.enqueue('login:inbox-first-page', () async {
      await _chatRepository.fetchOlderChatsPage(
        uid: uid,
        limit: chatListPageSize,
      );
    });
    _queue.enqueue('login:flush-pending', _flushPending);
  }

  /// Called when a chat screen is opened. Loads missed newer messages
  /// for the chat (bounded pages). The realtime listener subscription
  /// itself is owned by `ChatRoomVM`; this hook is for the one-shot
  /// catch-up.
  void onChatOpened(String chatId) {
    _queue.enqueue(
      'chat-opened:$chatId:catchup',
      () => _messageRepository.fetchMissedMessages(chatId),
    );
  }

  /// Called when a chat screen is closed. Recomputes the local
  /// message-bounds cursor so the next open starts from a known state.
  void onChatClosed(String chatId) {
    _queue.enqueue('chat-closed:$chatId:bounds', () async {
      await _messageRepository.fetchMissedMessages(chatId);
      await _messageRepository.fetchOlderMessages(chatId);
    });
  }

  /// Called when a push notification arrives for a chat. Lightweight:
  /// just `fetchMissedMessages` (no older page fetch). This is what
  /// the notification handler invokes when the user taps a push.
  void onNotificationReceived(String chatId) {
    _queue.enqueue(
      'notif:$chatId:missed',
      () => _messageRepository.fetchMissedMessages(chatId),
    );
  }

  /// Called when the device transitions from offline to online, and
  /// once on initial app boot (no offline→online event yet).
  void onNetworkResumed() {
    _queue.enqueue('net:resume:flush-pending', _flushPending);
    _queue.enqueue(
      'user-profile:flush', () => _userProfileRepository.refreshAll(),
    );
  }

  /// Awaits all currently-pending and in-flight jobs. Used by tests
  /// and graceful shutdown.
  Future<void> drain() => _queue.drain();

  Future<void> close() => _queue.close();

  // --- Internals -------------------------------------

  /// Delegates to [SyncService.retryStuckMessages] through the queue.
  /// The actual retry sweep is owned by SyncService; the coordinator
  /// exists to throttle, dedupe, and add observability around the call.
  Future<void> _flushPending() async {
    debugPrint('📡 [ChatSyncCoordinator] flush-pending requested');
    await _syncService.retryStuckMessages();
  }
}

final chatSyncCoordinatorProvider = Provider<ChatSyncCoordinator>((ref) {
  final coord = ChatSyncCoordinator(
    chatRepository: ref.watch(chatRepositoryProvider),
    messageRepository: ref.watch(messageRepositoryProvider),
    userProfileRepository: ref.watch(userProfileRepositoryProvider),
    syncService: ref.watch(syncServiceProvider),
  );
  ref.onDispose(coord.close);
  return coord;
});

/// Lightweight wrapper that:
///   1. On provider mount: seeds the first page of the inbox and
///      flushes pending messages from a previous session.
///   2. On auth state change to signed-in: same as (1).
///   3. On connectivity change from offline→online: flushes pending
///      messages.
///
/// This replaces the ad-hoc `Future.microtask` chain in the legacy
/// `networkAutoSyncProvider`. The viewmodel/data layer stays out of
/// the connectivity event flow.
final networkResumeAutoSyncProvider = Provider<void>((ref) {
  final coord = ref.watch(chatSyncCoordinatorProvider);

  // Initial mount: trigger the login flow if we already have a user.
  final currentUid = ref.read(authServiceProvider).currentUser?.uid;
  if (currentUid != null) {
    coord.onLogin(currentUid);
  }

  // React to auth state changes.
  ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
    final uid = next.valueOrNull?.uid;
    if (uid != null && prev?.valueOrNull?.uid != uid) {
      coord.onLogin(uid);
    }
  });

  // React to connectivity changes.
  ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
    final isOnline = next.valueOrNull ?? false;
    final wasOnline = prev?.valueOrNull ?? false;
    if (isOnline && !wasOnline) {
      debugPrint('🌍 [ChatSyncCoordinator] network resumed');
      coord.onNetworkResumed();
    }
  });
});
