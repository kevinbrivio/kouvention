import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/shared/services/connectivity_service.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

final connectivityProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

final networkAutoSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
    
    final isOnline = next.value ?? false;
    final wasOnline = previous?.value ?? false;

    if (isOnline && !wasOnline) {
      debugPrint('🌍 [INTERNET Going online!]');
      
      final currentUid = ref.read(authServiceProvider).currentUser?.uid;
      
      if (currentUid != null) {
        debugPrint('🌍 Building network provider');
        ref.read(syncServiceProvider).syncInitialChatRooms(currentUid);

      }
    } else if (!isOnline && wasOnline) {
      debugPrint('🛑 [NO INTERNET, going offline]');
    }
  });
});
