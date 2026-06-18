class Team {
  final String id;
  final String? clubId;
  final String country;
  final String club;
  final String? imageUrl;
  final String? clubLogoUrl;
  final String sport;
  final String category;
  final Map<String, String> memberRoles;

  Team({
    this.id = '',
    this.clubId,
    required this.country,
    required this.club,
    this.imageUrl,
    this.clubLogoUrl,
    this.sport = '',
    required this.category,
    this.memberRoles = const {},
  });

  Team copyWith({
    String? id,
    String? clubId,
    String? country,
    String? club,
    String? imageUrl,
    String? clubLogoUrl,
    String? sport,
    String? category,
    Map<String, String>? memberRoles,
  }) {
    return Team(
      id: id ?? this.id,
      clubId: clubId ?? this.clubId,
      country: country ?? this.country,
      club: club ?? this.club,
      imageUrl: imageUrl ?? this.imageUrl,
      clubLogoUrl: clubLogoUrl ?? this.clubLogoUrl,
      sport: sport ?? this.sport,
      category: category ?? this.category,
      memberRoles: memberRoles ?? this.memberRoles,
    );
  }

  String get displayImage => imageUrl ?? clubLogoUrl ?? 'assets/profile.png';
}
