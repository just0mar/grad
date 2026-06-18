import 'api_client.dart';

/// A coach note as returned by the backend.
class CoachNoteDto {
  final String noteId;
  final String eventId;
  final String teamId;
  final String body;
  final String authorUserId;
  final String authorName;
  final String authorRole;
  final String? authorAvatarUrl;
  final bool canEdit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CoachNoteDto({
    required this.noteId,
    required this.eventId,
    required this.teamId,
    required this.body,
    required this.authorUserId,
    required this.authorName,
    required this.authorRole,
    required this.authorAvatarUrl,
    required this.canEdit,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoachNoteDto.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    return CoachNoteDto(
      noteId: (json['noteId'] ?? '').toString(),
      eventId: (json['eventId'] ?? '').toString(),
      teamId: (json['teamId'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      authorUserId: (json['authorUserId'] ?? '').toString(),
      authorName: (json['authorName'] ?? '').toString(),
      authorRole: (json['authorRole'] ?? '').toString(),
      authorAvatarUrl: json['authorAvatarUrl']?.toString(),
      canEdit: json['canEdit'] == true,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}

class CoachNoteService {
  final ApiClient _api = ApiClient.instance;

  Future<List<CoachNoteDto>> getNotes(
    String clubId,
    String teamId,
    String eventId,
  ) async {
    final json = await _api.get(
      '/clubs/$clubId/teams/$teamId/events/$eventId/notes',
    );
    return (json as List)
        .map((e) => CoachNoteDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CoachNoteDto> createNote(
    String clubId,
    String teamId,
    String eventId,
    String body,
  ) async {
    final json = await _api.post(
      '/clubs/$clubId/teams/$teamId/events/$eventId/notes',
      body: {'body': body},
    );
    return CoachNoteDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<CoachNoteDto> updateNote(
    String clubId,
    String teamId,
    String eventId,
    String noteId,
    String body,
  ) async {
    final json = await _api.put(
      '/clubs/$clubId/teams/$teamId/events/$eventId/notes/$noteId',
      body: {'body': body},
    );
    return CoachNoteDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> deleteNote(
    String clubId,
    String teamId,
    String eventId,
    String noteId,
  ) async {
    await _api.delete(
      '/clubs/$clubId/teams/$teamId/events/$eventId/notes/$noteId',
    );
  }
}
