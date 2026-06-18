import '../models/api_models.dart';
import 'api_client.dart';

class EventService {
  final ApiClient _api = ApiClient.instance;

  Future<SeasonDto> getCurrentTeamSeason(String clubId, String teamId) async {
    final json = await _api.get('/clubs/$clubId/teams/$teamId/seasons/current');
    return SeasonDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<List<EventDto>> getTeamEvents(
    String clubId,
    String teamId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{};
    if (from != null) query['from'] = from.toIso8601String();
    if (to != null) query['to'] = to.toIso8601String();
    final json = await _api.get(
      '/clubs/$clubId/teams/$teamId/events',
      queryParams: query.isEmpty ? null : query,
    );
    return (json as List)
        .map((e) => EventDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<EventDto> createEvent(
      String clubId, String teamId, Map<String, dynamic> request) async {
    final json =
        await _api.post('/clubs/$clubId/teams/$teamId/events', body: request);
    return EventDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<EventDto> getEvent(String clubId, String teamId, String eventId) async {
    final json = await _api.get('/clubs/$clubId/teams/$teamId/events/$eventId');
    return EventDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<EventDto> updateEvent(
      String clubId, String teamId, String eventId, Map<String, dynamic> request) async {
    final json = await _api.put(
      '/clubs/$clubId/teams/$teamId/events/$eventId',
      body: request,
    );
    return EventDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> deleteEvent(String clubId, String teamId, String eventId) async {
    await _api.delete('/clubs/$clubId/teams/$teamId/events/$eventId');
  }
}
