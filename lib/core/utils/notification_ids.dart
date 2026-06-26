class NotificationIds {
  const NotificationIds._();

  static int reminder(String eventId, int offsetDays) {
    final value = Object.hash(eventId, offsetDays);
    return value & 0x7fffffff;
  }
}
