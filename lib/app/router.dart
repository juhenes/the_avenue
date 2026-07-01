import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../features/announcements/presentation/announcements_screen.dart';
import '../features/authentication/presentation/auth_screens.dart';
import '../features/events/presentation/event_screens.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/admin_management_screen.dart';
import 'providers.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final refreshStream = GoRouterRefreshStream(authRepository.watchAuthState());

  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshStream,
    redirect: (context, state) {
      final currentUser = authRepository.currentUser;
      final onAuthRoute = state.matchedLocation.startsWith('/auth');

      if (currentUser == null && !onAuthRoute) {
        return '/auth/login';
      }

      if (currentUser != null && onAuthRoute && currentUser.isGuest) {
        return '/home';
      }

      if (currentUser != null && onAuthRoute && !currentUser.isGuest) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventListScreen(),
      ),
      GoRoute(
        path: '/events/new',
        builder: (context, state) => const EventFormScreen(),
      ),
      GoRoute(
        path: '/events/:eventId',
        builder: (context, state) => EventDetailScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/events/:eventId/edit',
        builder: (context, state) => EventFormScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/announcements',
        builder: (context, state) => const AnnouncementsScreen(),
      ),
      GoRoute(
        path: '/announcements/new',
        builder: (context, state) => const AnnouncementFormScreen(),
      ),
      GoRoute(
        path: '/announcements/:announcementId',
        builder: (context, state) => AnnouncementDetailScreen(announcementId: state.pathParameters['announcementId']!),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/admins',
        builder: (context, state) => const AdminManagementScreen(),
      ),
    ],
  );
});
