import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/api_models.dart';
import 'api_client.dart';

class PlanService {
  final ApiClient _api = ApiClient.instance;

  Future<List<PlanDto>> getTeamPlans(String clubId, String teamId) async {
    final json = await _api.get('/clubs/$clubId/teams/$teamId/plans');
    return (json as List)
        .map((e) => PlanDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<PlanDto> createPlan(
    String clubId,
    String teamId,
    Map<String, dynamic> body,
  ) async {
    final json = await _api.post(
      '/clubs/$clubId/teams/$teamId/plans',
      body: body,
    );
    return PlanDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<PlanDto> updatePlan(
    String clubId,
    String teamId,
    String planId,
    Map<String, dynamic> body,
  ) async {
    final json = await _api.put(
      '/clubs/$clubId/teams/$teamId/plans/$planId',
      body: body,
    );
    return PlanDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> deletePlan(String clubId, String teamId, String planId) async {
    await _api.delete('/clubs/$clubId/teams/$teamId/plans/$planId');
  }

  /// Upload a document attachment to a plan.
  Future<dynamic> uploadPlanDocument(
    String clubId,
    String teamId,
    String planId,
    PlatformFile file,
  ) {
    return _api.uploadFile(
      '/clubs/$clubId/teams/$teamId/plans/$planId/documents',
      fileField: 'file',
      fileBytes: file.bytes,
      filePath: kIsWeb ? null : file.path,
      fileName: file.name,
    );
  }

  /// Delete a plan document by its document ID.
  Future<void> deletePlanDocument(
    String clubId,
    String teamId,
    String planId,
    String documentId,
  ) async {
    await _api.delete(
      '/clubs/$clubId/teams/$teamId/plans/$planId/documents/$documentId',
    );
  }

  /// Download a plan document by its document ID.
  Future<({Uint8List bytes, String contentType, String fileName})>
  downloadPlanDocument(String planId, String documentId) async {
    final response = await _api.getFile(
      '/plans/$planId/documents/$documentId/download',
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

  Future<List<LineupDto>> getLineups(String clubId, String teamId) async {
    final json = await _api.get('/clubs/$clubId/teams/$teamId/lineups');
    return (json as List)
        .map((e) => LineupDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<LineupDto> createLineup(
    String clubId,
    String teamId,
    Map<String, dynamic> body,
  ) async {
    final json = await _api.post(
      '/clubs/$clubId/teams/$teamId/lineups',
      body: body,
    );
    return LineupDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<LineupDto> updateLineup(
    String clubId,
    String teamId,
    String lineupId,
    Map<String, dynamic> body,
  ) async {
    final json = await _api.put(
      '/clubs/$clubId/teams/$teamId/lineups/$lineupId',
      body: body,
    );
    return LineupDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<List<PlanDto>> getEventPlans(
    String clubId,
    String teamId,
    String eventId,
  ) async {
    final json =
        await _api.get('/clubs/$clubId/teams/$teamId/events/$eventId/plans');
    return (json as List)
        .map((e) => PlanDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> attachEventPlan(
    String clubId,
    String teamId,
    String eventId,
    String planId,
  ) async {
    await _api.post(
      '/clubs/$clubId/teams/$teamId/events/$eventId/plans/$planId',
    );
  }

  Future<void> detachEventPlan(
    String clubId,
    String teamId,
    String eventId,
    String planId,
  ) async {
    await _api.delete(
      '/clubs/$clubId/teams/$teamId/events/$eventId/plans/$planId',
    );
  }
}
