class AnnouncementAttachment {
  const AnnouncementAttachment({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;

  Map<String, dynamic> toJson() => {
        'label': label,
        'url': url,
      };

  factory AnnouncementAttachment.fromJson(Map<String, dynamic> json) {
    return AnnouncementAttachment(
      label: json['label'] as String,
      url: json['url'] as String,
    );
  }
}

class AnnouncementLink {
  const AnnouncementLink({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
      };

  factory AnnouncementLink.fromJson(Map<String, dynamic> json) {
    return AnnouncementLink(
      title: json['title'] as String,
      url: json['url'] as String,
    );
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.priority,
    required this.author,
    this.imageUrl,
    this.expirationDate,
    this.pinned = false,
    this.attachments = const [],
    this.links = const [],
  });

  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? expirationDate;
  final int priority;
  final String author;
  final bool pinned;
  final List<AnnouncementAttachment> attachments;
  final List<AnnouncementLink> links;

  Announcement copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? expirationDate,
    int? priority,
    String? author,
    bool? pinned,
    List<AnnouncementAttachment>? attachments,
    List<AnnouncementLink>? links,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      expirationDate: expirationDate ?? this.expirationDate,
      priority: priority ?? this.priority,
      author: author ?? this.author,
      pinned: pinned ?? this.pinned,
      attachments: attachments ?? this.attachments,
      links: links ?? this.links,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'expirationDate': expirationDate?.toIso8601String(),
      'priority': priority,
      'author': author,
      'pinned': pinned,
      'attachments': attachments.map((attachment) => attachment.toJson()).toList(),
      'links': links.map((link) => link.toJson()).toList(),
    };
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expirationDate: json['expirationDate'] == null
          ? null
          : DateTime.parse(json['expirationDate'] as String),
      priority: json['priority'] as int? ?? 0,
      author: json['author'] as String? ?? 'System',
      pinned: json['pinned'] as bool? ?? false,
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AnnouncementAttachment.fromJson)
          .toList(),
      links: (json['links'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AnnouncementLink.fromJson)
          .toList(),
    );
  }
}
