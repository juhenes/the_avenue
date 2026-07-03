import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/event_record.dart';

enum _EventSort { celebrationDate, eventName }

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
              return privacyFilter == null || event.privacy == privacyFilter;
            }

            final matchesQuery = event.eventName.toLowerCase().contains(query.toLowerCase());
            final matchesPrivacy = privacyFilter == null || event.privacy == privacyFilter;
            return matchesQuery && matchesPrivacy;
          }).toList()
            ..sort((left, right) {
              if (sortBy == _EventSort.eventName) {
                return left.eventName.toLowerCase().compareTo(right.eventName.toLowerCase());
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
                initialValue: sortBy,
                decoration: const InputDecoration(labelText: 'Sort by'),
                items: const [
                  DropdownMenuItem(value: _EventSort.celebrationDate, child: Text('Celebration date')),
                  DropdownMenuItem(value: _EventSort.eventName, child: Text('Event name')),
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
  final _notesController = TextEditingController();

  DateTime _celebrationDate = DateTime.now().add(const Duration(days: 7));
  EventType _eventType = EventType.birthday;
  EventRecurrence _recurrence = EventRecurrence.yearly;
  EventPrivacy _privacy = EventPrivacy.private;
  int _reminderDays = 7;
  bool _reminderEnabled = true;
  bool _saving = false;
  bool _loadedExistingEvent = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _canManageEvent({
    required AppUser currentUser,
    required bool isAdmin,
    required EventRecord event,
  }) {
    final normalizedEmail = currentUser.email.trim().toLowerCase();
    return event.ownerId == currentUser.id ||
        normalizedEmail == 'superadmin@theavenue.org' ||
        isAdmin;
  }

  void _hydrateFromEvent(EventRecord event) {
    if (_loadedExistingEvent) {
      return;
    }

    _loadedExistingEvent = true;
    _fullNameController.text = event.eventName;
    _notesController.text = event.notes ?? '';
    _celebrationDate = event.celebrationDate;
    _eventType = event.eventType;
    _recurrence = event.recurrence;
    _privacy = event.privacy;
    _reminderEnabled = event.reminderEnabled;
    _reminderDays = _reminderDaysFromOffsets(event.reminderOffsets);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _celebrationDate,
    );

    if (picked == null) return;

    setState(() {
      _celebrationDate = picked;
    });
  }

  int _reminderDaysFromOffsets(List<int> offsets) {
    if (offsets.isEmpty) {
      return 7;
    }

    for (final preset in [1, 3, 7]) {
      final generatedOffsets = List<int>.generate(preset, (index) => preset - index);
      if (listEquals(offsets, generatedOffsets)) {
        return preset;
      }
    }

    final highestOffset = offsets.first;
    if (highestOffset >= 7) {
      return 7;
    }
    if (highestOffset >= 3) {
      return 3;
    }
    return 1;
  }

  List<int> _buildReminderOffsets(int days) {
    return List<int>.generate(days, (index) => days - index);
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

    final isAdmin = ref.read(currentUserIsAdminProvider).value ?? false;

    EventRecord? existingEvent;
    if (widget.eventId != null) {
      final events = ref.read(eventsProvider).value ?? const <EventRecord>[];
      existingEvent = events.firstWhere(
        (candidate) => candidate.id == widget.eventId,
        orElse: () => EventRecord(
          id: widget.eventId!,
          ownerId: user.id,
          eventName: '',
          eventType: EventType.birthday,
          celebrationDate: DateTime.now(),
          recurrence: EventRecurrence.yearly,
          privacy: EventPrivacy.private,
          createdBy: user.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (!_canManageEvent(currentUser: user, isAdmin: isAdmin, event: existingEvent)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only the creator, admin, or superadmin can edit this event.')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final event = EventRecord(
      id: widget.eventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: existingEvent?.ownerId ?? user.id,
      eventName: _fullNameController.text.trim(),
      eventType: _eventType,
      celebrationDate: _celebrationDate,
      recurrence: _recurrence,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      reminderEnabled: _reminderEnabled,
      reminderOffsets: _buildReminderOffsets(_reminderDays),
      privacy: _privacy,
      createdBy: existingEvent?.createdBy ?? user.id,
      createdAt: existingEvent?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(eventRepositoryProvider).saveEvent(event);

      try {
        await ref.read(notificationServiceProvider).updateReminders(event);
      } catch (error) {
        debugPrint('Failed to update reminders for ${event.id}: $error');
      }

      ref.invalidate(eventsProvider);

      if (mounted) {
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save event: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventId != null;
    final currentUser = ref.watch(authStateProvider).value ?? AppUser.guest();
    final isAdminAsync = ref.watch(currentUserIsAdminProvider);
    final eventsAsync = ref.watch(eventsProvider);

    if (!isEditing) {
      return Scaffold(
        appBar: AppBar(title: const Text('New event')),
        body: _EventFormBody(
          formKey: _formKey,
          fullNameController: _fullNameController,
          notesController: _notesController,
          saving: _saving,
          celebrationDate: _celebrationDate,
          eventType: _eventType,
          recurrence: _recurrence,
          privacy: _privacy,
          reminderDays: _reminderDays,
          reminderEnabled: _reminderEnabled,
          onReminderDaysChanged: (value) => setState(() => _reminderDays = value),
          onPickDate: _pickDate,
          onEventTypeChanged: (value) {
            setState(() {
              _eventType = value;

              switch (value) {
                case EventType.birthday:
                case EventType.anniversary:
                case EventType.wedding:
                  _recurrence = EventRecurrence.yearly;
                  break;
                case EventType.graduation:
                  _recurrence = EventRecurrence.never;
                  break;
                case EventType.custom:
                  break;
              }
            });
          },
          onPrivacyChanged: (value) => setState(() => _privacy = value ?? EventPrivacy.private),
          onRecurrenceChanged: (value) {
            if (value != null) {
              setState(() => _recurrence = value);
            }
          },
          onReminderEnabledChanged: (value) => setState(() => _reminderEnabled = value),
          onSave: _save,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit event')),
      body: eventsAsync.when(
        data: (events) {
          final event = events.firstWhere(
            (candidate) => candidate.id == widget.eventId,
            orElse: () => events.first,
          );

          return isAdminAsync.when(
            data: (isAdmin) {
              final canManageEvent = _canManageEvent(currentUser: currentUser, isAdmin: isAdmin, event: event);

              if (!canManageEvent) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Only the creator, admin, or superadmin can edit this event.'),
                  ),
                );
              }

              if (!_loadedExistingEvent) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _hydrateFromEvent(event);
                    setState(() {});
                  }
                });
              }

              return _EventFormBody(
                formKey: _formKey,
                fullNameController: _fullNameController,
                notesController: _notesController,
                saving: _saving,
                celebrationDate: _celebrationDate,
                eventType: _eventType,
                recurrence: _recurrence,
                privacy: _privacy,
                reminderDays: _reminderDays,
                reminderEnabled: _reminderEnabled,
                onReminderDaysChanged: (value) => setState(() => _reminderDays = value),
                onPickDate: _pickDate,
                onEventTypeChanged: (value) {
                  setState(() {
                    _eventType = value;

                    switch (value) {
                      case EventType.birthday:
                      case EventType.anniversary:
                      case EventType.wedding:
                        _recurrence = EventRecurrence.yearly;
                        break;
                      case EventType.graduation:
                        _recurrence = EventRecurrence.never;
                        break;
                      case EventType.custom:
                        break;
                    }
                  });
                },
                onPrivacyChanged: (value) => setState(() => _privacy = value ?? EventPrivacy.private),
                onRecurrenceChanged: (value) {
                  if (value != null) {
                    setState(() => _recurrence = value);
                  }
                },
                onReminderEnabledChanged: (value) => setState(() => _reminderEnabled = value),
                onSave: _save,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('Unable to load permissions: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Unable to load event: $error')),
      ),
    );
  }
}

class _EventFormBody extends StatelessWidget {
  const _EventFormBody({
    required this.formKey,
    required this.fullNameController,
    required this.notesController,
    required this.saving,
    required this.celebrationDate,
    required this.eventType,
    required this.recurrence,
    required this.privacy,
    required this.reminderDays,
    required this.reminderEnabled,
    required this.onPickDate,
    required this.onEventTypeChanged,
    required this.onPrivacyChanged,
    required this.onRecurrenceChanged,
    required this.onReminderEnabledChanged,
    required this.onReminderDaysChanged,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController notesController;
  final bool saving;
  final DateTime celebrationDate;
  final EventType eventType;
  final EventRecurrence recurrence;
  final EventPrivacy privacy;
  final int reminderDays;
  final bool reminderEnabled;
  final VoidCallback onPickDate;
  final ValueChanged<EventType> onEventTypeChanged;
  final ValueChanged<EventPrivacy?> onPrivacyChanged;
  final ValueChanged<EventRecurrence?> onRecurrenceChanged;
  final ValueChanged<bool> onReminderEnabledChanged;
  final ValueChanged<int> onReminderDaysChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: fullNameController,
                decoration: const InputDecoration(labelText: 'Event name'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter an event name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EventType>(
                initialValue: eventType,
                decoration: const InputDecoration(labelText: 'Event type'),
                items: EventType.values
                    .map((value) => DropdownMenuItem(value: value, child: Text(_eventTypeLabel(value))))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onEventTypeChanged(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                value: reminderEnabled,
                onChanged: onReminderEnabledChanged,
                title: const Text('Reminder enabled'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: reminderDays,
                decoration: const InputDecoration(labelText: 'Reminder days before event'),
                items: const [1, 3, 7]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value == 1 ? '1 day' : '$value days'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onReminderDaysChanged(value);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Selecting $reminderDays day${reminderDays == 1 ? '' : 's'} creates reminders at ${List<int>.generate(reminderDays, (index) => reminderDays - index).join(', ')} day${reminderDays == 1 ? '' : 's'} before the event.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EventPrivacy>(
                initialValue: privacy,
                decoration: const InputDecoration(labelText: 'Privacy'),
                items: EventPrivacy.values
                    .map((value) => DropdownMenuItem(value: value, child: Text(value.name.toUpperCase())))
                    .toList(),
                onChanged: onPrivacyChanged,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EventRecurrence>(
                initialValue: recurrence,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: EventRecurrence.values
                    .map((value) => DropdownMenuItem(value: value, child: Text(value.name.toUpperCase())))
                    .toList(),
                onChanged: onRecurrenceChanged,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Celebration date'),
                subtitle: Text(DateFormat.yMMMMd().format(celebrationDate)),
                trailing: TextButton(
                  onPressed: onPickDate,
                  child: const Text('Pick date'),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: saving ? null : onSave,
                child: Text(saving ? 'Saving...' : 'Save event'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value ?? AppUser.guest();
    final isAdminAsync = ref.watch(currentUserIsAdminProvider);
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      body: eventsAsync.when(
        data: (events) {
          final event = events.firstWhere(
            (candidate) => candidate.id == eventId,
            orElse: () => events.first,
          );

          return isAdminAsync.when(
            data: (isAdmin) {
              final canManageEvent = event.ownerId == currentUser.id ||
                  currentUser.email.trim().toLowerCase() == 'superadmin@theavenue.org' ||
                  isAdmin;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.eventName, style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 8),
                          Text(event.eventType.name.toUpperCase()),
                          const SizedBox(height: 16),
                          _KeyValue(label: 'Privacy', value: event.privacy.name.toUpperCase()),
                          _KeyValue(label: 'Celebration date', value: DateFormat.yMMMMd().format(event.celebrationDate)),
                          _KeyValue(label: 'Reminder', value: event.reminderEnabled ? 'Enabled' : 'Disabled'),
                          _KeyValue(label: 'Repeat', value: event.recurrence.name.toUpperCase()),
                          _KeyValue(label: 'Reminder days', value: event.reminderOffsets.map((e) => '$e day(s)').join(', ')),
                          if (event.notes != null) _KeyValue(label: 'Notes', value: event.notes!),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (canManageEvent)
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
                              if (canManageEvent) ...[
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () => context.push('/events/$eventId/edit'),
                                  child: const Text('Edit'),
                                ),
                              ],
                            ],
                          ),
                          if (!canManageEvent)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text('Only the creator, admin, or superadmin can edit or delete this event.'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('Unable to load permissions: $error')),
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
        leading: CircleAvatar(child: Text(event.eventName.characters.first.toUpperCase())),
        title: Text(event.eventName),
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
  switch (eventType) {
    case EventType.birthday:
      return 'Birthday';
    case EventType.anniversary:
      return 'Anniversary';
    case EventType.graduation:
      return 'Graduation';
    case EventType.wedding:
      return 'Wedding';
    case EventType.custom:
      return 'Custom';
  }
}