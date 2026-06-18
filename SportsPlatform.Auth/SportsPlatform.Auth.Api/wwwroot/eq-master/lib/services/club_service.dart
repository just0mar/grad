import 'dart:io';

import '../models/api_models.dart';
import 'api_client.dart';

class ClubService {
  final ApiClient _api = ApiClient.instance;

  Future<List<ClubDto>> getMyClubs() async {
    final json = await _api.get('/clubs/my');
    return (json as List)
        .map((e) => ClubDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> leaveClub(String clubId, String currentUserId) {
    return _api.delete('/clubs/$clubId/members/$currentUserId');
  }

  Future<ClubDto> createClub(
    String name, {
    File? logo,
    String? location,
    double? locationLatitude,
    double? locationLongitude,
  }) async {
    final body = {
      'name': name,
      if (location?.trim().isNotEmpty == true) 'location': location!.trim(),
      if (locationLatitude != null) 'locationLatitude': locationLatitude,
      if (locationLongitude != null) 'locationLongitude': locationLongitude,
    };
    final fields = {
      'name': name,
      if (location?.trim().isNotEmpty == true) 'location': location!.trim(),
      if (locationLatitude != null)
        'locationLatitude': locationLatitude.toString(),
      if (locationLongitude != null)
        'locationLongitude': locationLongitude.toString(),
    };
    final json = logo == null
        ? await _api.post('/clubs', body: body)
        : await _api.uploadFile(
            '/clubs',
            fileField: 'logo',
            filePath: logo.path,
            fileName: logo.uri.pathSegments.isEmpty
                ? 'club-logo'
                : logo.uri.pathSegments.last,
            fields: fields,
          );
    return ClubDto.fromJson(Map<String, dynamic>.from(json as Map));
  }
}
