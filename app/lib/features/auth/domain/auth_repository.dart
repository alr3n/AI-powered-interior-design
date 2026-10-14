/// Domain-level auth contract. Presentation depends on this, never on the
/// Supabase SDK directly (Dependency Inversion).
///
/// Actions return nothing: the resulting session is observed through
/// [authStateChanges]. (Google sign-in completes in the browser and returns
/// through a deep link, so there is no user to hand back at call time.)
abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<void> signInWithGoogle();
  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String email, String password);
  Future<void> signInAsGuest();
  Future<void> signOut();
}

class AppUser {
  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    this.isGuest = false,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final bool isGuest;
}
