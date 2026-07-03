import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value ?? AppUser.guest();
    final themeMode = ref.watch(themeModeProvider);
    final isSuperAdmin =
        user.email.trim().toLowerCase() == 'superadmin@theavenue.org';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    child: Text(
                      user.displayName.characters.first.toUpperCase(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user.email.isEmpty ? 'Guest account' : user.email,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.isGuest
                        ? 'Limited mode active'
                        : 'Signed in and ready to sync events.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: SwitchListTile.adaptive(
              title: const Text('Demo notifications'),
              subtitle: const Text(
                'NotificationService is wired for local reminders.',
              ),
              value: true,
              onChanged: (_) {},
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<ThemeMode>(
                initialValue: themeMode,
                decoration: const InputDecoration(
                  labelText: 'Theme',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                ],
                onChanged: (value) {
                  ref.read(themeModeProvider.notifier).state =
                      value ?? ThemeMode.system;
                },
              ),
            ),
          ),

          if (isSuperAdmin) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Admin management'),
                subtitle: const Text(
                  'Grant or revoke admin access.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/admins'),
              ),
            ),
          ],

          const SizedBox(height: 24),

          FilledButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();

              if (context.mounted) {
                context.go('/auth/login');
              }
            },
          ),
        ],
      ),
    );
  }
}