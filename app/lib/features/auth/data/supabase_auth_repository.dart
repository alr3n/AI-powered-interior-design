import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/errors/failures.dart';
import '../domain/auth_repository.dart';

/// Supabase Auth implementation. The matching `profiles` row is created and
/// kept in sync by database triggers (see supabase/migrations), so unlike the
/// old Firestore version no client-side "ensure user doc" step is needed.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  GoTrueClient get _auth => _client.auth;

  AppUser _map(User u) {
    final meta = u.userMetadata ?? const <String, dynamic>{};
    final email = u.email;
    return AppUser(
      uid: u.id,
      displayName: (meta['full_name'] ?? meta['name']) as String?,
      email: (email == null || email.isEmpty) ? null : email,
      photoUrl: (meta['avatar_url'] ?? meta['picture']) as String?,
      isGuest: u.isAnonymous,
    );
  }

  @override
  AppUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _map(u);
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    // Emit the restored session immediately so the router never waits on a
    // first auth event, then follow changes. Token refreshes re-emit the same
    // user, so collapse duplicates.
    yield currentUser;
    yield* _auth.onAuthStateChange
        .map((s) {
          final u = s.session?.user;
          return u == null ? null : _map(u);
        })
        .distinct((a, b) =>
            a?.uid == b?.uid &&
            a?.isGuest == b?.isGuest &&
            a?.email == b?.email &&
            a?.displayName == b?.displayName);
  }

  /// Google runs through Supabase's OAuth flow (configure the provider in the
  /// dashboard). A guest is *linked* so the uid — and therefore all of their
  /// projects — is preserved; everyone else signs in normally.
  @override
  Future<void> signInWithGoogle() => _guard(() async {
        final redirect = kIsWeb ? null : Env.authRedirect;
        final current = _auth.currentUser;
        final launched = (current != null && current.isAnonymous)
            ? await _auth.linkIdentity(OAuthProvider.google,
                redirectTo: redirect)
            : await _auth.signInWithOAuth(OAuthProvider.google,
                redirectTo: redirect);
        if (!launched) throw const AuthFailure('Could not open Google sign-in.');
      });

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _guard(() async {
        await _auth.signInWithPassword(email: email, password: password);
      });

  @override
  Future<void> registerWithEmail(String email, String password) =>
      _guard(() async {
        final current = _auth.currentUser;
        if (current != null && current.isAnonymous) {
          // Upgrade the guest in place: same uid, data preserved.
          await _auth.updateUser(
              UserAttributes(email: email, password: password));
          return;
        }
        final res = await _auth.signUp(email: email, password: password);
        if (res.session == null) {
          throw const AuthFailure(
              'Check your email to confirm your account, then sign in.');
        }
      });

  @override
  Future<void> signInAsGuest() => _guard(() async {
        await _auth.signInAnonymously();
      });

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Failure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    } catch (_) {
      throw const NetworkFailure();
    }
  }

  String _friendly(AuthException e) => switch (e.code) {
        'invalid_credentials' => 'Email or password is incorrect.',
        'email_not_confirmed' => 'Confirm your email address, then sign in.',
        'user_already_exists' ||
        'email_exists' =>
          'An account already exists for that email.',
        'weak_password' => 'Password must be at least 6 characters.',
        'email_address_invalid' ||
        'validation_failed' =>
          'That email address looks invalid.',
        'over_request_rate_limit' ||
        'over_email_send_rate_limit' =>
          'Too many attempts. Please wait a moment and try again.',
        'anonymous_provider_disabled' =>
          'Guest sign-in is not enabled for this project.',
        'signup_disabled' => 'New sign-ups are currently disabled.',
        _ => e.message,
      };
}
