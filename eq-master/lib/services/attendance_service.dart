import '../models/api_models.dart';
import 'api_client.dart';

class AttendanceService {
  final ApiClient _api = ApiClient.instance;

  Future<List<AttendanceDto>> getEventAttendance(
      String clubId, String teamId, String eventId) async {
    final json =
        await _api.get('/clubs/$clubId/teams/$teamId/events/$eventId/attendance');
    return (json as List)
        .map((e) => AttendanceDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<dynamic> recordAttendance(
      String clubId, String teamId, String eventId, Map<String, dynamic> body) {
    return _api.post(
      '/clubs/$clubId/teams/$teamId/events/$eventId/attendance',
      body: body,
    );
  }

  Future<dynamic> updateAttendance(String clubId, String teamId, String eventId,
      String playerId, Map<String, dynamic> body) {
    return _api.put(
      '/clubs/$clubId/teams/$teamId/events/$eventId/attendance/$playerId',
      body: body,
    );
  }
}
