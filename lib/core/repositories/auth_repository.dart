import 'dart:async';

import '../models/app_user.dart';
import '../models/event_record.dart';
import 'event_repository.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchAuthState();
  AppUser? get currentUser;
  Future<void> continueAsGuest();
  Future<void> signIn({required String email, required String password});
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required DateTime birthday,
  });
  Future<void> sendPasswordReset({required String email});
  Future<void> signOut();
}

class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({EventRepository? eventRepository}) : _eventRepository = eventRepository;

  final StreamController<AppUser?> _controller = StreamController<AppUser?>.broadcast();
  final EventRepository? _eventRepository;
  AppUser? _currentUser = AppUser.guest();

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> watchAuthState() async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  void _emit(AppUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Future<void> continueAsGuest() async {
    _emit(AppUser.guest());
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required DateTime birthday,
  }) async {
    _emit(AppUser(id: 'demo-user', displayName: displayName, email: email, isGuest: false));

    final eventRepository = _eventRepository;
    if (eventRepository != null) {
      await eventRepository.saveEvent(
        EventRecord(
          id: 'demo-user-birthday',
          ownerId: 'demo-user',
          eventName: "$displayName's Birthday",
          eventType: EventType.birthday,
          celebrationDate: birthday,
          recurrence: EventRecurrence.yearly,
          privacy: EventPrivacy.public,
          createdBy: 'demo-user',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    return;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _emit(AppUser(id: 'demo-user', displayName: 'The Avenue User', email: email, isGuest: false));
  }

  @override
  Future<void> signOut() async {
    _emit(AppUser.guest());
  }
}
