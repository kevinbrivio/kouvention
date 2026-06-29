import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:oktoast/oktoast.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

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
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    try {
      return _auth.signInWithCredential(credential);
    } catch (_) {
      showToast('Sign in failed. Please try again later.');
    }

    return _auth.signInWithCredential(credential);
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
