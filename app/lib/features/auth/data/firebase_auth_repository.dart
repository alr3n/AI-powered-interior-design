import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AppUser _map(User u) => AppUser(
        uid: u.uid,
        displayName: u.displayName,
        email: u.email,
        photoUrl: u.photoURL,
        isGuest: u.isAnonymous,
      );

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u == null ? null : _map(u));

  @override
  AppUser? get currentUser =>
      _auth.currentUser == null ? null : _map(_auth.currentUser!);

  Future<void> _ensureUserDoc(User u) async {
    final ref = _firestore.doc('users/${u.uid}');
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'displayName': u.displayName,
        'email': u.email,
        'photoUrl': u.photoURL,
        'isGuest': u.isAnonymous,
        'region': AppConstants.defaultRegion,
        'currency': AppConstants.defaultCurrency,
        'preferences': {
          'themeMode': 'system',
          'budgetTier': 'medium',
          'occupants': 2,
          'hasChildren': false,
          'hasPets': false,
          'accessibilityNeeds': <String>[],
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) throw const AuthFailure('Sign-in cancelled.');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      // Guest upgrade: linking preserves the uid, so guest data survives.
      final current = _auth.currentUser;
      UserCredential cred;
      if (current != null && current.isAnonymous) {
        cred = await current.linkWithCredential(credential);
      } else {
        cred = await _auth.signInWithCredential(credential);
      }
      await _ensureUserDoc(cred.user!);
      return _map(cred.user!);
    } on Failure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Google sign-in failed.');
    } catch (_) {
      throw const NetworkFailure();
    }
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      await _ensureUserDoc(cred.user!);
      return _map(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  @override
  Future<AppUser> registerWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await _ensureUserDoc(cred.user!);
      return _map(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  @override
  Future<AppUser> signInAsGuest() async {
    try {
      final cred = await _auth.signInAnonymously();
      await _ensureUserDoc(cred.user!);
      return _map(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Guest sign-in failed.');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  String _friendly(FirebaseAuthException e) => switch (e.code) {
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Password must be at least 6 characters.',
        'invalid-email' => 'That email address looks invalid.',
        _ => e.message ?? 'Authentication failed.',
      };
}
