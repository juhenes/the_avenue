import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/event_record.dart';

enum _EventSort { celebrationDate, fullName }

class EventListScreen extends ConsumerWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value ?? AppUser.guest();
    final eventsAsync = ref.watch(eventsProvider);
    final query = ref.watch(searchQueryProvider);
    final privacyFilter = ref.watch(_eventPrivacyFilterProvider);
    final sortBy = ref.watch(_eventSortProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/events/new'),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: eventsAsync.when(
        data: (events) {
          final visibleEvents = events.where((event) {
            if (query.isEmpty) {
              final matchesPrivacy = privacyFilter == null || event.privacy == privacyFilter;
              return matchesPrivacy;
            }
            final matchesQuery = event.fullName.toLowerCase().contains(query.toLowerCase()) ||
                event.relationship?.toLowerCase().contains(query.toLowerCase()) == true;
            final matchesPrivacy = privacyFilter == null || event.privacy == privacyFilter;
            return matchesQuery && matchesPrivacy;
          }).toList()
            ..sort((left, right) {
              if (sortBy == _EventSort.fullName) {
                return left.fullName.toLowerCase().compareTo(right.fullName.toLowerCase());
              }
              return left.celebrationDate.compareTo(right.celebrationDate);
            });

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search events'),
                onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: privacyFilter == null,
                    onSelected: (_) => ref.read(_eventPrivacyFilterProvider.notifier).state = null,
                  ),
                  ChoiceChip(
                    label: const Text('Public'),
                    selected: privacyFilter == EventPrivacy.public,
                    onSelected: (_) => ref.read(_eventPrivacyFilterProvider.notifier).state = EventPrivacy.public,
                  ),
                  ChoiceChip(
                    label: const Text('Private'),
                    selected: privacyFilter == EventPrivacy.private,
                    onSelected: (_) => ref.read(_eventPrivacyFilterProvider.notifier).state = EventPrivacy.private,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<_EventSort>(
                value: sortBy,
                decoration: const InputDecoration(labelText: 'Sort by'),
                items: const [
                  DropdownMenuItem(value: _EventSort.celebrationDate, child: Text('Celebration date')),
                  DropdownMenuItem(value: _EventSort.fullName, child: Text('Full name')),
                ],
                onChanged: (value) => ref.read(_eventSortProvider.notifier).state = value ?? _EventSort.celebrationDate,
              ),
              const SizedBox(height: 20),
              if (visibleEvents.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No events found.')))
              else
                ...visibleEvents.map((event) => _EventCard(event: event)),
              if (user.isGuest)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text('Guest mode is read-only for cloud-synced events.'),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Unable to load events: $error')),
      ),
    );
  }
}

