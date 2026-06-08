import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/services/sync/chat_sync_coordinator.dart';
import 'package:kouvention/features/shared/services/connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

final connectivityProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

/// Re-export of [networkResumeAutoSyncProvider] from the chat sync
/// coordinator. Touching this provider (e.g. via `ref.listen` in
/// `main.dart`) wires login-flush + network-resume-flush into the
/// app lifecycle. See [chat_sync_coordinator.dart] for the full
/// implementation.
final networkAutoSyncProvider = networkResumeAutoSyncProvider;
