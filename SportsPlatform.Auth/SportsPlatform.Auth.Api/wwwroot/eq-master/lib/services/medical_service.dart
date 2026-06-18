import 'dart:typed_data';

import '../models/api_models.dart';
import 'api_client.dart';

class MedicalService {
  final ApiClient _api = ApiClient.instance;

  Future<List<MedicalRecordDto>> getPlayerMedical(
      String clubId, String teamId, String playerId) async {
    final json =
        await _api.get('/clubs/$clubId/teams/$teamId/players/$playerId/medical');
    return (json as List)
        .map((e) =>
            MedicalRecordDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<MedicalRecordDto> createMedicalRecord(
      String clubId, String teamId, String playerId, Map<String, dynamic> body) async {
    final json = await _api.post(
      '/clubs/$clubId/teams/$teamId/players/$playerId/medical',
      body: body,
    );
    return MedicalRecordDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<MedicalRecordDto> updateMedicalRecord(
      String clubId, String teamId, String recordId, Map<String, dynamic> body) async {
    final json = await _api.put(
      '/clubs/$clubId/teams/$teamId/medical/$recordId',
      body: body,
    );
    return MedicalRecordDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> updateClearance(
      String clubId, String teamId, String recordId, bool cleared) async {
    await _api.patch(
      '/clubs/$clubId/teams/$teamId/medical/$recordId/clearance',
      body: {'isCleared': cleared},
    );
  }

  Future<MedicalDocumentRequestDto> requestDocument(
      String clubId, String teamId, String recordId, Map<String, dynamic> body) async {
    final json = await _api.post(
      '/clubs/$clubId/teams/$teamId/medical/$recordId/document-requests',
      body: body,
    );
    return MedicalDocumentRequestDto.fromJson(
      Map<String, dynamic>.from(json as Map),
    );
  }

  Future<void> deleteMedicalRecord(
      String clubId, String teamId, String recordId) async {
    await _api.post('/clubs/$clubId/teams/$teamId/medical/$recordId/delete');
  }

  Future<dynamic> uploadDocument(
      String requestId, String filePath, String fileName) {
    return _api.uploadFile(
      '/players/me/medical/document-requests/$requestId/upload',
      fileField: 'file',
      filePath: filePath,
      fileName: fileName,
    );
  }

  /// Downloads the uploaded document bytes (authenticated).
  /// Returns a record with the bytes, content type, and file name.
  Future<({Uint8List bytes, String contentType, String fileName})>
      downloadDocument(String requestId) async {
    final response = await _api
        .getFile('/medical/document-requests/$requestId/download');
    final contentType =
        response.headers['content-type'] ?? 'application/octet-stream';
    // Try to extract filename from content-disposition header
    var fileName = 'document';
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
