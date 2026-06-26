import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
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
