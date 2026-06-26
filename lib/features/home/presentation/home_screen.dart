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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/events/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
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
            const SizedBox(height: 20),
            _QuickStats(eventsAsync: eventsAsync),
            const SizedBox(height: 20),
            _SectionHeader(title: 'Upcoming events', actionLabel: 'See all', onTap: () => context.push('/events')),
            eventsAsync.when(
              data: (events) => _UpcomingEventList(
                events: events.where((event) {
                  if (searchQuery.isEmpty) {
                    return true;
                  }
                  return event.fullName.toLowerCase().contains(searchQuery.toLowerCase());
                }).toList(),
              ),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (error, stackTrace) => Text('Failed to load events: $error'),
            ),
            const SizedBox(height: 20),
            _SectionHeader(title: 'Announcements', actionLabel: 'View all', onTap: () => context.push('/announcements')),
            announcementsAsync.when(
              data: (announcements) => Column(
                children: announcements
                    .map(
                      (announcement) => Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Icon(announcement.pinned ? Icons.push_pin : Icons.campaign)),
                          title: Text(announcement.title),
                          subtitle: Text(announcement.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/announcements/${announcement.id}'),
                        ),
                      ),
                    )
                    .toList(),
              ),
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => Text('Failed to load announcements: $error'),
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

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.eventsAsync});

  final AsyncValue<List<EventRecord>> eventsAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return eventsAsync.when(
      data: (events) {
        final birthDateEvents = events.where((event) => event.eventType == EventType.birthday).length;
        final otherEvents = events.length - birthDateEvents;
        final upcoming = events.where((event) => event.celebrationDate.isAfter(DateTime.now())).length;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(label: 'Upcoming', value: '$upcoming', icon: Icons.event_available_outlined),
            _StatCard(label: 'Birth date events', value: '$birthDateEvents', icon: Icons.cake_outlined),
            _StatCard(label: 'Other events', value: '$otherEvents', icon: Icons.celebration_outlined),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      ),
      error: (error, stackTrace) => Text('Unable to load stats: $error', style: theme.textTheme.bodyMedium),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 18),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
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
    if (events.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No events found yet.'),
        ),
      );
    }

    return Column(
      children: events
          .take(3)
          .map(
            (event) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(event.fullName.characters.first.toUpperCase())),
                title: Text(event.fullName),
                subtitle: Text(DateFormat.yMMMMd().format(event.celebrationDate)),
                trailing: _PrivacyChip(privacy: event.privacy),
                onTap: () => context.push('/events/${event.id}'),
              ),
            ),
          )
          .toList(),
    );
  }
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
