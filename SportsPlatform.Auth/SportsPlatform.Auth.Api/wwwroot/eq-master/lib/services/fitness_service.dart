import '../models/api_models.dart';
import 'api_client.dart';

class FitnessService {
  final ApiClient _api = ApiClient.instance;

  Future<List<FitnessRecordDto>> getPlayerFitness(
      String clubId, String teamId, String playerId) async {
    final json =
        await _api.get('/clubs/$clubId/teams/$teamId/players/$playerId/fitness');
    return (json as List)
        .map((e) =>
            FitnessRecordDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<FitnessRecordDto> createFitnessRecord(
      String clubId, String teamId, String playerId, Map<String, dynamic> body) async {
    final json = await _api.post(
      '/clubs/$clubId/teams/$teamId/players/$playerId/fitness',
      body: body,
    );
    return FitnessRecordDto.fromJson(Map<String, dynamic>.from(json as Map));
  }
}
