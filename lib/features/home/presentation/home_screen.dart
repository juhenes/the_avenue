import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/event_record.dart';

/// Events with fewer days than this remaining are shown on the home screen.
const int _kUpcomingWindowDays = 30;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value ?? AppUser.guest();
    final eventsAsync = ref.watch(eventsProvider);
    final announcementsAsync = ref.watch(announcementsProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final isAdmin = ref.watch(currentUserIsAdminProvider).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );

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
                if (!isAdmin) {
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _HeroBanner(user: user),
            const SizedBox(height: 16),
            _FloatingSearchBar(
              onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
            ),
            const SizedBox(height: 28),

            // Announcements: only rendered when there is at least one.
            announcementsAsync.when(
              data: (announcements) {
                if (announcements.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: 'Announcements',
                      actionLabel: 'View all',
                      onTap: () => context.push('/announcements'),
                    ),
                    const SizedBox(height: 12),
                    ...announcements.map(
                      (announcement) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          margin: EdgeInsets.zero,
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
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text('Failed to load announcements: $error'),
              ),
            ),

            _SectionHeader(
              title: 'Upcoming events',
              actionLabel: 'See all',
              onTap: () => context.push('/events'),
            ),
            const SizedBox(height: 12),
            eventsAsync.when(
              data: (events) {
                final visibleEvents = events.where((event) {
                  if (searchQuery.isEmpty) {
                    return true;
                  }
                  return event.eventName
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

/// A search field styled as a floating card, sitting above the surrounding
/// content with its own elevation and rounded corners.
class _FloatingSearchBar extends StatelessWidget {
  const _FloatingSearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(18),
      color: Theme.of(context).colorScheme.surface,
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Search events, celebrations, or announcements',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        onChanged: onChanged,
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
    final today = DateTime.now();
    final reference = DateTime(today.year, today.month, today.day);

    final upcomingEvents = events
        .map((event) => MapEntry(event, nextOccurrenceForEvent(event, now: reference)))
        .where((entry) => entry.value != null)
        // Only surface events happening within the upcoming window.
        .where((entry) =>
            entry.value!.difference(reference).inDays < _kUpcomingWindowDays)
        .toList()
      ..sort((left, right) => left.value!.compareTo(right.value!));

    if (upcomingEvents.isEmpty) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No events in the next 30 days.'),
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

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(event.eventName.characters.first.toUpperCase()),
                    ),
                    title: Text(event.eventName),
                    subtitle: Text(_countdownLabel(nextOccurrence, reference)),
                    trailing: _PrivacyChip(privacy: event.privacy),
                    onTap: () => context.push('/events/${event.id}'),
                  ),
                ),
              );
            },
          )
          .toList(),
    );
  }
}

/// Formats a friendly countdown string, e.g. "Today", "Tomorrow", or
/// "In 12 days", along with the calendar date for reference.
String _countdownLabel(DateTime occurrence, DateTime reference) {
  final daysAway = occurrence.difference(reference).inDays;
  final formattedDate = DateFormat.yMMMMd().format(occurrence);

  final String countdown;
  if (daysAway <= 0) {
    countdown = 'Today';
  } else if (daysAway == 1) {
    countdown = 'Tomorrow';
  } else {
    countdown = 'In $daysAway days';
  }

  return '$countdown - $formattedDate';
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