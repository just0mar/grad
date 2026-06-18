import '../models/api_models.dart';
import 'api_client.dart';

class AnnouncementService {
  final ApiClient _api = ApiClient.instance;

  Future<List<AnnouncementDto>> getTeamAnnouncements(
    String clubId,
    String teamId,
  ) async {
    final json = await _api.get('/clubs/$clubId/teams/$teamId/announcements');
    return (json as List)
        .map(
          (e) => AnnouncementDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<AnnouncementDto> createAnnouncement(
    String clubId,
    String teamId,
    Map<String, dynamic> request, {
    String? imagePath,
    String? imageFileName,
  }) async {
    final json = imagePath == null
        ? await _api.post(
            '/clubs/$clubId/teams/$teamId/announcements',
            body: request,
          )
        : await _api.uploadFile(
            '/clubs/$clubId/teams/$teamId/announcements',
            fileField: 'image',
            filePath: imagePath,
            fileName: imageFileName ?? 'announcement-image',
            fields: request.map((key, value) => MapEntry(key, '$value')),
          );
    return AnnouncementDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<AnnouncementDto> updateAnnouncement(
    String clubId,
    String teamId,
    String announcementId,
    Map<String, dynamic> request, {
    String? imagePath,
    String? imageFileName,
  }) async {
    final json = imagePath == null
        ? await _api.post(
            '/clubs/$clubId/teams/$teamId/announcements/$announcementId/update',
            body: request,
          )
        : await _api.uploadFile(
            '/clubs/$clubId/teams/$teamId/announcements/$announcementId/update',
            fileField: 'image',
            filePath: imagePath,
            fileName: imageFileName ?? 'announcement-image',
            fields: request.map((key, value) => MapEntry(key, '$value')),
          );
    return AnnouncementDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> deleteAnnouncement(
    String clubId,
    String teamId,
    String announcementId,
  ) async {
    await _api.post(
      '/clubs/$clubId/teams/$teamId/announcements/$announcementId/delete',
    );
  }
}