final _eventPrivacyFilterProvider = StateProvider<EventPrivacy?>((ref) => null);
final _eventSortProvider = StateProvider<_EventSort>((ref) => _EventSort.celebrationDate);

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.eventId});

  final String? eventId;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _notesController = TextEditingController();
  final List<int> _selectedOffsets = [7, 3, 1];
  DateTime _celebrationDate = DateTime.now().add(const Duration(days: 7));
  DateTime? _birthDate;
  EventType _eventType = EventType.birthday;
  EventPrivacy _privacy = EventPrivacy.private;
  ReminderPattern _pattern = ReminderPattern.once;
  bool _reminderEnabled = true;
  bool _saving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _relationshipController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isBirthDate}) async {
    final initial = isBirthDate ? (_birthDate ?? DateTime.now()) : _celebrationDate;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isBirthDate) {
        _birthDate = picked;
      } else {
        _celebrationDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = ref.read(authStateProvider).value ?? AppUser.guest();
    if (user.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to create private or synced events.')),
      );
      return;
    }

    setState(() => _saving = true);
    final event = EventRecord(
      id: widget.eventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: user.id,
      fullName: _fullNameController.text.trim(),
      eventType: _eventType,
      birthDate: _birthDate,
      celebrationDate: _celebrationDate,
      relationship: _relationshipController.text.trim().isEmpty ? null : _relationshipController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      reminderEnabled: _reminderEnabled,
      reminderOffsets: _selectedOffsets,
      reminderPattern: _pattern,
      privacy: _privacy,
      createdBy: user.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.read(eventRepositoryProvider).saveEvent(event);
    await ref.read(notificationServiceProvider).updateReminders(event);
    ref.invalidate(eventsProvider);

    if (mounted) {
      context.pop();
    }
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit event' : 'New event')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EventType>(
                  value: _eventType,
                  decoration: const InputDecoration(labelText: 'Event type'),
                  items: EventType.values
                      .map((value) => DropdownMenuItem(value: value, child: Text(_eventTypeLabel(value))))
                      .toList(),
                  onChanged: (value) => setState(() => _eventType = value ?? EventType.birthday),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _relationshipController,
                  decoration: const InputDecoration(labelText: 'Relationship / Category'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  value: _reminderEnabled,
                  onChanged: (value) => setState(() => _reminderEnabled = value),
                  title: const Text('Reminder enabled'),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(label: const Text('Once'), selected: _pattern == ReminderPattern.once, onSelected: (_) => setState(() => _pattern = ReminderPattern.once)),
                    ChoiceChip(label: const Text('Daily'), selected: _pattern == ReminderPattern.dailyUntilEvent, onSelected: (_) => setState(() => _pattern = ReminderPattern.dailyUntilEvent)),
                    ChoiceChip(label: const Text('Every other day'), selected: _pattern == ReminderPattern.everyOtherDay, onSelected: (_) => setState(() => _pattern = ReminderPattern.everyOtherDay)),
                    ChoiceChip(label: const Text('Weekly'), selected: _pattern == ReminderPattern.weeklyUntilEvent, onSelected: (_) => setState(() => _pattern = ReminderPattern.weeklyUntilEvent)),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EventPrivacy>(
                  value: _privacy,
                  decoration: const InputDecoration(labelText: 'Privacy'),
                  items: EventPrivacy.values
                      .map((value) => DropdownMenuItem(value: value, child: Text(value.name.toUpperCase())))
                      .toList(),
                  onChanged: (value) => setState(() => _privacy = value ?? EventPrivacy.private),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Celebration date'),
                  subtitle: Text(DateFormat.yMMMMd().format(_celebrationDate)),
                  trailing: TextButton(onPressed: () => _pickDate(isBirthDate: false), child: const Text('Pick date')),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Birth date (optional)'),
                  subtitle: Text(_birthDate == null ? 'Not set' : DateFormat.yMMMMd().format(_birthDate!)),
                  trailing: TextButton(onPressed: () => _pickDate(isBirthDate: true), child: const Text('Pick date')),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save event'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event details'),
        actions: [
          IconButton(
            onPressed: () => context.push('/events/$eventId/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) {
          final event = events.firstWhere(
            (candidate) => candidate.id == eventId,
            orElse: () => events.first,
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.fullName, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(event.eventType.name.toUpperCase()),
                      const SizedBox(height: 16),
                      _KeyValue(label: 'Privacy', value: event.privacy.name.toUpperCase()),
                      _KeyValue(label: 'Celebration date', value: DateFormat.yMMMMd().format(event.celebrationDate)),
                      _KeyValue(label: 'Reminder', value: event.reminderEnabled ? 'Enabled' : 'Disabled'),
                      _KeyValue(label: 'Pattern', value: event.reminderPattern.name),
                      if (event.relationship != null) _KeyValue(label: 'Relationship', value: event.relationship!),
                      if (event.notes != null) _KeyValue(label: 'Notes', value: event.notes!),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () async {
                              await ref.read(eventRepositoryProvider).deleteEvent(event.id);
                              ref.invalidate(eventsProvider);
                              if (context.mounted) {
                                context.pop();
                              }
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Unable to load event: $error')),
      ),
    );
  }
}

class AnnouncementDetailScreen extends ConsumerWidget {
  const AnnouncementDetailScreen({super.key, required this.announcementId});

  final String announcementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Announcement')),
      body: announcementsAsync.when(
        data: (announcements) {
          final announcement = announcements.firstWhere(
            (candidate) => candidate.id == announcementId,
            orElse: () => announcements.first,
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(announcement.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('By ${announcement.author}'),
              const SizedBox(height: 16),
              Text(announcement.description),
              const SizedBox(height: 16),
              if (announcement.attachments.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Attachments', style: Theme.of(context).textTheme.titleMedium),
                        ...announcement.attachments.map((attachment) => ListTile(title: Text(attachment.label), subtitle: Text(attachment.url))),
                      ],
                    ),
                  ),
                ),
              if (announcement.links.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Links', style: Theme.of(context).textTheme.titleMedium),
                        ...announcement.links.map((link) => ListTile(title: Text(link.title), subtitle: Text(link.url))),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Unable to load announcement: $error')),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final EventRecord event;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(event.fullName.characters.first.toUpperCase())),
        title: Text(event.fullName),
        subtitle: Text('${_eventTypeLabel(event.eventType)} • ${DateFormat.yMMMMd().format(event.celebrationDate)}'),
        trailing: Wrap(
          spacing: 8,
          children: [
            Chip(label: Text(event.privacy.name.toUpperCase())),
            Icon(event.reminderEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
          ],
        ),
        onTap: () => context.push('/events/${event.id}'),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

String _eventTypeLabel(EventType eventType) {
  if (eventType == EventType.birthday) {
    return 'Birth date';
  }
  return eventType.name.toUpperCase();
}
