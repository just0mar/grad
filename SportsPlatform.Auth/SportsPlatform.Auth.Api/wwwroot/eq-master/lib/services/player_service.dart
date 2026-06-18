import '../models/api_models.dart';
import 'api_client.dart';

class PlayerService {
  final ApiClient _api = ApiClient.instance;

  Future<PlayerProfileDto> getMyProfile() async {
    final json = await _api.get('/players/me/profile');
    return PlayerProfileDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<PlayerProfileDto> getPlayerProfile(
      String clubId, String teamId, String playerId) async {
    final json =
        await _api.get('/clubs/$clubId/teams/$teamId/players/$playerId/profile');
    return PlayerProfileDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<PlayerProfileDto> upsertPlayerProfile(
      String clubId, String teamId, String playerId, Map<String, dynamic> body) async {
    final json = await _api.post(
      '/clubs/$clubId/teams/$teamId/players/$playerId/profile',
      body: body,
    );
    return PlayerProfileDto.fromJson(Map<String, dynamic>.from(json as Map));
  }
}
