enum EventType {
  birthday,
  anniversary,
  graduation,
  wedding,
  custom,
}

enum EventPrivacy {
  private,
  public,
}

enum EventRecurrence {
  never,
  daily,
  weekly,
  monthly,
  yearly,
}

class EventRecord {
  const EventRecord({
    required this.id,
    required this.ownerId,
    required this.eventName,
    required this.eventType,
    required this.celebrationDate,
    required this.recurrence,
    required this.privacy,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.reminderEnabled = true,
    this.reminderOffsets = const [7, 3, 1, 0],
  });

  final String id;
  final String ownerId;
  final String eventName;
  final EventType eventType;
  final DateTime celebrationDate;
  final EventRecurrence recurrence;
  final String? notes;

  final bool reminderEnabled;

  final List<int> reminderOffsets;

  final EventPrivacy privacy;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventRecord copyWith({
    String? id,
    String? ownerId,
    String? eventName,
    EventType? eventType,
    DateTime? celebrationDate,
    EventRecurrence? recurrence,
    String? notes,
    bool? reminderEnabled,
    List<int>? reminderOffsets,
    EventPrivacy? privacy,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventRecord(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      eventName: eventName ?? this.eventName,
      eventType: eventType ?? this.eventType,
      celebrationDate: celebrationDate ?? this.celebrationDate,
      recurrence: recurrence ?? this.recurrence,
      notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      privacy: privacy ?? this.privacy,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'eventName': eventName,
      'eventType': eventType.name,
      'celebrationDate': celebrationDate.toIso8601String(),
      'recurrence': recurrence.name,
      'notes': notes,
      'reminderEnabled': reminderEnabled,
      'reminderOffsets': reminderOffsets,
      'privacy': privacy.name,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory EventRecord.fromJson(Map<String, dynamic> json) {
    return EventRecord(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      eventName: json['eventName'] as String? ?? json['fullName'] as String,
      eventType: EventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => EventType.custom,
      ),
      celebrationDate: DateTime.parse(
        json['celebrationDate'] as String,
      ),
      recurrence: EventRecurrence.values.firstWhere(
        (r) => r.name == json['recurrence'],
        orElse: () => EventRecurrence.never,
      ),
      notes: json['notes'] as String?,
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      reminderOffsets:
          (json['reminderOffsets'] as List<dynamic>? ?? const [7, 3, 1, 0])
              .cast<int>(),
      privacy: EventPrivacy.values.firstWhere(
        (p) => p.name == json['privacy'],
        orElse: () => EventPrivacy.private,
      ),
      createdBy: json['createdBy'] as String? ?? json['ownerId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}