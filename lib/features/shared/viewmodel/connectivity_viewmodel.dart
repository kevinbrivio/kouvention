import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/services/sync/chat_sync_coordinator.dart';
import 'package:kouvention/features/shared/services/connectivity_service.dart';
import 'package:kouvention/features/story/services/story_sync_coordinator.dart';

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

final connectivityProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

/// Touching this provider (e.g. via `ref.listen` in `main.dart`) wires
/// login-flush + network-resume-flush into the app lifecycle.
final networkAutoSyncProvider = Provider<void>((ref) {
  ref.watch(networkResumeAutoSyncProvider);

  final storyCoordinator = ref.watch(storySyncCoordinatorProvider);
  final currentUid = ref.read(authServiceProvider).currentUser?.uid;
  if (currentUid != null) {
    unawaited(storyCoordinator.flushPending());
  }

  ref.listen(authStateProvider, (prev, next) {
    final uid = next.valueOrNull?.uid;
    if (uid != null && prev?.valueOrNull?.uid != uid) {
      unawaited(storyCoordinator.flushPending());
    }
  });

  ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
    final isOnline = next.valueOrNull ?? false;
    final wasOnline = prev?.valueOrNull ?? false;
    if (isOnline && !wasOnline) {
      unawaited(storyCoordinator.flushPending());
    }
  });
});
