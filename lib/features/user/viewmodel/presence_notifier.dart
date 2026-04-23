import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/user/services/user_service.dart';

final presenceNotifierProvider = ChangeNotifierProvider(
  (ref) => PresenceNotifier(ref, ref.read(userServiceProvider)),
);

class PresenceNotifier extends ChangeNotifier {
  final UserService _userService;
  final Ref _ref;
  AppLifecycleListener? _lifecycleListener;
  String? _uid;

  PresenceNotifier(this._ref, this._userService) {
    // Listen to auth state - auto start/stop updates
    _ref.listen(authStateProvider, (prev, next) {
      final user = next.valueOrNull;
      if (user != null) {
        _start(user.uid);
      } else {
        _stop();
      }
    });
  }

  void _start(String userId) {
    _uid = userId;
  
    _lifecycleListener = AppLifecycleListener(
      onResume: () async {
        try {
          await _userService.setOnline(userId);
        } catch (e) {
          debugPrint('setOnline failed (likely mid-auth): $e');
        }
      },
      onHide: () async {
        try {
          await _userService.setOffline(userId);
        } catch (e) {
          debugPrint('setOffline failed: $e');
        }
      },
      onPause: () async {
        try {
          await _userService.setOffline(userId);
        } catch (e) {
          debugPrint('setOffline failed: $e');
        }
      },
    );
  }

  void _stop() {
    _uid = null;

    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }

  Future<void> signOutWithPresence(AuthService authService) async {
    if (_uid != null) {
      await _userService.setOffline(_uid!);
      _uid = null;
    }

    _lifecycleListener?.dispose();
    _lifecycleListener = null;

    await authService.signOut();
  }
  
  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}
