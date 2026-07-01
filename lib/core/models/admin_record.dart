class AdminRecord {
  const AdminRecord({
    required this.id,
    required this.email,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String email;
  final DateTime createdAt;
  final String createdBy;

  Map<String, dynamic> toJson() => {
        'email': email,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

  factory AdminRecord.fromJson(Map<String, dynamic> json) {
    return AdminRecord(
      id: json['id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String? ?? 'superadmin@theavenue.org',
    );
  }
}