import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/event_record.dart';
import 'event_repository.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, EventRepository? eventRepository})
      : _auth = auth ?? FirebaseAuth.instance,
        _eventRepository = eventRepository;

  final FirebaseAuth _auth;
  final EventRepository? _eventRepository;

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<void> continueAsGuest() async {
    await _auth.signInAnonymously();
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required DateTime birthday,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await credential.user?.updateDisplayName(displayName);
    await credential.user?.reload();

    final user = credential.user;
    final eventRepository = _eventRepository;
    if (user != null && eventRepository != null) {
      await eventRepository.saveEvent(
        EventRecord(
          id: '${user.uid}-birthday',
          ownerId: user.uid,
          eventName: "$displayName's Birthday",
          eventType: EventType.birthday,
          celebrationDate: birthday,
          recurrence: EventRecurrence.yearly,
          privacy: EventPrivacy.public,
          createdBy: user.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
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
