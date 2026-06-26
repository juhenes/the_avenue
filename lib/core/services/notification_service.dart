import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/event_record.dart';
import '../utils/notification_ids.dart';
import '../utils/reminder_schedule.dart';

class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(initializationSettings);
    _initialized = true;
  }

  Future<void> scheduleReminder({
    required EventRecord event,
    required DateTime scheduledFor,
    required int reminderOffsetDays,
  }) async {
    await initialize();
    if (kIsWeb) {
      return;
    }

    final notificationDateTime = scheduledFor.toLocal();
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'event_reminders',
        'Event Reminders',
        channelDescription: 'Local reminders for events and celebration dates',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      NotificationIds.reminder(event.id, reminderOffsetDays),
      '${event.fullName} is coming up',
      'Reminder ${reminderOffsetDays} day(s) before the ${event.eventType.name}.',
      NotificationService._toZonedDateTime(notificationDateTime),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> updateReminders(EventRecord event) async {
    await cancelReminders(event.id);
    for (final reminderOffset in ReminderSchedule.offsetsForEvent(event)) {
      final scheduledFor = event.celebrationDate.subtract(Duration(days: reminderOffset));
      if (scheduledFor.isAfter(DateTime.now())) {
        await scheduleReminder(
          event: event,
          scheduledFor: scheduledFor,
          reminderOffsetDays: reminderOffset,
        );
      }
    }
  }

  Future<void> cancelReminders(String eventId) async {
    await initialize();
    for (var offset = 0; offset <= 365; offset++) {
      await _plugin.cancel(NotificationIds.reminder(eventId, offset));
    }
  }

  Future<void> rescheduleAfterEdit(EventRecord event) async {
    await updateReminders(event);
  }

  static tz.TZDateTime _toZonedDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return tz.TZDateTime.local(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
  }
}
