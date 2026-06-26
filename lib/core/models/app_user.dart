class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.isGuest,
  });

  final String id;
  final String displayName;
  final String email;
  final bool isGuest;

  AppUser copyWith({
    String? id,
    String? displayName,
    String? email,
    bool? isGuest,
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      isGuest: isGuest ?? this.isGuest,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'isGuest': isGuest,
      };

  factory AppUser.guest() {
    return const AppUser(
      id: 'guest',
      displayName: 'Guest',
      email: '',
      isGuest: true,
    );
  }
}
