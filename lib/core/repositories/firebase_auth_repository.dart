import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<void> continueAsGuest() async {
    await _auth.signInAnonymously();
  }

  @override
  Future<void> register({required String email, required String password, required String displayName}) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await credential.user?.updateDisplayName(displayName);
    await credential.user?.reload();
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    if (_auth.currentUser?.isAnonymous ?? false) {
      await _auth.currentUser?.delete();
    }
    await _auth.signOut();
  }

  @override
  Stream<AppUser?> watchAuthState() {
    return _auth.authStateChanges().map(_toAppUser);
  }

  AppUser? _toAppUser(User? user) {
    if (user == null) {
      return null;
    }

    return AppUser(
      id: user.uid,
      displayName: user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'The Avenue User',
      email: user.email ?? '',
      isGuest: user.isAnonymous,
    );
  }
}
