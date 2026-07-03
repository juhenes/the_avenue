import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:the_avenue/app/providers.dart';

import '../../../../core/models/announcement.dart';

class AnnouncementCard extends ConsumerWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.canManage,
  });

  final Announcement announcement;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Opacity(
      opacity: announcement.archived ? 0.6 : 1,
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(
              announcement.pinned
                  ? Icons.push_pin
                  : Icons.campaign,
            ),
          ),

          title: Row(
            children: [
              Expanded(
                child: Text(announcement.title),
              ),

              if (announcement.archived)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                  child: Text(
                    'Archived',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),

          subtitle: Text(
            DateFormat.yMMMMd().format(
              announcement.createdAt,
            ),
          ),

          trailing: canManage
              ? _AnnouncementMenuButton(
                  announcement: announcement,
                )
              : const Icon(Icons.chevron_right),

          onTap: () {
            context.push(
              '/announcements/${announcement.id}',
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementMenuButton extends ConsumerWidget {
  const _AnnouncementMenuButton({
    required this.announcement,
  });

  final Announcement announcement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            context.push(
              '/announcements/${announcement.id}/edit',
            );
            break;

          case 'archive':
            await ref
                .read(announcementRepositoryProvider)
                .saveAnnouncement(
                  announcement.copyWith(
                    archived: true,
                  ),
                );

            ref.invalidate(announcementsProvider);
            break;

          case 'unarchive':
            await ref
                .read(announcementRepositoryProvider)
                .saveAnnouncement(
                  announcement.copyWith(
                    archived: false,
                  ),
                );

            ref.invalidate(announcementsProvider);
            break;

          case 'delete':
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text(
                  'Delete announcement?',
                ),
                content: Text(
                  'Delete "${announcement.title}"?',
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              await ref
                  .read(announcementRepositoryProvider)
                  .deleteAnnouncement(
                    announcement.id,
                  );

              ref.invalidate(
                announcementsProvider,
              );
            }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Text('Edit'),
        ),
        PopupMenuItem(
          value: announcement.archived
              ? 'unarchive'
              : 'archive',
          child: Text(
            announcement.archived
                ? 'Unarchive'
                : 'Archive',
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete',
            style: TextStyle(
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }
}