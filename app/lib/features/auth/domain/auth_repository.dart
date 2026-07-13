/// Domain-level auth contract. Presentation depends on this, never on
/// FirebaseAuth directly (Dependency Inversion).
abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> registerWithEmail(String email, String password);
  Future<AppUser> signInAsGuest();
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
