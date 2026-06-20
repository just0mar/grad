import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import '../models/api_models.dart';
import 'api_client.dart';

class TeamService {
  final ApiClient _api = ApiClient.instance;

  Future<List<TeamDto>> getMyTeams() async {
    final json = await _api.get('/teams/my');
    return (json as List)
        .map((e) => TeamDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<TeamDto>> getClubTeams(String clubId) async {
    final json = await _api.get('/clubs/$clubId/teams');
    return (json as List)
        .map((e) => TeamDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<TeamMemberDto>> getTeamMembers(
      String clubId, String teamId) async {
    final json = await _api.get('/clubs/$clubId/teams/$teamId/members');
    return (json as List)
        .map((e) => TeamMemberDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<TeamCategoryDto>> getCategories() async {
    final json = await _api.get('/teams/categories');
    return (json as List)
        .map((e) =>
            TeamCategoryDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<TeamDto> createTeam(
    String clubId,
    Map<String, dynamic> request, {
    PlatformFile? image,
  }) async {
    final json = image == null
        ? await _api.post('/clubs/$clubId/teams', body: request)
        : await _api.uploadFile(
            '/clubs/$clubId/teams',
            fileField: 'image',
            fileBytes: image.bytes,
            filePath: kIsWeb ? null : image.path,
            fileName: image.name,
            fields: request.map((key, value) => MapEntry(key, '$value')),
          );
    return TeamDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> leaveTeam(String clubId, String teamId, String currentUserId) {
    return _api.delete('/clubs/$clubId/teams/$teamId/members/$currentUserId');
  }
}
