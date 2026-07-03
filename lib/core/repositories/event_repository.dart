import '../models/event_record.dart';

abstract class EventRepository {
  Stream<List<EventRecord>> watchEvents(String userId);
  Future<List<EventRecord>> fetchEvents(String userId);
  Future<void> saveEvent(EventRecord event);
  Future<void> deleteEvent(String eventId);
}

class DemoEventRepository implements EventRepository {
  DemoEventRepository()
      : _events = [
          EventRecord(
            id: '1',
            ownerId: 'demo-user',
            eventName: 'Mia Carter',
            eventType: EventType.birthday,
            celebrationDate: DateTime.now().add(const Duration(days: 7)),
            recurrence: EventRecurrence.yearly,
            notes: 'Order the chocolate cake.',
            reminderEnabled: true,
            reminderOffsets: const [7, 3, 1, 0],
            privacy: EventPrivacy.private,
            createdBy: 'demo-user',
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          EventRecord(
            id: '2',
            ownerId: 'demo-user',
            eventName: 'Campus Graduation',
            eventType: EventType.graduation,
            celebrationDate: DateTime.now().add(const Duration(days: 14)),
            recurrence: EventRecurrence.never,
            notes: 'Bring a camera.',
            reminderEnabled: true,
            reminderOffsets: const [14, 7, 3, 1, 0],
            privacy: EventPrivacy.public,
            createdBy: 'demo-user',
            createdAt: DateTime.now().subtract(const Duration(days: 20)),
            updatedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ];

  final List<EventRecord> _events;

  @override
  Future<void> deleteEvent(String eventId) async {
    _events.removeWhere((event) => event.id == eventId);
  }

  @override
  Future<List<EventRecord>> fetchEvents(String userId) async {
    return _events
        .where(
          (event) =>
              event.ownerId == userId ||
              event.privacy == EventPrivacy.public,
        )
        .toList()
      ..sort(
        (left, right) =>
            left.celebrationDate.compareTo(right.celebrationDate),
      );
  }

  @override
  Stream<List<EventRecord>> watchEvents(String userId) async* {
    yield await fetchEvents(userId);
  }

  @override
  Future<void> saveEvent(EventRecord event) async {
    final index = _events.indexWhere(
      (existing) => existing.id == event.id,
    );

    if (index == -1) {
      _events.add(event);
    } else {
      _events[index] = event;
    }
  }
}