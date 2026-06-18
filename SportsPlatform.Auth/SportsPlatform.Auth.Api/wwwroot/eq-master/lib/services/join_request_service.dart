import '../models/api_models.dart';
import 'api_client.dart';

/// Service that wraps the club/team browsing and invitation creation
/// endpoints used by the in-app join request flow.
class JoinRequestService {
  final ApiClient _api = ApiClient.instance;

  /// Attempts to search clubs by name. The backend may not expose this
  /// endpoint yet — callers should handle errors gracefully.
  Future<List<ClubDto>> searchClubs(String query) async {
    try {
      final json = await _api.get(
        '/clubs',
        queryParams: {'search': query},
      );
      return (json as List)
          .map(
              (e) => ClubDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on ApiException {
      // Backend may not support club search — rethrow so the caller
      // can fall back to manual club-ID entry.
      rethrow;
    }
  }

  /// Returns the teams under a given club.
  Future<List<TeamDto>> getClubTeams(String clubId) async {
    final json = await _api.get('/clubs/$clubId/teams');
    return (json as List)
        .map((e) => TeamDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Submits a join request by creating an invitation on the target team.
  ///
  /// **Note**: The backend requires the caller to have manager authority on
  /// the target team. For a regular user this will return 403. The UI should
  /// handle this gracefully.
  Future<InvitationDto> submitJoinRequest({
    required String clubId,
    required String teamId,
    required String email,
    required String roleName,
    String? playerPosition,
    int? jerseyNumber,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'roleName': roleName,
    };
    if (playerPosition != null) body['playerPosition'] = playerPosition;
    if (jerseyNumber != null) body['jerseyNumber'] = jerseyNumber;

    final json = await _api.post(
      '/clubs/$clubId/teams/$teamId/invitations',
      body: body,
    );
    return InvitationDto.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Gets the pending invitations for a specific team (manager view).
  Future<List<InvitationDto>> getTeamInvitations(
      String clubId, String teamId) async {
    final json = await _api.get('/clubs/$clubId/teams/$teamId/invitations');
    return (json as List)
        .map(
            (e) => InvitationDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Cancels / declines a pending invitation.
  Future<void> cancelInvitation(
      String clubId, String teamId, String invitationId) async {
    await _api.delete(
      '/clubs/$clubId/teams/$teamId/invitations/$invitationId',
    );
  }
}
