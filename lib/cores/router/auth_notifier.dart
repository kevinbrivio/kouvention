import 'package:flutter/material.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';

/// Bridges Firebase's auth stream to GoRouter's redirect.
/// Every time a user signs in or out, this notifies GoRouter
/// to re-run its redirect logic — no manual navigation needed.
class AuthNotifier extends ChangeNotifier {
  final AuthService _authService;

  AuthNotifier(this._authService) {
    _authService.authStateChanges.listen((_) {
      notifyListeners();
    });
  }

  bool get isLoggedIn => _authService.currentUser != null;

  bool get hasDisplayName =>
      _authService.currentUser?.displayName?.isNotEmpty ?? false;
}
