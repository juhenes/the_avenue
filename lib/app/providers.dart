import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/models/announcement.dart';
import '../core/models/app_user.dart';
import '../core/models/event_record.dart';
import '../core/repositories/announcement_repository.dart';
import '../core/repositories/auth_repository.dart';
import '../core/repositories/firebase_auth_repository.dart';
import '../core/repositories/firestore_announcement_repository.dart';
import '../core/repositories/firestore_event_repository.dart';
import '../core/repositories/event_repository.dart';
import '../core/services/firebase_messaging_service.dart';
import '../core/services/notification_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirebaseAuthRepository();
  }
  return DemoAuthRepository();
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirestoreEventRepository();
  }
  return DemoEventRepository();
});

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    return FirestoreAnnouncementRepository();
  }
  return DemoAnnouncementRepository();
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
