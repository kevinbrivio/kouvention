import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Future<bool> get isLoggedIn async {
    final user = await _auth.authStateChanges().first;
    return user != null;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});
