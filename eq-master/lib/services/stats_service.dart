import 'dart:typed_data';

import 'api_client.dart';

class StatsService {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> getTeamAggregates(
      String clubId, String teamId) async {
    final json = await _api.get('/clubs/$clubId/teams/$teamId/stats');
    return Map<String, dynamic>.from(json as Map);
  }

  Future<List<dynamic>> getMatchHistory(String clubId, String teamId) async {
    final json = await _api.get('/clubs/$clubId/teams/$teamId/stats/matches');
    return json as List<dynamic>;
  }

  Future<dynamic> getMatchStats(String clubId, String teamId, String eventId) {
    return _api.get('/clubs/$clubId/teams/$teamId/stats/matches/$eventId');
  }

  Future<void> deleteMatchStats(
      String clubId, String teamId, String eventId) async {
    await _api.delete('/clubs/$clubId/teams/$teamId/stats/matches/$eventId');
  }

  Future<dynamic> getPlayerAggregate(
      String clubId, String teamId, String playerId) {
    return _api.get('/clubs/$clubId/teams/$teamId/stats/players/$playerId');
  }

  Future<List<dynamic>> getPlayerMatchHistory(
      String clubId, String teamId, String playerId) async {
    final json =
        await _api.get('/clubs/$clubId/teams/$teamId/stats/players/$playerId/matches');
    return json as List<dynamic>;
  }

  Future<dynamic> createStats(
      String clubId, String teamId, Map<String, dynamic> body) {
    return _api.post('/clubs/$clubId/teams/$teamId/stats', body: body);
  }

  Future<dynamic> uploadStatsFile(
      String clubId, String teamId, String eventId, String filePath, String fileName) {
    return _api.uploadFile(
      '/clubs/$clubId/teams/$teamId/stats/upload',
      fileField: 'file',
      filePath: filePath,
      fileName: fileName,
      fields: {'eventId': eventId},
    );
  }

  // ── Basketball-specific endpoints ──

  Future<Map<String, dynamic>> extractBasketballPdf(
      String clubId, String teamId, String? filePath, Uint8List? fileBytes, String fileName) async {
    final json = await _api.uploadFile(
      '/clubs/$clubId/teams/$teamId/stats/basketball/extract',
      fileField: 'file',
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> createBasketballStats(
      String clubId, String teamId, Map<String, dynamic> body) async {
    final json = await _api.post(
      '/clubs/$clubId/teams/$teamId/stats/basketball',
      body: body,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> confirmBasketballUpload(
      String clubId, String teamId, Map<String, dynamic> body) async {
    final json = await _api.post(
      '/clubs/$clubId/teams/$teamId/stats/basketball/confirm',
      body: body,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> getBasketballAggregates(
      String clubId, String teamId) async {
    final json = await _api.get(
      '/clubs/$clubId/teams/$teamId/stats/basketball',
    );
    return Map<String, dynamic>.from(json as Map);
  }

  // ── Raw stats PDF (stored for the future "Ask Equipo" chatbot) ──

  /// Attach the original stats PDF to a recorded match so it can be served
  /// later. Best-effort: callers should not block the upload flow on this.
  Future<Map<String, dynamic>> uploadRawStatsPdf(
      String clubId, String teamId, String eventId, String? filePath, Uint8List? fileBytes, String fileName) async {
    final json = await _api.uploadFile(
      '/clubs/$clubId/teams/$teamId/stats/matches/$eventId/raw-pdf',
      fileField: 'file',
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> getMatchContext(
      String clubId, String teamId, String eventId) async {
    final json = await _api.get(
      '/clubs/$clubId/teams/$teamId/stats/matches/$eventId/context',
    );
    return Map<String, dynamic>.from(json as Map);
  }

  /// Download the stored raw stats PDF for a match.
  Future<({Uint8List bytes, String contentType, String fileName})>
      downloadRawStatsPdf(
          String clubId, String teamId, String eventId) async {
    final response = await _api.getFile(
      '/clubs/$clubId/teams/$teamId/stats/matches/$eventId/raw-pdf',
    );
    final contentType =
        response.headers['content-type'] ?? 'application/pdf';
    var fileName = 'stats.pdf';
    final disposition = response.headers['content-disposition'];
    if (disposition != null) {
      final pattern = RegExp('filename\\*?=["\\x27]?([^"\\x27;\\r\\n]+)');
      final match = pattern.firstMatch(disposition);
      if (match != null) fileName = match.group(1)!;
    }
    return (
      bytes: response.bodyBytes,
      contentType: contentType,
      fileName: fileName,
    );
  }
}
