class Member {
  final String userId;
  final String email;
  final String name;
  final String role;
  final String image;
  final String? profileImageUrl;
  final int age;
  final String? position;
  final int? jerseyNumber;

  String? fitnessPdfUrl;
  String? fitnessPdfName;
  String? analysisPdfUrl;
  String? analysisPdfName;
  String? medicalPdfUrl;
  String? medicalPdfName;
  String? videoUrl;
  String? videoFileName;

  String medicalNotes;
  String injuryType;
  String absencePeriod;
  bool injuryFlag;

  bool isInSquad;

  Member({
    this.userId = '',
    this.email = '',
    required this.name,
    required this.role,
    this.image = 'assets/profile.png',
    this.profileImageUrl,
    this.age = 0,
    this.position,
    this.jerseyNumber,
    this.fitnessPdfUrl,
    this.fitnessPdfName,
    this.analysisPdfUrl,
    this.analysisPdfName,
    this.medicalPdfUrl,
    this.medicalPdfName,
    this.videoUrl,
    this.videoFileName,
    this.medicalNotes = '',
    this.injuryType = '',
    this.absencePeriod = '',
    this.injuryFlag = false,
    this.isInSquad = false,
  });

  bool get isInjured =>
      injuryFlag ||
      medicalPdfUrl != null &&
          medicalPdfUrl!.isNotEmpty &&
          injuryType.isNotEmpty;

  Member copyWith({
    String? userId,
    String? email,
    String? name,
    String? role,
    String? image,
    String? profileImageUrl,
    int? age,
    String? position,
    int? jerseyNumber,
    String? fitnessPdfUrl,
    String? fitnessPdfName,
    String? analysisPdfUrl,
    String? analysisPdfName,
    String? medicalPdfUrl,
    String? medicalPdfName,
    String? videoUrl,
    String? videoFileName,
    String? medicalNotes,
    String? injuryType,
    String? absencePeriod,
    bool? injuryFlag,
    bool? isInSquad,
  }) {
    return Member(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      image: image ?? this.image,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      age: age ?? this.age,
      position: position ?? this.position,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      fitnessPdfUrl: fitnessPdfUrl ?? this.fitnessPdfUrl,
      fitnessPdfName: fitnessPdfName ?? this.fitnessPdfName,
      analysisPdfUrl: analysisPdfUrl ?? this.analysisPdfUrl,
      analysisPdfName: analysisPdfName ?? this.analysisPdfName,
      medicalPdfUrl: medicalPdfUrl ?? this.medicalPdfUrl,
      medicalPdfName: medicalPdfName ?? this.medicalPdfName,
      videoUrl: videoUrl ?? this.videoUrl,
      videoFileName: videoFileName ?? this.videoFileName,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      injuryType: injuryType ?? this.injuryType,
      absencePeriod: absencePeriod ?? this.absencePeriod,
      injuryFlag: injuryFlag ?? this.injuryFlag,
      isInSquad: isInSquad ?? this.isInSquad,
    );
  }
}
