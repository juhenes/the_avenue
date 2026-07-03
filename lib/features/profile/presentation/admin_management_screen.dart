import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  ConsumerState<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _grantAdmin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null || user.email.trim().toLowerCase() != 'superadmin@theavenue.org') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the super admin can manage admin access.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).grantAdmin(
            email: _emailController.text.trim(),
            createdBy: user.id,
          );
      ref.invalidate(adminsProvider);
      _emailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin access granted.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to grant admin access: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _revokeAdmin(String email) async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.email.trim().toLowerCase() != 'superadmin@theavenue.org') {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).revokeAdmin(email);
      ref.invalidate(adminsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to revoke admin access: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isSuperAdmin = user?.email.trim().toLowerCase() == 'superadmin@theavenue.org';
    final adminsAsync = ref.watch(adminsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin management')),
      body: isSuperAdmin
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Grant admin access', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'user@example.com',
                            ),
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter an email' : null,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _busy ? null : _grantAdmin,
                            child: Text(_busy ? 'Saving...' : 'Grant admin'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Current admins', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                adminsAsync.when(
                  data: (admins) {
                    if (admins.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No admin accounts have been created yet.'),
                        ),
                      );
                    }

                    return Column(
                      children: admins
                          .map(
                            (admin) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.admin_panel_settings_outlined),
                                title: Text(admin.email),
                                subtitle: Text(admin.id),
                                trailing: IconButton(
                                  onPressed: _busy ? null : () => _revokeAdmin(admin.id),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                  error: (error, stackTrace) => Text('Unable to load admins: $error'),
                ),
              ],
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Only the super admin can manage admin accounts.'),
              ),
            ),
    );
  }
}