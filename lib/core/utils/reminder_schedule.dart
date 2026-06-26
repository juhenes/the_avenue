import '../models/event_record.dart';

class ReminderSchedule {
  const ReminderSchedule._();

  static List<int> offsetsForEvent(EventRecord event) {
    if (!event.reminderEnabled) {
      return const [];
    }

    final offsets = <int>{...event.reminderOffsets.where((value) => value >= 0)};
    offsets.addAll(_patternOffsets(event.reminderPattern, event.celebrationDate));

    final sortedOffsets = offsets.toList()..sort((left, right) => right.compareTo(left));
    return sortedOffsets;
  }

  static List<DateTime> scheduleDatesForEvent(EventRecord event, DateTime now) {
    return offsetsForEvent(event)
        .map((offset) => event.celebrationDate.subtract(Duration(days: offset)))
        .where((dateTime) => dateTime.isAfter(now))
        .toList()
      ..sort();
  }

  static Iterable<int> _patternOffsets(ReminderPattern pattern, DateTime celebrationDate) {
    final daysUntilEvent = celebrationDate.difference(DateTime.now()).inDays;
    if (daysUntilEvent <= 0) {
      return const [];
    }

    switch (pattern) {
      case ReminderPattern.once:
        return const [];
      case ReminderPattern.dailyUntilEvent:
        return List<int>.generate(daysUntilEvent, (index) => daysUntilEvent - index);
      case ReminderPattern.everyOtherDay:
        return List<int>.generate((daysUntilEvent / 2).ceil(), (index) => daysUntilEvent - (index * 2));
      case ReminderPattern.weeklyUntilEvent:
        return List<int>.generate((daysUntilEvent / 7).ceil(), (index) => daysUntilEvent - (index * 7));
    }
  }
}
