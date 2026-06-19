import '../models/api_models.dart';
import 'api_client.dart';

class InvitationService {
  final ApiClient _api = ApiClient.instance;

  Future<List<InvitationDto>> getMyInvitations() async {
    final json = await _api.get('/invitations/me');
    return (json as List)
        .map((e) => InvitationDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<dynamic> acceptInvitation(String token) {
    return _api.post('/invitations/${Uri.encodeComponent(token)}/accept');
  }

  Future<void> denyInvitation(String token) async {
    await _api.post('/invitations/${Uri.encodeComponent(token)}/deny');
  }

  Future<InvitationDto> createTeamInvitation(
      String clubId, String teamId, Map<String, dynamic> request) async {
    final json = await _api.post(
      '/clubs/$clubId/teams/$teamId/invitations',
      body: request,
    );
    return InvitationDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<InvitationDto> createClubInvitation(
      String clubId, Map<String, dynamic> request) async {
    final json = await _api.post(
      '/clubs/$clubId/invitations',
      body: request,
    );
    return InvitationDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<List<InvitationDto>> getTeamInvitations(
      String clubId, String teamId) async {
    final json = await _api.get('/clubs/$clubId/teams/$teamId/invitations');
    return (json as List)
        .map((e) => InvitationDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> deleteTeamInvitation(
      String clubId, String teamId, String invitationId) async {
    await _api.delete(
      '/clubs/$clubId/teams/$teamId/invitations/$invitationId',
    );
  }
}
