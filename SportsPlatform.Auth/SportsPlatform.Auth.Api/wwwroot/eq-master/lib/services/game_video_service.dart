import 'api_client.dart';

/// A game video uploaded to the server, as returned by the backend.
class GameVideoDto {
  final String videoId;
  final String eventId;
  final String teamId;
  final String title;
  final String originalFileName;
  final String contentType;
  final int fileSize;

  /// Relative path to the authenticated streaming endpoint for this video.
  final String streamPath;

  final String addedByUserId;
  final String addedByName;
  final String addedByRole;
  final bool canEdit;
  final DateTime? createdAt;

  const GameVideoDto({
    required this.videoId,
    required this.eventId,
    required this.teamId,
    required this.title,
    required this.originalFileName,
    required this.contentType,
    required this.fileSize,
    required this.streamPath,
    required this.addedByUserId,
    required this.addedByName,
    required this.addedByRole,
    required this.canEdit,
    required this.createdAt,
  });

  /// Absolute URL to stream this video, resolved against the API base URL.
  String? get streamUrl => ApiClient.resolveUrl(streamPath);

  factory GameVideoDto.fromJson(Map<String, dynamic> json) {
    return GameVideoDto(
      videoId: (json['videoId'] ?? '').toString(),
      eventId: (json['eventId'] ?? '').toString(),
      teamId: (json['teamId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      originalFileName: (json['originalFileName'] ?? '').toString(),
      contentType: (json['contentType'] ?? '').toString(),
      fileSize: (json['fileSize'] is int)
          ? json['fileSize'] as int
          : int.tryParse((json['fileSize'] ?? '0').toString()) ?? 0,
      streamPath: (json['streamPath'] ?? '').toString(),
      addedByUserId: (json['addedByUserId'] ?? '').toString(),
      addedByName: (json['addedByName'] ?? '').toString(),
      addedByRole: (json['addedByRole'] ?? '').toString(),
      canEdit: json['canEdit'] == true,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString())?.toLocal(),
    );
  }
}

class GameVideoService {
  final ApiClient _api = ApiClient.instance;

  /// Authorization headers a video player needs to stream a protected video.
  Future<Map<String, String>> streamHeaders() async {
    final token = await _api.getFreshAccessToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  /// Absolute stream URL with the access token appended as a query parameter.
  ///
  /// The native video player can't reliably send an Authorization header
  /// (especially on iOS), so the backend also accepts the token via
  /// `?access_token=` for video /stream endpoints.
  Future<String?> authorizedStreamUrl(GameVideoDto video) async {
    final base = video.streamUrl;
    if (base == null || base.isEmpty) return null;
    final token = await _api.getFreshAccessToken();
    if (token == null || token.isEmpty) return base;
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}access_token=${Uri.encodeQueryComponent(token)}';
  }

  Future<List<GameVideoDto>> getVideos(
    String clubId,
    String teamId,
    String eventId,
  ) async {
    final json = await _api.get(
      '/clubs/$clubId/teams/$teamId/events/$eventId/videos',
    );
    return (json as List)
        .map((e) => GameVideoDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Upload a video file. The backend stores it and returns its metadata.
  Future<GameVideoDto> uploadVideo(
    String clubId,
    String teamId,
    String eventId,
    String title,
    String filePath,
    String fileName,
  ) async {
    final json = await _api.uploadFile(
      '/clubs/$clubId/teams/$teamId/events/$eventId/videos',
      fileField: 'file',
      filePath: filePath,
      fileName: fileName,
      fields: {'title': title},
    );
    return GameVideoDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> deleteVideo(
    String clubId,
    String teamId,
    String eventId,
    String videoId,
  ) async {
    await _api.delete(
      '/clubs/$clubId/teams/$teamId/events/$eventId/videos/$videoId',
    );
  }
}
