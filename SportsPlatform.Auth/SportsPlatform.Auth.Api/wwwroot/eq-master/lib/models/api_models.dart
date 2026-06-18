import 'dart:convert';

class AuthResponse {
  final String? accessToken;
  final String? refreshToken;
  final UserInfo? user;
  final bool requiresProfileCompletion;

  const AuthResponse({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.requiresProfileCompletion = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    accessToken: json['accessToken']?.toString(),
    refreshToken: json['refreshToken']?.toString(),
    requiresProfileCompletion:
        json['requiresProfileCompletion'] as bool? ?? false,
    user: json['user'] is Map<String, dynamic>
        ? UserInfo.fromJson(json['user'] as Map<String, dynamic>)
        : null,
  );
}

class UserInfo {
  final String userId;
  final String name;
  final String email;
  final String? username;
  final String? phone;
  final String? dob;
  final String? bio;
  final int? yearsOfExperience;
  final String? profileImageUrl;

  const UserInfo({
    required this.userId,
    required this.name,
    required this.email,
    this.username,
    this.phone,
    this.dob,
    this.bio,
    this.yearsOfExperience,
    this.profileImageUrl,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    userId: (json['userId'] ?? json['id'] ?? '').toString(),
    name: (json['name'] ?? json['fullName'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    username: json['username']?.toString(),
    phone: (json['phone'] ?? json['phoneNumber'])?.toString(),
    dob: json['dob']?.toString(),
    bio: json['bio']?.toString(),
    yearsOfExperience: json['yearsOfExperience'] as int?,
    profileImageUrl: json['profileImageUrl']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'email': email,
    if (username != null) 'username': username,
    if (phone != null) 'phoneNumber': phone,
    if (dob != null) 'dob': dob,
    if (bio != null) 'bio': bio,
    if (yearsOfExperience != null) 'yearsOfExperience': yearsOfExperience,
    if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
  };

  UserInfo copyWith({
    String? name,
    String? email,
    String? username,
    String? phone,
    String? dob,
    String? bio,
    int? yearsOfExperience,
    String? profileImageUrl,
  }) {
    return UserInfo(
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      dob: dob ?? this.dob,
      bio: bio ?? this.bio,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}

class ClubDto {
  final String clubId;
  final String name;
  final String? logoUrl;
  final String? location;
  final double? locationLatitude;
  final double? locationLongitude;
  final String? myRole;

  const ClubDto({
    required this.clubId,
    required this.name,
    this.logoUrl,
    this.location,
    this.locationLatitude,
    this.locationLongitude,
    this.myRole,
  });

  factory ClubDto.fromJson(Map<String, dynamic> json) => ClubDto(
    clubId: (json['clubId'] ?? json['id'] ?? '').toString(),
    name: (json['name'] ?? json['clubName'] ?? '').toString(),
    logoUrl: json['logoUrl']?.toString(),
    location: json['location']?.toString(),
    locationLatitude: (json['locationLatitude'] as num?)?.toDouble(),
    locationLongitude: (json['locationLongitude'] as num?)?.toDouble(),
    myRole: json['myRole']?.toString() ?? json['role']?.toString(),
  );
}

class TeamDto {
  final String teamId;
  final String? clubId;
  final String teamName;
  final String? clubName;
  final String? imageUrl;
  final String? clubLogoUrl;
  final String? categoryId;
  final String? categoryName;
  final String? myRole;

  const TeamDto({
    required this.teamId,
    this.clubId,
    required this.teamName,
    this.clubName,
    this.imageUrl,
    this.clubLogoUrl,
    this.categoryId,
    this.categoryName,
    this.myRole,
  });

  factory TeamDto.fromJson(Map<String, dynamic> json) => TeamDto(
    teamId: (json['teamId'] ?? json['id'] ?? '').toString(),
    clubId: json['clubId']?.toString(),
    teamName: (json['teamName'] ?? json['name'] ?? '').toString(),
    clubName: json['clubName']?.toString(),
    imageUrl: json['imageUrl']?.toString(),
    clubLogoUrl: json['clubLogoUrl']?.toString(),
    categoryId: json['categoryId']?.toString(),
    categoryName: json['categoryName']?.toString(),
    myRole: json['myRole']?.toString() ?? json['role']?.toString(),
  );
}

class TeamMemberDto {
  final String userId;
  final String name;
  final String email;
  final String? profileImageUrl;
  final String role;
  final String? position;
  final int? jerseyNumber;
  final bool isInjured;
  final String? injuryType;

  const TeamMemberDto({
    required this.userId,
    required this.name,
    required this.email,
    this.profileImageUrl,
    required this.role,
    this.position,
    this.jerseyNumber,
    this.isInjured = false,
    this.injuryType,
  });

  factory TeamMemberDto.fromJson(Map<String, dynamic> json) => TeamMemberDto(
    userId: (json['userId'] ?? json['id'] ?? '').toString(),
    name: (json['name'] ?? json['fullName'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    profileImageUrl: json['profileImageUrl']?.toString(),
    role: (json['role'] ?? '').toString(),
    position: json['position']?.toString(),
    jerseyNumber: json['jerseyNumber'] != null
        ? (json['jerseyNumber'] is int
            ? json['jerseyNumber'] as int
            : (json['jerseyNumber'] as num).toInt())
        : null,
    isInjured: json['isInjured'] == true,
    injuryType: json['injuryType']?.toString(),
  );
}

class TeamCategoryDto {
  final String categoryId;
  final String name;

  const TeamCategoryDto({required this.categoryId, required this.name});

  factory TeamCategoryDto.fromJson(Map<String, dynamic> json) =>
      TeamCategoryDto(
        categoryId: (json['categoryId'] ?? json['id'] ?? '').toString(),
        name: (json['name'] ?? json['label'] ?? '').toString(),
      );
}

class SeasonDto {
  final String seasonId;
  final String label;

  const SeasonDto({required this.seasonId, required this.label});

  factory SeasonDto.fromJson(Map<String, dynamic> json) => SeasonDto(
    seasonId: (json['seasonId'] ?? json['id'] ?? '').toString(),
    label: (json['label'] ?? json['name'] ?? '').toString(),
  );
}

class EventDto {
  final String eventId;
  final String teamId;
  final String seasonId;
  final String title;
  final String eventType;
  final DateTime startAt;
  final DateTime? endAt;
  final String? location;
  final double? locationLatitude;
  final double? locationLongitude;
  final String? description;
  final String? recurrenceRule;
  final DateTime? recurrenceEndDate;

  const EventDto({
    required this.eventId,
    required this.teamId,
    required this.seasonId,
    required this.title,
    required this.eventType,
    required this.startAt,
    this.endAt,
    this.location,
    this.locationLatitude,
    this.locationLongitude,
    this.description,
    this.recurrenceRule,
    this.recurrenceEndDate,
  });

  factory EventDto.fromJson(Map<String, dynamic> json) => EventDto(
    eventId: (json['eventId'] ?? json['id'] ?? '').toString(),
    teamId: (json['teamId'] ?? '').toString(),
    seasonId: (json['seasonId'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    eventType: (json['eventType'] ?? json['type'] ?? '').toString(),
    // startAt/endAt are instants stored as UTC on the server; convert to the
    // device's local zone so the displayed time matches what the user picked.
    startAt: DateTime.parse(
      (json['startAt'] ?? DateTime.now().toIso8601String()).toString(),
    ).toLocal(),
    endAt: json['endAt'] == null
        ? null
        : DateTime.tryParse(json['endAt'].toString())?.toLocal(),
    location: json['location']?.toString(),
    locationLatitude: (json['locationLatitude'] as num?)?.toDouble(),
    locationLongitude: (json['locationLongitude'] as num?)?.toDouble(),
    description: json['description']?.toString(),
    recurrenceRule: json['recurrenceRule']?.toString(),
    recurrenceEndDate: json['recurrenceEndDate'] == null
        ? null
        : DateTime.tryParse(json['recurrenceEndDate'].toString()),
  );
}

class AnnouncementDto {
  final String announcementId;
  final String title;
  final String content;
  final String priority;
  final String creatorName;
  final String creatorRole;
  final String? creatorImageUrl;
  final String? createdBy;
  final String? imageUrl;
  final DateTime createdAt;

  const AnnouncementDto({
    required this.announcementId,
    required this.title,
    required this.content,
    required this.priority,
    required this.creatorName,
    required this.creatorRole,
    this.creatorImageUrl,
    this.createdBy,
    this.imageUrl,
    required this.createdAt,
  });

  factory AnnouncementDto.fromJson(Map<String, dynamic> json) =>
      AnnouncementDto(
        announcementId: (json['announcementId'] ?? json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        content: (json['content'] ?? '').toString(),
        priority: (json['priority'] ?? 'Normal').toString(),
        creatorName: (json['creatorName'] ?? '').toString(),
        creatorRole: (json['creatorRole'] ?? '').toString(),
        creatorImageUrl: json['creatorImageUrl']?.toString(),
        createdBy: json['createdBy']?.toString(),
        imageUrl: json['imageUrl']?.toString(),
        createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      );
}

class InvitationDto {
  final String invitationId;
  final String token;
  final String email;
  final String role;
  final String clubName;
  final String? teamName;
  final String? playerPosition;
  final int? jerseyNumber;
  final String inviterName;
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  const InvitationDto({
    required this.invitationId,
    required this.token,
    required this.email,
    required this.role,
    required this.clubName,
    this.teamName,
    this.playerPosition,
    this.jerseyNumber,
    required this.inviterName,
    required this.status,
    this.expiresAt,
    this.createdAt,
  });

  factory InvitationDto.fromJson(Map<String, dynamic> json) => InvitationDto(
    invitationId: (json['invitationId'] ?? json['id'] ?? '').toString(),
    token: (json['token'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    role: (json['role'] ?? '').toString(),
    clubName: (json['clubName'] ?? '').toString(),
    teamName: json['teamName']?.toString(),
    playerPosition: json['playerPosition']?.toString(),
    jerseyNumber: json['jerseyNumber'] as int?,
    inviterName: (json['inviterName'] ?? '').toString(),
    status: (json['status'] ?? '').toString(),
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.tryParse(json['expiresAt'].toString()),
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.tryParse(json['createdAt'].toString()),
  );
}

class PlayerProfileDto {
  final String playerId;
  final String userId;
  final String name;
  final String email;
  final String? username;
  final String? bio;
  final String? profileImageUrl;
  final String? dob;
  final String? position;
  final int? jerseyNumber;
  final double? height;
  final double? weight;

  const PlayerProfileDto({
    required this.playerId,
    required this.userId,
    required this.name,
    required this.email,
    this.username,
    this.bio,
    this.profileImageUrl,
    this.dob,
    this.position,
    this.jerseyNumber,
    this.height,
    this.weight,
  });

  factory PlayerProfileDto.fromJson(Map<String, dynamic> json) =>
      PlayerProfileDto(
        playerId: (json['playerId'] ?? '').toString(),
        userId: (json['userId'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        username: json['username']?.toString(),
        bio: json['bio']?.toString(),
        profileImageUrl: json['profileImageUrl']?.toString(),
        dob: json['dob']?.toString(),
        position: json['position']?.toString(),
        jerseyNumber: json['jerseyNumber'] as int?,
        height: (json['height'] as num?)?.toDouble(),
        weight: (json['weight'] as num?)?.toDouble(),
      );
}

class FitnessRecordDto {
  final String recordId;
  final String playerUserId;
  final String playerName;
  final double? height;
  final double? weight;
  final double? bmi;
  final double? bodyFatPct;
  final double? speedTestResult;
  final double? enduranceScore;
  final String? customTestName;
  final double? customTestResult;
  final DateTime recordedAt;

  const FitnessRecordDto({
    required this.recordId,
    required this.playerUserId,
    required this.playerName,
    this.height,
    this.weight,
    this.bmi,
    this.bodyFatPct,
    this.speedTestResult,
    this.enduranceScore,
    this.customTestName,
    this.customTestResult,
    required this.recordedAt,
  });

  factory FitnessRecordDto.fromJson(Map<String, dynamic> json) =>
      FitnessRecordDto(
        recordId:
            (json['recordId'] ??
                    json['fitnessRecordId'] ??
                    json['fitnessId'] ??
                    '')
                .toString(),
        playerUserId: (json['playerUserId'] ?? '').toString(),
        playerName: (json['playerName'] ?? '').toString(),
        height: (json['height'] as num?)?.toDouble(),
        weight: (json['weight'] as num?)?.toDouble(),
        bmi: (json['bmi'] as num?)?.toDouble(),
        bodyFatPct: (json['bodyFatPct'] as num?)?.toDouble(),
        speedTestResult: (json['speedTestResult'] as num?)?.toDouble(),
        enduranceScore: (json['enduranceScore'] as num?)?.toDouble(),
        customTestName: json['customTestName']?.toString(),
        customTestResult: (json['customTestResult'] as num?)?.toDouble(),
        recordedAt:
            DateTime.tryParse(
              '${json['recordedAt'] ?? json['testDate'] ?? json['createdAt']}',
            ) ??
            DateTime.now(),
      );
}

class MedicalRecordDto {
  final String recordId;
  final String playerUserId;
  final String playerName;
  final String? injuryType;
  final String? diagnosis;
  final String? expectedReturnDate;
  final String? recoveryTips;
  final bool isClearedToPlay;
  final DateTime recordedAt;
  final DateTime? updatedAt;
  final List<MedicalDocumentRequestDto> documentRequests;

  const MedicalRecordDto({
    required this.recordId,
    required this.playerUserId,
    required this.playerName,
    this.injuryType,
    this.diagnosis,
    this.expectedReturnDate,
    this.recoveryTips,
    this.isClearedToPlay = false,
    required this.recordedAt,
    this.updatedAt,
    this.documentRequests = const [],
  });

  factory MedicalRecordDto.fromJson(Map<String, dynamic> json) =>
      MedicalRecordDto(
        recordId: (json['recordId'] ?? json['medicalRecordId'] ?? '')
            .toString(),
        playerUserId: (json['playerUserId'] ?? '').toString(),
        playerName: (json['playerName'] ?? '').toString(),
        injuryType: json['injuryType']?.toString(),
        diagnosis: json['diagnosis']?.toString(),
        expectedReturnDate: json['expectedReturnDate']?.toString(),
        recoveryTips: json['recoveryTips']?.toString(),
        isClearedToPlay:
            json['isCleared'] == true || json['isClearedToPlay'] == true,
        recordedAt:
            DateTime.tryParse('${json['recordDate'] ?? json['recordedAt']}') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
        documentRequests: (json['documentRequests'] as List<dynamic>? ?? [])
            .map(
              (e) => MedicalDocumentRequestDto.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
}

class MedicalDocumentRequestDto {
  final String requestId;
  final String? recordId;
  final String documentName;
  final String? note;
  final String status;
  final String? requestedByName;
  final String? uploadedByName;
  final String? fileName;
  final String? contentType;
  final int? fileSizeBytes;
  final DateTime? requestedAt;
  final DateTime? uploadedAt;
  final String? downloadUrl;

  const MedicalDocumentRequestDto({
    required this.requestId,
    this.recordId,
    required this.documentName,
    this.note,
    required this.status,
    this.requestedByName,
    this.uploadedByName,
    this.fileName,
    this.contentType,
    this.fileSizeBytes,
    this.requestedAt,
    this.uploadedAt,
    this.downloadUrl,
  });

  factory MedicalDocumentRequestDto.fromJson(Map<String, dynamic> json) =>
      MedicalDocumentRequestDto(
        requestId: (json['requestId'] ?? json['id'] ?? '').toString(),
        recordId: json['recordId']?.toString(),
        documentName: (json['documentName'] ?? json['documentType'] ?? '')
            .toString(),
        note: json['note']?.toString() ?? json['description']?.toString(),
        status: (json['status'] ?? '').toString(),
        requestedByName: json['requestedByName']?.toString(),
        uploadedByName: json['uploadedByName']?.toString(),
        fileName:
            json['fileName']?.toString() ??
            json['originalFileName']?.toString(),
        contentType: json['contentType']?.toString(),
        fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
        requestedAt: DateTime.tryParse('${json['requestedAt'] ?? ''}'),
        uploadedAt: DateTime.tryParse('${json['uploadedAt'] ?? ''}'),
        downloadUrl: json['downloadUrl']?.toString(),
      );
}

class PlanDto {
  final String planId;
  final String? createdBy;
  final String title;
  final String? description;
  final String content;
  final String? visibility;
  final String creatorName;

  /// "Offensive" or "Defensive"
  final String category;

  /// Document attachments associated with this plan.
  final List<PlanDocumentDto> documents;

  /// Serialised tactical-board state (JSON string of player positions).
  final String? tacticalBoardData;

  const PlanDto({
    required this.planId,
    this.createdBy,
    required this.title,
    this.description,
    this.content = '',
    this.visibility,
    required this.creatorName,
    this.category = 'Offensive',
    this.documents = const [],
    this.tacticalBoardData,
  });

  factory PlanDto.fromJson(Map<String, dynamic> json) {
    final content = (json['content'] ?? '').toString();
    final meta = _decodePlanContentMeta(content);
    return PlanDto(
      planId: (json['planId'] ?? json['id'] ?? '').toString(),
      createdBy: json['createdBy']?.toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      content: content,
      visibility: json['visibility']?.toString(),
      creatorName: (json['creatorName'] ?? '').toString(),
      category: (json['category'] ?? meta['category'] ?? 'Offensive')
          .toString(),
      documents:
          (json['documents'] as List?)
              ?.map(
                (e) => PlanDocumentDto.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      tacticalBoardData:
          (json['tacticalBoardData'] ?? meta['tacticalBoardData'])?.toString(),
    );
  }
}

Map<String, dynamic> _decodePlanContentMeta(String content) {
  if (content.isEmpty) return const {};
  try {
    final decoded = jsonDecode(content);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return const {};
}

class PlanDocumentDto {
  final String documentId;
  final String fileName;
  final String? contentType;
  final int? fileSizeBytes;
  final DateTime? uploadedAt;

  const PlanDocumentDto({
    required this.documentId,
    required this.fileName,
    this.contentType,
    this.fileSizeBytes,
    this.uploadedAt,
  });

  factory PlanDocumentDto.fromJson(Map<String, dynamic> json) =>
      PlanDocumentDto(
        documentId: (json['documentId'] ?? json['id'] ?? '').toString(),
        fileName: (json['fileName'] ?? 'document').toString(),
        contentType: json['contentType']?.toString(),
        fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
        uploadedAt: DateTime.tryParse('${json['uploadedAt'] ?? ''}'),
      );
}

class LineupDto {
  final String lineupId;
  final String? eventId;
  final String name;
  final String creatorName;
  final List<LineupPlayerDto> players;

  const LineupDto({
    required this.lineupId,
    this.eventId,
    required this.name,
    required this.creatorName,
    this.players = const [],
  });

  factory LineupDto.fromJson(Map<String, dynamic> json) => LineupDto(
    lineupId: (json['lineupId'] ?? json['id'] ?? '').toString(),
    eventId: json['eventId']?.toString(),
    name: (json['name'] ?? json['title'] ?? '').toString(),
    creatorName: (json['creatorName'] ?? '').toString(),
    players: (json['players'] as List<dynamic>? ?? [])
        .map(
          (e) => LineupPlayerDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
  );
}

class LineupPlayerDto {
  final String userId;
  final String name;
  final String unit;
  final String position;

  const LineupPlayerDto({
    required this.userId,
    required this.name,
    this.unit = 'Starting',
    this.position = '',
  });

  factory LineupPlayerDto.fromJson(Map<String, dynamic> json) =>
      LineupPlayerDto(
        userId: (json['userId'] ?? json['playerUserId'] ?? '').toString(),
        name: (json['name'] ?? json['playerName'] ?? '').toString(),
        unit: (json['unit'] ?? 'Starting').toString(),
        position: (json['position'] ?? '').toString(),
      );
}

class AttendanceDto {
  final String attendanceId;
  final String playerUserId;
  final String playerName;
  final String status;

  const AttendanceDto({
    required this.attendanceId,
    required this.playerUserId,
    required this.playerName,
    required this.status,
  });

  factory AttendanceDto.fromJson(Map<String, dynamic> json) => AttendanceDto(
    attendanceId: (json['attendanceId'] ?? json['id'] ?? '').toString(),
    playerUserId: (json['playerUserId'] ?? '').toString(),
    playerName: (json['playerName'] ?? '').toString(),
    status: (json['status'] ?? '').toString(),
  );
}

class EventDocumentDto {
  final String documentId;
  final String eventId;
  final String originalFileName;
  final String contentType;
  final int fileSize;
  final String? uploadedBy;
  final String? uploadedByRole;
  final String? description;
  final DateTime createdAt;

  const EventDocumentDto({
    required this.documentId,
    required this.eventId,
    required this.originalFileName,
    required this.contentType,
    required this.fileSize,
    this.uploadedBy,
    this.uploadedByRole,
    this.description,
    required this.createdAt,
  });

  factory EventDocumentDto.fromJson(Map<String, dynamic> json) =>
      EventDocumentDto(
        documentId: (json['documentId'] ?? json['id'] ?? '').toString(),
        eventId: (json['eventId'] ?? '').toString(),
        originalFileName: (json['originalFileName'] ?? '').toString(),
        contentType: (json['contentType'] ?? '').toString(),
        fileSize: (json['fileSize'] is int)
            ? json['fileSize'] as int
            : int.tryParse(json['fileSize']?.toString() ?? '0') ?? 0,
        uploadedBy: json['uploadedBy']?.toString(),
        uploadedByRole: json['uploadedByRole']?.toString(),
        description: json['description']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class ConversationDto {
  final String conversationId;
  final bool isGroup;
  final String? title;
  final String? lastMessage;
  final String lastMessageType; // text, image, video, audio, document, location
  final int unreadCount;
  final List<ConversationParticipantDto> participants;

  const ConversationDto({
    required this.conversationId,
    this.isGroup = false,
    this.title,
    this.lastMessage,
    this.lastMessageType = 'text',
    this.unreadCount = 0,
    this.participants = const [],
  });

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    String lastMsgType = 'text';
    String? lastMsgContent;

    if (last is Map) {
      lastMsgContent = last['content']?.toString();
      lastMsgType = last['messageType']?.toString() ?? 'text';
      // Detect audio from filename if messageType is generic
      final fileName = (last['mediaFileName'] ?? '').toString().toLowerCase();
      if (lastMsgType == 'text' && fileName.isNotEmpty) {
        if (RegExp(r'\.(m4a|aac|mp3|wav|ogg|opus)$').hasMatch(fileName)) {
          lastMsgType = 'audio';
        } else if (RegExp(r'\.(png|jpe?g|gif|webp|bmp)$').hasMatch(fileName)) {
          lastMsgType = 'image';
        } else if (RegExp(
          r'\.(mp4|mov|m4v|webm|avi|mkv)$',
        ).hasMatch(fileName)) {
          lastMsgType = 'video';
        } else {
          lastMsgType = 'document';
        }
      }
    } else {
      lastMsgContent = last?.toString();
    }

    return ConversationDto(
      conversationId: (json['conversationId'] ?? json['id'] ?? '').toString(),
      isGroup: json['isGroup'] == true,
      title: json['title']?.toString() ?? json['name']?.toString(),
      lastMessage: lastMsgContent,
      lastMessageType: lastMsgType,
      unreadCount: json['unreadCount'] as int? ?? 0,
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map(
            (e) => ConversationParticipantDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class ConversationParticipantDto {
  final String userId;
  final String name;
  final String? profileImageUrl;

  const ConversationParticipantDto({
    required this.userId,
    required this.name,
    this.profileImageUrl,
  });

  factory ConversationParticipantDto.fromJson(Map<String, dynamic> json) =>
      ConversationParticipantDto(
        userId: (json['userId'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        profileImageUrl: json['profileImageUrl']?.toString(),
      );
}

class MessageDto {
  final String messageId;
  final String conversationId;
  final String senderUserId;
  final String senderName;
  final String content;
  final DateTime sentAt;
  final DateTime? editedAt;
  final bool isDeleted;
  final bool isRead;
  final String messageType;
  final String? mediaUrl;
  final String? mediaFileName;
  final double? locationLatitude;
  final double? locationLongitude;
  final String? locationLabel;
  final List<MessageReactionDto> reactions;
  final List<MessageSeenByDto> seenBy;
  final int seenByCount;
  final int requiredSeenCount;
  final bool seenByAll;

  const MessageDto({
    required this.messageId,
    required this.conversationId,
    required this.senderUserId,
    required this.senderName,
    required this.content,
    required this.sentAt,
    this.editedAt,
    this.isDeleted = false,
    this.isRead = false,
    this.messageType = 'text',
    this.mediaUrl,
    this.mediaFileName,
    this.locationLatitude,
    this.locationLongitude,
    this.locationLabel,
    this.reactions = const [],
    this.seenBy = const [],
    this.seenByCount = 0,
    this.requiredSeenCount = 0,
    this.seenByAll = false,
  });

  factory MessageDto.fromJson(Map<String, dynamic> json) => MessageDto(
    messageId: (json['messageId'] ?? json['id'] ?? '').toString(),
    conversationId: (json['conversationId'] ?? '').toString(),
    senderUserId: (json['senderUserId'] ?? '').toString(),
    senderName: (json['senderName'] ?? '').toString(),
    content: (json['content'] ?? '').toString(),
    sentAt: DateTime.tryParse('${json['sentAt']}') ?? DateTime.now(),
    editedAt: json['editedAt'] != null
        ? DateTime.tryParse('${json['editedAt']}')
        : null,
    isDeleted: json['isDeleted'] == true,
    isRead: json['isRead'] == true,
    messageType: (json['messageType'] ?? 'text').toString(),
    mediaUrl: json['mediaUrl']?.toString(),
    mediaFileName: json['mediaFileName']?.toString(),
    locationLatitude: (json['locationLatitude'] as num?)?.toDouble(),
    locationLongitude: (json['locationLongitude'] as num?)?.toDouble(),
    locationLabel: json['locationLabel']?.toString(),
    reactions: (json['reactions'] as List<dynamic>? ?? [])
        .map(
          (e) =>
              MessageReactionDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    seenBy: (json['seenBy'] as List<dynamic>? ?? [])
        .map(
          (e) => MessageSeenByDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    seenByCount: json['seenByCount'] as int? ?? 0,
    requiredSeenCount: json['requiredSeenCount'] as int? ?? 0,
    seenByAll: json['seenByAll'] == true || json['isRead'] == true,
  );
}

class MessageReactionDto {
  final String reactionId;
  final String userId;
  final String userName;
  final String emoji;

  const MessageReactionDto({
    required this.reactionId,
    required this.userId,
    required this.userName,
    required this.emoji,
  });

  factory MessageReactionDto.fromJson(Map<String, dynamic> json) =>
      MessageReactionDto(
        reactionId: (json['reactionId'] ?? '').toString(),
        userId: (json['userId'] ?? '').toString(),
        userName: (json['userName'] ?? '').toString(),
        emoji: (json['emoji'] ?? '').toString(),
      );
}

class MessageSeenByDto {
  final String userId;
  final String userName;
  final String? profileImageUrl;
  final DateTime readAt;

  const MessageSeenByDto({
    required this.userId,
    required this.userName,
    this.profileImageUrl,
    required this.readAt,
  });

  factory MessageSeenByDto.fromJson(Map<String, dynamic> json) =>
      MessageSeenByDto(
        userId: (json['userId'] ?? '').toString(),
        userName: (json['userName'] ?? '').toString(),
        profileImageUrl: json['profileImageUrl']?.toString(),
        readAt: DateTime.tryParse('${json['readAt']}') ?? DateTime.now(),
      );
}

class AppNotificationDto {
  final String notificationId;
  final String recipientUserId;
  final String? actorUserId;
  final String? actorName;
  final String? clubId;
  final String? teamId;
  final String? teamName;
  final String type;
  final String priority;
  final String deliveryPolicy;
  final String title;
  final String body;
  final String? targetType;
  final String? targetId;
  final String? targetRoute;
  final String? metadataJson;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotificationDto({
    required this.notificationId,
    required this.recipientUserId,
    this.actorUserId,
    this.actorName,
    this.clubId,
    this.teamId,
    this.teamName,
    required this.type,
    required this.priority,
    required this.deliveryPolicy,
    required this.title,
    required this.body,
    this.targetType,
    this.targetId,
    this.targetRoute,
    this.metadataJson,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotificationDto.fromJson(Map<String, dynamic> json) =>
      AppNotificationDto(
        notificationId: (json['notificationId'] ?? json['id'] ?? '').toString(),
        recipientUserId: (json['recipientUserId'] ?? '').toString(),
        actorUserId: json['actorUserId']?.toString(),
        actorName: json['actorName']?.toString(),
        clubId: json['clubId']?.toString(),
        teamId: json['teamId']?.toString(),
        teamName: json['teamName']?.toString(),
        type: (json['type'] ?? '').toString(),
        priority: (json['priority'] ?? 'Normal').toString(),
        deliveryPolicy: (json['deliveryPolicy'] ?? 'RealtimeIfConnected')
            .toString(),
        title: (json['title'] ?? '').toString(),
        body: (json['body'] ?? json['message'] ?? '').toString(),
        targetType: json['targetType']?.toString(),
        targetId: json['targetId']?.toString(),
        targetRoute: json['targetRoute']?.toString(),
        metadataJson: json['metadataJson']?.toString(),
        createdAt:
            DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
        readAt: DateTime.tryParse('${json['readAt'] ?? ''}'),
      );
}

class NotificationListDto {
  final List<AppNotificationDto> items;
  final int totalCount;
  final int unreadCount;

  const NotificationListDto({
    required this.items,
    required this.totalCount,
    required this.unreadCount,
  });

  factory NotificationListDto.fromJson(Map<String, dynamic> json) =>
      NotificationListDto(
        items: (json['items'] as List<dynamic>? ?? [])
            .map(
              (e) => AppNotificationDto.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}

class SearchResultDto {
  final String id;
  final String type;
  final String title;
  final String? subtitle;
  final String? clubId;
  final String? teamId;
  final String? targetId;
  final String? targetRoute;
  final String? imageUrl;
  final String? metadataJson;
  final DateTime? occurredAt;

  const SearchResultDto({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.clubId,
    this.teamId,
    this.targetId,
    this.targetRoute,
    this.imageUrl,
    this.metadataJson,
    this.occurredAt,
  });

  factory SearchResultDto.fromJson(Map<String, dynamic> json) =>
      SearchResultDto(
        id: (json['id'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        subtitle: json['subtitle']?.toString(),
        clubId: json['clubId']?.toString(),
        teamId: json['teamId']?.toString(),
        targetId: json['targetId']?.toString(),
        targetRoute: json['targetRoute']?.toString(),
        imageUrl: json['imageUrl']?.toString(),
        metadataJson: json['metadataJson']?.toString(),
        occurredAt: DateTime.tryParse('${json['occurredAt'] ?? ''}'),
      );
}

class SearchResponseDto {
  final String query;
  final String type;
  final int totalCount;
  final List<SearchResultDto> results;

  const SearchResponseDto({
    required this.query,
    required this.type,
    required this.totalCount,
    required this.results,
  });

  factory SearchResponseDto.fromJson(Map<String, dynamic> json) =>
      SearchResponseDto(
        query: (json['query'] ?? '').toString(),
        type: (json['type'] ?? 'all').toString(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        results: (json['results'] as List<dynamic>? ?? [])
            .map(
              (e) => SearchResultDto.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
}
