import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/models/announcement.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider);
    final user = ref.watch(authStateProvider).value;
    final isAdminAsync = ref.watch(currentUserIsAdminProvider);

    final canCreateAnnouncement = user != null &&
        !user.isGuest &&
        isAdminAsync.maybeWhen(
          data: (isAdmin) => isAdmin,
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          if (canCreateAnnouncement)
            IconButton(
              onPressed: () => context.push('/announcements/new'),
              icon: const Icon(Icons.add),
              tooltip: 'Create announcement',
            ),
        ],
      ),
      floatingActionButton: canCreateAnnouncement
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/announcements/new'),
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            )
          : null,
      body: announcementsAsync.when(
        data: (announcements) {
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: announcements.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(announcement.pinned ? Icons.push_pin : Icons.campaign)),
                  title: Text(announcement.title),
                  subtitle: Text(DateFormat.yMMMMd().format(announcement.createdAt)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/announcements/${announcement.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Unable to load announcements: $error')),
      ),
    );
  }
}

class AnnouncementFormScreen extends ConsumerStatefulWidget {
  const AnnouncementFormScreen({super.key});

  @override
  ConsumerState<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends ConsumerState<AnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _pinned = false;
  bool _busy = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveAnnouncement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null || user.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in as an admin to create announcements.')),
      );
      return;
    }

    final normalizedEmail = user.email.trim().toLowerCase();
    final isSuperAdmin = normalizedEmail == 'superadmin@theavenue.org';

    if (!mounted) {
      return;
    }

    final isAdmin = isSuperAdmin || await ref.read(currentUserIsAdminProvider.future);

    if (!mounted) {
      return;
    }

    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins and the super admin can create announcements.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final announcement = Announcement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        priority: _pinned ? 100 : 0,
        author: user.displayName,
        pinned: _pinned,
      );

      await ref.read(announcementRepositoryProvider).saveAnnouncement(announcement);
      ref.invalidate(announcementsProvider);

      if (mounted) {
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save announcement: $error')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Create announcement')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a title' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 5,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a description' : null,
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  value: _pinned,
                  onChanged: _busy ? null : (value) => setState(() => _pinned = value),
                  title: const Text('Pinned announcement'),
                  subtitle: const Text('Pinned items show first in the list.'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _saveAnnouncement,
                  child: Text(_busy ? 'Saving...' : 'Save announcement'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
