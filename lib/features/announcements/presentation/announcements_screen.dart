import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/models/announcement.dart';

bool _isSuperAdminEmail(String? email) {
  return email?.trim().toLowerCase() == 'superadmin@theavenue.org';
}

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider);
    final user = ref.watch(authStateProvider).value;
    final isAdminAsync = ref.watch(currentUserIsAdminProvider);

    final isSuperAdmin = _isSuperAdminEmail(user?.email);
    final isAdmin = isAdminAsync.maybeWhen(data: (isAdmin) => isAdmin, orElse: () => false);

    final canManageAnnouncements = user != null && !user.isGuest && (isAdmin || isSuperAdmin);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          if (canManageAnnouncements)
            IconButton(
              onPressed: () => context.push('/announcements/new'),
              icon: const Icon(Icons.add),
              tooltip: 'Create announcement',
            ),
        ],
      ),
      floatingActionButton: canManageAnnouncements
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/announcements/new'),
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            )
          : null,
      body: announcementsAsync.when(
        data: (announcements) {
          // Normal users and guests never see archived announcements.
          final visible =
              canManageAnnouncements ? announcements : announcements.where((a) => !a.archived).toList();

          if (visible.isEmpty) {
            return const Center(child: Text('No announcements yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: visible.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final announcement = visible[index];
              return Opacity(
                opacity: announcement.archived ? 0.6 : 1.0,
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(announcement.pinned ? Icons.push_pin : Icons.campaign),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(announcement.title)),
                        if (announcement.archived)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Archived',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(DateFormat.yMMMMd().format(announcement.createdAt)),
                    trailing: canManageAnnouncements
                        ? PopupMenuButton<String>(
                            onSelected: (value) => _handleMenuAction(
                              context,
                              ref,
                              value,
                              announcement,
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: announcement.archived ? 'unarchive' : 'archive',
                                child: Text(announcement.archived ? 'Unarchive' : 'Archive'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => context.push('/announcements/${announcement.id}'),
                  ),
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

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    Announcement announcement,
  ) async {
    switch (action) {
      case 'edit':
        context.push('/announcements/${announcement.id}/edit');
        return;
      case 'archive':
        await ref.read(announcementRepositoryProvider).saveAnnouncement(
              announcement.copyWith(archived: true),
            );
        ref.invalidate(announcementsProvider);
        return;
      case 'unarchive':
        await ref.read(announcementRepositoryProvider).saveAnnouncement(
              announcement.copyWith(archived: false),
            );
        ref.invalidate(announcementsProvider);
        return;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete announcement?'),
            content: Text('This will permanently delete "${announcement.title}". This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(announcementRepositoryProvider).deleteAnnouncement(announcement.id);
          ref.invalidate(announcementsProvider);
        }
        return;
    }
  }
}

class AnnouncementFormScreen extends ConsumerStatefulWidget {
  const AnnouncementFormScreen({super.key, this.announcementId});

  /// Pass an existing announcement's id to edit it; leave null to create a new one.
  final String? announcementId;

  bool get isEditing => announcementId != null;

  @override
  ConsumerState<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends ConsumerState<AnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _pinned = false;
  bool _busy = false;
  bool _initialized = false;
  Announcement? _existing;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _hydrateFromExisting(Announcement announcement) {
    if (_initialized) return;
    _existing = announcement;
    _titleController.text = announcement.title;
    _descriptionController.text = announcement.description;
    _pinned = announcement.pinned;
    _initialized = true;
  }

  Future<bool> _resolveIsAdmin(dynamic user) async {
    if (user == null || user.isGuest as bool) {
      return false;
    }
    if (user.email.trim().toLowerCase() == 'superadmin@theavenue.org') {
      return true;
    }
    return ref.read(currentUserIsAdminProvider.future);
  }

  Future<void> _saveAnnouncement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null || user.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in as an admin to manage announcements.')),
      );
      return;
    }

    final isAdmin = await _resolveIsAdmin(user);

    if (!mounted) {
      return;
    }

    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins and the super admin can manage announcements.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final announcement = (_existing ??
              Announcement(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: '',
                description: '',
                createdAt: DateTime.now(),
                priority: 0,
                author: user.displayName,
              ))
          .copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _pinned ? 100 : 0,
        pinned: _pinned,
      );

      await ref.read(announcementRepositoryProvider).saveAnnouncement(announcement);
      ref.invalidate(announcementsProvider);
      if (widget.announcementId != null) {
        ref.invalidate(announcementByIdProvider(widget.announcementId!));
      }

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
    // Creating a new announcement — no lookup needed.
    if (!widget.isEditing) {
      return _buildForm(context, title: 'Create announcement');
    }

    final announcementAsync = ref.watch(announcementByIdProvider(widget.announcementId!));

    return announcementAsync.when(
      data: (announcement) {
        if (announcement == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit announcement')),
            body: const Center(child: Text('This announcement no longer exists.')),
          );
        }
        _hydrateFromExisting(announcement);
        return _buildForm(context, title: 'Edit announcement');
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Edit announcement')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Edit announcement')),
        body: Center(child: Text('Unable to load announcement: $error')),
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required String title}) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                  child: Text(_busy ? 'Saving...' : (widget.isEditing ? 'Save changes' : 'Save announcement')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}