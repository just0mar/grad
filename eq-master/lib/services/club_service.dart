import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

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
    PlatformFile? logo,
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
            fileBytes: logo.bytes,
            filePath: kIsWeb ? null : logo.path,
            fileName: logo.name,
            fields: fields,
          );
    return ClubDto.fromJson(Map<String, dynamic>.from(json as Map));
  }
}
