import 'dart:typed_data';

import '../models/api_models.dart';
import 'api_client.dart';

class EventDocumentService {
  final ApiClient _api = ApiClient.instance;

  Future<List<EventDocumentDto>> getEventDocuments(
    String clubId,
    String teamId,
    String eventId,
  ) async {
    final json = await _api.get(
      '/clubs/$clubId/teams/$teamId/events/$eventId/documents',
    );
    return (json as List)
        .map((e) =>
            EventDocumentDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<EventDocumentDto> uploadDocument(
    String clubId,
    String teamId,
    String eventId,
    String filePath,
    String fileName,
    String? description,
  ) async {
    final json = await _api.uploadFile(
      '/clubs/$clubId/teams/$teamId/events/$eventId/documents',
      fileField: 'file',
      filePath: filePath,
      fileName: fileName,
      fields: {
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return EventDocumentDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<({Uint8List bytes, String contentType, String fileName})>
      downloadDocument(String documentId) async {
    final response = await _api.getFile(
      '/events/documents/$documentId/download',
    );
    final contentType =
        response.headers['content-type'] ?? 'application/octet-stream';
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

  Future<void> deleteDocument(
    String clubId,
    String teamId,
    String eventId,
    String documentId,
  ) async {
    await _api.delete(
      '/clubs/$clubId/teams/$teamId/events/$eventId/documents/$documentId',
    );
  }
}
