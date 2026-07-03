import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/models/announcement.dart';
import '../core/models/admin_record.dart';
import '../core/models/app_user.dart';
import '../core/models/event_record.dart';
import '../core/repositories/admin_repository.dart';
import '../core/repositories/announcement_repository.dart';
import '../core/repositories/auth_repository.dart';
import '../core/repositories/firestore_admin_repository.dart';
import '../core/repositories/firebase_auth_repository.dart';
import '../core/repositories/firestore_announcement_repository.dart';
import '../core/repositories/firestore_event_repository.dart';
import '../core/repositories/event_repository.dart';
import '../core/services/firebase_messaging_service.dart';
import '../core/services/notification_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirebaseAuthRepository(eventRepository: ref.watch(eventRepositoryProvider));
  }

  throw StateError('Firebase has not been initialized.');
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirestoreEventRepository();
  }

  throw StateError('Firebase has not been initialized.');
});

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirestoreAnnouncementRepository();
  }

  throw StateError('Firebase has not been initialized.');
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirestoreAdminRepository();
  }

  throw StateError('Firebase has not been initialized.');
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final messagingServiceProvider = Provider<FirebaseMessagingService>((ref) {
  return FirebaseMessagingService();
});

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});

final searchQueryProvider = StateProvider<String>((ref) {
  return '';
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthState();
});

final eventsProvider = StreamProvider<List<EventRecord>>((ref) {
  final user = ref.watch(authStateProvider).value ?? AppUser.guest();
  return ref.watch(eventRepositoryProvider).watchEvents(user.id);
});

final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  return ref.watch(announcementRepositoryProvider).watchAnnouncements();
});

final adminsProvider = StreamProvider<List<AdminRecord>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAdmins();
});

final currentUserIsAdminProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value ?? AppUser.guest();
  final normalizedEmail = user.email.trim().toLowerCase();

  if (user.isGuest) {
    return Stream.value(false);
  }

  if (normalizedEmail == 'superadmin@theavenue.org') {
    return Stream.value(true);
  }

  return ref.watch(adminRepositoryProvider).watchAdminByEmail(normalizedEmail).map((admin) => admin != null);
});
