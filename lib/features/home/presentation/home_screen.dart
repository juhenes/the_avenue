import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/event_record.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value ?? AppUser.guest();
    final eventsAsync = ref.watch(eventsProvider);
    final announcementsAsync = ref.watch(announcementsProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(user.isGuest ? 'The Avenue' : 'Hello, ${user.displayName}'),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: user.isGuest
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final currentUser = ref.read(authStateProvider).value ?? AppUser.guest();
                final normalizedEmail = currentUser.email.trim().toLowerCase();

                final admins = await ref.read(adminsProvider.future);
                if (!context.mounted) {
                  return;
                }

                final canCreateAnnouncement = normalizedEmail == 'superadmin@theavenue.org' ||
                    admins.any((admin) => admin.email == normalizedEmail);

                if (!canCreateAnnouncement) {
                  context.push('/events/new');
                  return;
                }

                final choice = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder: (sheetContext) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.event_outlined),
                            title: const Text('Create event'),
                            onTap: () => Navigator.of(sheetContext).pop('event'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.campaign_outlined),
                            title: const Text('Create announcement'),
                            onTap: () => Navigator.of(sheetContext).pop('announcement'),
                          ),
                        ],
                      ),
                    );
                  },
                );

                if (!context.mounted || choice == null) {
                  return;
                }

                if (choice == 'announcement') {
                  context.push('/announcements/new');
                } else {
                  context.push('/events/new');
                }
              },
              child: const Icon(Icons.add),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(eventsProvider);
          ref.invalidate(announcementsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _HeroBanner(user: user),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search events, celebrations, or announcements',
              ),
              onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
            ),
            _SectionHeader(
                title: 'Announcements',
                actionLabel: 'View all',
                onTap: () => context.push('/announcements'),
              ),
              announcementsAsync.when(
                data: (announcements) => Column(
                  children: announcements
                      .map(
                        (announcement) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                announcement.pinned
                                    ? Icons.push_pin
                                    : Icons.campaign,
                              ),
                            ),
                            title: Text(announcement.title),
                            subtitle: Text(
                              announcement.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.push('/announcements/${announcement.id}'),
                          ),
                        ),
                      )
                      .toList(),
                ),
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) =>
                    Text('Failed to load announcements: $error'),
              ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Upcoming events',
                actionLabel: 'See all',
                onTap: () => context.push('/events'),
              ),
              eventsAsync.when(
                data: (events) {
                  final visibleEvents = events.where((event) {
                    if (searchQuery.isEmpty) {
                      return true;
                    }
                    return event.fullName
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase());
                  }).toList();

                  return _UpcomingEventList(events: visibleEvents);
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) =>
                    Text('Failed to load events: $error'),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.secondaryContainer],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.isGuest ? 'Welcome, guest' : 'Welcome back, ${user.displayName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            user.isGuest
                ? 'Browse public events and announcements. Sign in to store your own reminders.'
                : 'Track events, celebrations, announcements, and reminders from one place.',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionLabel, required this.onTap});

  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _UpcomingEventList extends StatelessWidget {
  const _UpcomingEventList({required this.events});

  final List<EventRecord> events;

  @override
  Widget build(BuildContext context) {
    final upcomingEvents = events
        .map(
          (event) => MapEntry(event, nextOccurrenceForEvent(event)),
        )
        .where((entry) => entry.value != null)
        .toList()
      ..sort((left, right) => left.value!.compareTo(right.value!));

    if (upcomingEvents.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No upcoming events yet.'),
        ),
      );
    }

    return Column(
      children: upcomingEvents
          .take(3)
          .map(
            (entry) {
              final event = entry.key;
              final nextOccurrence = entry.value!;

              return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(event.fullName.characters.first.toUpperCase())),
                title: Text(event.fullName),
                subtitle: Text(DateFormat.yMMMMd().format(nextOccurrence)),
                trailing: _PrivacyChip(privacy: event.privacy),
                onTap: () => context.push('/events/${event.id}'),
              ),
            );
            },
          )
          .toList(),
    );
  }
}

DateTime? nextOccurrenceForEvent(EventRecord event, {DateTime? now}) {
  final reference = DateTime(now?.year ?? DateTime.now().year, now?.month ?? DateTime.now().month, now?.day ?? DateTime.now().day);
  final initial = DateTime(event.celebrationDate.year, event.celebrationDate.month, event.celebrationDate.day);

  switch (event.recurrence) {
    case EventRecurrence.never:
      return initial.isBefore(reference) ? null : initial;
    case EventRecurrence.daily:
      var next = initial;
      while (next.isBefore(reference)) {
        next = next.add(const Duration(days: 1));
      }
      return next;
    case EventRecurrence.weekly:
      var next = initial;
      while (next.isBefore(reference)) {
        next = next.add(const Duration(days: 7));
      }
      return next;
    case EventRecurrence.monthly:
      var next = initial;
      while (next.isBefore(reference)) {
        next = _addMonthsClamped(next, 1);
      }
      return next;
    case EventRecurrence.yearly:
      var next = initial;
      while (next.isBefore(reference)) {
        next = _addMonthsClamped(next, 12);
      }
      return next;
  }
}

DateTime _addMonthsClamped(DateTime date, int monthsToAdd) {
  final targetYear = date.year + ((date.month - 1 + monthsToAdd) ~/ 12);
  final targetMonth = ((date.month - 1 + monthsToAdd) % 12) + 1;
  final targetDay = date.day.clamp(1, DateTime(targetYear, targetMonth + 1, 0).day);

  return DateTime(targetYear, targetMonth, targetDay);
}

class _PrivacyChip extends StatelessWidget {
  const _PrivacyChip({required this.privacy});

  final EventPrivacy privacy;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(privacy == EventPrivacy.public ? 'Public' : 'Private'),
      avatar: Icon(
        privacy == EventPrivacy.public ? Icons.public : Icons.lock,
        size: 16,
      ),
    );
  }
}
