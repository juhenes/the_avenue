enum EventType { birthday, anniversary, graduation, wedding, custom }

enum EventPrivacy { private, public }

enum ReminderPattern { once, dailyUntilEvent, everyOtherDay, weeklyUntilEvent }

class EventRecord {
  const EventRecord({
    required this.id,
    required this.ownerId,
    required this.fullName,
    required this.eventType,
    required this.celebrationDate,
    required this.privacy,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.birthDate,
    this.relationship,
    this.notes,
    this.reminderEnabled = true,
    this.reminderOffsets = const [7, 3, 1],
    this.reminderPattern = ReminderPattern.once,
  });

  final String id;
  final String ownerId;
  final String fullName;
  final EventType eventType;
  final DateTime? birthDate;
  final DateTime celebrationDate;
  final String? relationship;
  final String? notes;
  final bool reminderEnabled;
  final List<int> reminderOffsets;
  final ReminderPattern reminderPattern;
  final EventPrivacy privacy;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventRecord copyWith({
    String? id,
    String? ownerId,
    String? fullName,
    EventType? eventType,
    DateTime? birthDate,
    DateTime? celebrationDate,
    String? relationship,
    String? notes,
    bool? reminderEnabled,
    List<int>? reminderOffsets,
    ReminderPattern? reminderPattern,
    EventPrivacy? privacy,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventRecord(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      fullName: fullName ?? this.fullName,
      eventType: eventType ?? this.eventType,
      birthDate: birthDate ?? this.birthDate,
      celebrationDate: celebrationDate ?? this.celebrationDate,
      relationship: relationship ?? this.relationship,
      notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      reminderPattern: reminderPattern ?? this.reminderPattern,
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
      'fullName': fullName,
      'eventType': eventType.name,
      'birthDate': birthDate?.toIso8601String(),
      'celebrationDate': celebrationDate.toIso8601String(),
      'relationship': relationship,
      'notes': notes,
      'reminderEnabled': reminderEnabled,
      'reminderOffsets': reminderOffsets,
      'reminderPattern': reminderPattern.name,
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
      fullName: json['fullName'] as String,
      eventType: EventType.values.firstWhere(
        (eventType) => eventType.name == json['eventType'],
        orElse: () => EventType.custom,
      ),
      birthDate: json['birthDate'] == null
          ? (json['birthday'] == null ? null : DateTime.parse(json['birthday'] as String))
          : DateTime.parse(json['birthDate'] as String),
      celebrationDate: DateTime.parse(json['celebrationDate'] as String),
      relationship: json['relationship'] as String?,
      notes: json['notes'] as String?,
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      reminderOffsets: (json['reminderOffsets'] as List<dynamic>? ?? const [7, 3, 1]).cast<int>(),
      reminderPattern: ReminderPattern.values.firstWhere(
        (pattern) => pattern.name == json['reminderPattern'],
        orElse: () => ReminderPattern.once,
      ),
      privacy: EventPrivacy.values.firstWhere(
        (privacy) => privacy.name == json['privacy'],
        orElse: () => EventPrivacy.private,
      ),
      createdBy: json['createdBy'] as String? ?? json['ownerId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}