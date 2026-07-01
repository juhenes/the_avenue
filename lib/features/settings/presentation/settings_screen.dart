import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(authStateProvider).value;
    final isSuperAdmin = user?.email.trim().toLowerCase() == 'superadmin@theavenue.org';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: SwitchListTile.adaptive(
              title: const Text('Demo notifications'),
              subtitle: const Text('NotificationService is wired for local reminders.'),
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
                decoration: const InputDecoration(labelText: 'Theme'),
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
                onChanged: (value) => ref.read(themeModeProvider.notifier).state = value ?? ThemeMode.system,
              ),
            ),
          ),
          if (isSuperAdmin) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Admin management'),
                subtitle: const Text('Grant or revoke admin access for announcement management.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/admins'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
