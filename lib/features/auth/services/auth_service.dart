import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Completer<UserCredential>? _signInCompleter;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> initialize({
    required String clientId,
    required String serverClientId,
  }) async {
    await _googleSignIn.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );

    _googleSignIn.authenticationEvents.listen(_handleAuthEvent).onError((
      error,
    ) {
      debugPrint('Google auth stream error: $error');
      _signInCompleter?.completeError(AuthException('google-sign-in failed'));
    });

    // await _googleSignIn.attemptLightweightAuthentication();
  }

  Future<void> _handleAuthEvent(GoogleSignInAuthenticationEvent event) async {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        try {
          final googleUser = event.user;
          final googleAuth = googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
          );

          final userCredential = await _auth.signInWithCredential(credential);
          _signInCompleter?.complete(userCredential);
        } catch (e) {
          debugPrint('Firebase credential error: $e');
          _signInCompleter?.completeError(e);
        }
        break;

      case GoogleSignInAuthenticationEventSignOut():
        debugPrint('Google sign-out event received');
        break;

      // Future-proofing: Google may add new event types.
      // Without this, a new event would silently do nothing.
      default:
        debugPrint('Unhandled Google auth event: $event');
    }
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      await _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signInWithGoogle() async {
    _signInCompleter = Completer<UserCredential>();

    try {
      await _googleSignIn.authenticate();
    } catch (e) {
      if (!_signInCompleter!.isCompleted) {
        _signInCompleter!.completeError(
          AuthException('Google sign-in was cancelled'),
        );
      }
    }

    return _signInCompleter!.future;
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.disconnect()]);
  }

  Future<bool> get isLoggedIn async {
    final user = await _auth.authStateChanges().first;
    return user != null;
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUidProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.uid;
});

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
