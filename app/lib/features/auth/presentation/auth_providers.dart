import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_auth_repository.dart';
import '../domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) =>
    FirebaseAuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance));

final authStateProvider = StreamProvider<AppUser?>(
    (ref) => ref.watch(authRepositoryProvider).authStateChanges());

final currentUserProvider = Provider<AppUser?>(
    (ref) => ref.watch(authStateProvider).valueOrNull);

/// Sign-in actions with AsyncValue state for button spinners / error banners.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> _run(Future<AppUser> Function(AuthRepository) action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await action(ref.read(authRepositoryProvider));
    });
  }

  Future<void> google() => _run((r) => r.signInWithGoogle());
  Future<void> guest() => _run((r) => r.signInAsGuest());
  Future<void> email(String email, String password, {required bool register}) =>
      _run((r) => register
          ? r.registerWithEmail(email, password)
          : r.signInWithEmail(email, password));
}

final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>(AuthController.new);
