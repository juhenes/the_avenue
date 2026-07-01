import '../models/event_record.dart';

class ReminderSchedule {
  const ReminderSchedule._();

  static List<int> offsetsForEvent(EventRecord event) {
    if (!event.reminderEnabled) {
      return const [];
    }

    final offsets = event.reminderOffsets
        .where((offset) => offset >= 0)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    return offsets;
  }

  static List<DateTime> scheduleDatesForEvent(
    EventRecord event,
    DateTime now,
  ) {
    return offsetsForEvent(event)
        .map(
          (offset) => event.celebrationDate.subtract(
            Duration(days: offset),
          ),
        )
        .where((date) => !date.isBefore(now))
        .toList()
      ..sort();
  }
}