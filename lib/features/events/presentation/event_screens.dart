import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/event_record.dart';
import '../../home/presentation/home_screen.dart' show nextOccurrenceForEvent;

enum _EventSort { nextOccurrence, celebrationDate, eventName }

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
              switch (sortBy) {
                case _EventSort.nextOccurrence:
                  final leftNext = nextOccurrenceForEvent(left);
                  final rightNext = nextOccurrenceForEvent(right);
                  if (leftNext == null && rightNext == null) return 0;
                  if (leftNext == null) return 1;
                  if (rightNext == null) return -1;
                  return leftNext.compareTo(rightNext);
                case _EventSort.eventName:
                  return left.eventName.toLowerCase().compareTo(right.eventName.toLowerCase());
                case _EventSort.celebrationDate:
                  return left.celebrationDate.compareTo(right.celebrationDate);
              }
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
                  DropdownMenuItem(value: _EventSort.nextOccurrence, child: Text('Upcoming (soonest)')),
                  DropdownMenuItem(value: _EventSort.celebrationDate, child: Text('Celebration date')),
                  DropdownMenuItem(value: _EventSort.eventName, child: Text('Event name')),
                ],
                onChanged: (value) => ref.read(_eventSortProvider.notifier).state = value ?? _EventSort.nextOccurrence,
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
final _eventSortProvider = StateProvider<_EventSort>((ref) => _EventSort.nextOccurrence);

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
  late final _celebrationDateController =
      TextEditingController(text: DateFormat.yMMMMd().format(_celebrationDate));

  DateTime _celebrationDate = DateTime.now().add(const Duration(days: 7));
  EventType _eventType = EventType.birthday;
  EventRecurrence _recurrence = EventRecurrence.yearly;
  EventPrivacy _privacy = EventPrivacy.private;
  // 0 represents "no reminder" and folds what used to be a separate
  // reminderEnabled switch into this single control.
  int _reminderDays = 7;
  bool _saving = false;
  bool _loadedExistingEvent = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _notesController.dispose();
    _celebrationDateController.dispose();
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
    _celebrationDateController.text = DateFormat.yMMMMd().format(_celebrationDate);
    _eventType = event.eventType;
    _recurrence = event.recurrence;
    _privacy = event.privacy;
    _reminderDays = event.reminderEnabled ? _reminderDaysFromOffsets(event.reminderOffsets) : 0;
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
      _celebrationDateController.text = DateFormat.yMMMMd().format(picked);
    });
  }

  int _reminderDaysFromOffsets(List<int> offsets) {
    if (offsets.isEmpty) {
      return 0;
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
    if (days <= 0) {
      return const [];
    }
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
      reminderEnabled: _reminderDays > 0,
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
          celebrationDateController: _celebrationDateController,
          eventType: _eventType,
          recurrence: _recurrence,
          privacy: _privacy,
          reminderDays: _reminderDays,
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
                celebrationDateController: _celebrationDateController,
                eventType: _eventType,
                recurrence: _recurrence,
                privacy: _privacy,
                reminderDays: _reminderDays,
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
    required this.celebrationDateController,
    required this.eventType,
    required this.recurrence,
    required this.privacy,
    required this.reminderDays,
    required this.onPickDate,
    required this.onEventTypeChanged,
    required this.onPrivacyChanged,
    required this.onRecurrenceChanged,
    required this.onReminderDaysChanged,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController notesController;
  final bool saving;
  final TextEditingController celebrationDateController;
  final EventType eventType;
  final EventRecurrence recurrence;
  final EventPrivacy privacy;
  // 0 means "no reminder" — this single field now covers what used to be a
  // separate enabled/disabled switch plus a lead-time dropdown.
  final int reminderDays;
  final VoidCallback onPickDate;
  final ValueChanged<EventType> onEventTypeChanged;
  final ValueChanged<EventPrivacy?> onPrivacyChanged;
  final ValueChanged<EventRecurrence?> onRecurrenceChanged;
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
              TextFormField(
                controller: celebrationDateController,
                readOnly: true,
                enabled: !saving,
                onTap: saving ? null : onPickDate,
                decoration: InputDecoration(
                  labelText: 'Celebration date',
                  hintText: 'Select the celebration date',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    onPressed: saving ? null : onPickDate,
                    icon: const Icon(Icons.calendar_month),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Select a celebration date' : null,
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
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: reminderDays,
                decoration: const InputDecoration(labelText: 'Reminder'),
                items: const [0, 1, 3, 7]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value == 0 ? 'None' : (value == 1 ? '1 day before' : '$value days before')),
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
                reminderDays == 0
                    ? 'No reminder will be sent for this event.'
                    : 'Reminders will be sent ${List<int>.generate(reminderDays, (index) => reminderDays - index).join(', ')} day${reminderDays == 1 ? '' : 's'} before the event.',
                style: Theme.of(context).textTheme.bodySmall,
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, EventRecord event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('"${event.eventName}" will be permanently removed. This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer,
              foregroundColor: Theme.of(dialogContext).colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(eventRepositoryProvider).deleteEvent(event.id);
    ref.invalidate(eventsProvider);
    if (context.mounted) {
      context.pop();
    }
  }

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
              final colorScheme = Theme.of(context).colorScheme;
              final nextOccurrence = nextOccurrenceForEvent(event);

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  // Identity row: avatar, name, type + privacy at a glance.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Icon(_eventTypeIcon(event.eventType), size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.eventName, style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(_eventTypeLabel(event.eventType)),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(
                                    event.privacy == EventPrivacy.public ? Icons.public : Icons.lock,
                                    size: 16,
                                  ),
                                  label: Text(event.privacy == EventPrivacy.public ? 'Public' : 'Private'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Countdown: the most useful single fact, surfaced first.
                  if (nextOccurrence != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_available_outlined, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            _countdownPhrase(nextOccurrence),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Core details as icon-led rows instead of a raw key/value stack.
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.cake_outlined,
                          label: 'Celebration date',
                          value: DateFormat.yMMMMd().format(event.celebrationDate),
                        ),
                        const Divider(height: 1),
                        _InfoTile(
                          icon: Icons.repeat,
                          label: 'Repeats',
                          value: event.recurrence.name.toUpperCase(),
                        ),
                        const Divider(height: 1),
                        _InfoTile(
                          icon: event.reminderEnabled
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_off_outlined,
                          label: 'Reminder',
                          value: event.reminderEnabled
                              ? 'Enabled Daily ${event.reminderOffsets[0]} days before'
                              : 'Disabled',
                        ),
                      ],
                    ),
                  ),

                  if (event.notes != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.notes_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text('Notes', style: Theme.of(context).textTheme.labelLarge),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(event.notes!),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (canManageEvent) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => context.push('/events/$eventId/edit'),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.error,
                              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                            ),
                            onPressed: () => _confirmDelete(context, ref, event),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Only the creator, admin, or superadmin can edit or delete this event.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
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

/// Icon-led label/value row used within the event details card.
class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly countdown phrase for a resolved next-occurrence date, e.g.
/// "Today", "Tomorrow", or "In 12 days".
String _countdownPhrase(DateTime occurrence) {
  final today = DateTime.now();
  final reference = DateTime(today.year, today.month, today.day);
  final daysAway = occurrence.difference(reference).inDays;

  if (daysAway <= 0) return 'Today';
  if (daysAway == 1) return 'Tomorrow';
  return 'In $daysAway days';
}

IconData _eventTypeIcon(EventType eventType) {
  switch (eventType) {
    case EventType.birthday:
      return Icons.cake_outlined;
    case EventType.anniversary:
      return Icons.favorite_outline;
    case EventType.graduation:
      return Icons.school_outlined;
    case EventType.wedding:
      return Icons.diamond_outlined;
    case EventType.custom:
      return Icons.celebration_outlined;
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