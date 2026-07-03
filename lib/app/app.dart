import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class TheAvenueApp extends ConsumerWidget {
  const TheAvenueApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'The Avenue',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final body = child ?? const SizedBox.shrink();
        if (firebaseReady) {
          return body;
        }

        return Banner(
          message: 'Demo mode',
          location: BannerLocation.topEnd,
          child: body,
        );
      },
    );
  }
}
