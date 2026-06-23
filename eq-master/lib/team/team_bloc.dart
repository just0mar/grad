import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../addteam/AddTeamModel.dart';
import '../members/MemberModel.dart';
import '../services/api_client.dart';
import '../services/team_service.dart';

abstract class TeamEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadTeamMembers extends TeamEvent {
  final String? activeTeamId;
  LoadTeamMembers({this.activeTeamId});

  @override
  List<Object?> get props => [activeTeamId];
}

class ConfigureTeamAccess extends TeamEvent {
  final String userId;
  final String fallbackRole;
  ConfigureTeamAccess({required this.userId, required this.fallbackRole});

  @override
  List<Object?> get props => [userId, fallbackRole];
}

class RegisterTeam extends TeamEvent {
  final Team team;
  final String fallbackRole;
  RegisterTeam({required this.team, required this.fallbackRole});

  @override
  List<Object?> get props => [team, fallbackRole];
}

class SwitchTeamContext extends TeamEvent {
  final String teamId;
  SwitchTeamContext(this.teamId);

  @override
  List<Object?> get props => [teamId];
}

class ClearPermissionError extends TeamEvent {}

class LeaveTeam extends TeamEvent {
  final String clubId;
  final String teamId;
  LeaveTeam({required this.clubId, required this.teamId});

  @override
  List<Object?> get props => [clubId, teamId];
}

class RemoveMember extends TeamEvent {
  final String clubId;
  final String teamId;
  final String memberId;
  RemoveMember({required this.clubId, required this.teamId, required this.memberId});

  @override
  List<Object?> get props => [clubId, teamId, memberId];
}

class ClearTeamMessage extends TeamEvent {}

class UpdateMemberStatus extends TeamEvent {
  final int index;
  final bool isInSquad;
  UpdateMemberStatus(this.index, this.isInSquad);

  @override
  List<Object?> get props => [index, isInSquad];
}

class UpdateMemberData extends TeamEvent {
  final int index;
  final Member member;
  final bool requiresStateEditPermission;
  UpdateMemberData(
    this.index,
    this.member, {
    this.requiresStateEditPermission = false,
  });

  @override
  List<Object?> get props => [index, member, requiresStateEditPermission];
}

class AddTeamMember extends TeamEvent {
  final Member member;
  AddTeamMember(this.member);

  @override
  List<Object?> get props => [member];
}

class TeamState extends Equatable {
  final List<Member> members;
  final Map<String, List<Member>> membersByTeamId;
  final List<Team> availableTeams;
  final String selectedTeamId;
  final String selectedTeamName;
  final String userRoleInSelectedTeam;
  final String currentUserId;
  final bool isLoading;
  final String? permissionError;
  final String? successMessage;

  const TeamState({
    this.members = const [],
    this.membersByTeamId = const {},
    this.availableTeams = const [],
    this.selectedTeamId = '',
    this.selectedTeamName = 'My Team',
    this.userRoleInSelectedTeam = '',
    this.currentUserId = '',
    this.isLoading = false,
    this.permissionError,
    this.successMessage,
  });

  TeamState copyWith({
    List<Member>? members,
    Map<String, List<Member>>? membersByTeamId,
    List<Team>? availableTeams,
    String? selectedTeamId,
    String? selectedTeamName,
    String? userRoleInSelectedTeam,
    String? currentUserId,
    bool? isLoading,
    String? permissionError,
    String? successMessage,
    bool clearPermissionError = false,
    bool clearSuccessMessage = false,
  }) {
    return TeamState(
      members: members ?? this.members,
      membersByTeamId: membersByTeamId ?? this.membersByTeamId,
      availableTeams: availableTeams ?? this.availableTeams,
      selectedTeamId: selectedTeamId ?? this.selectedTeamId,
      selectedTeamName: selectedTeamName ?? this.selectedTeamName,
      userRoleInSelectedTeam:
          userRoleInSelectedTeam ?? this.userRoleInSelectedTeam,
      currentUserId: currentUserId ?? this.currentUserId,
      isLoading: isLoading ?? this.isLoading,
      permissionError: clearPermissionError
          ? null
          : permissionError ?? this.permissionError,
      successMessage: clearSuccessMessage
          ? null
          : successMessage ?? this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
    members,
    membersByTeamId,
    availableTeams,
    selectedTeamId,
    selectedTeamName,
    userRoleInSelectedTeam,
    currentUserId,
    isLoading,
    permissionError,
    successMessage,
  ];
}

class TeamBloc extends Bloc<TeamEvent, TeamState> {
  final TeamService _teamService = TeamService();

  TeamBloc() : super(const TeamState()) {
    on<LoadTeamMembers>(_onLoadTeamMembers);
    on<ConfigureTeamAccess>(_onConfigureTeamAccess);
    on<RegisterTeam>(_onRegisterTeam);
    on<SwitchTeamContext>(_onSwitchTeamContext);
    on<ClearPermissionError>((_, emit) {
      emit(state.copyWith(clearPermissionError: true));
    });
    on<ClearTeamMessage>((_, emit) {
      emit(
        state.copyWith(clearPermissionError: true, clearSuccessMessage: true),
      );
    });
    on<LeaveTeam>(_onLeaveTeam);
    on<RemoveMember>(_onRemoveMember);
    on<UpdateMemberStatus>(_onUpdateMemberStatus);
    on<UpdateMemberData>(_onUpdateMemberData);
    on<AddTeamMember>(_onAddTeamMember);
  }

  Future<void> _onLoadTeamMembers(
    LoadTeamMembers event,
    Emitter<TeamState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearPermissionError: true));
    try {
      final myTeams = await _teamService.getMyTeams();
      final availableTeams = myTeams
          .map(
            (team) => Team(
              id: team.teamId,
              clubId: team.clubId,
              country: '',
              club: team.teamName,
              imageUrl: team.imageUrl,
              clubLogoUrl: team.clubLogoUrl,
              sport: 'Basketball',
              category: team.clubName ?? team.categoryName ?? '',
              memberRoles: {'self': team.myRole ?? ''},
            ),
          )
          .toList();

      if (myTeams.isEmpty) {
        emit(
          state.copyWith(
            members: const [],
            membersByTeamId: const {},
            availableTeams: const [],
            selectedTeamId: '',
            selectedTeamName: 'My Team',
            userRoleInSelectedTeam: '',
            isLoading: false,
          ),
        );
        return;
      }

      final selected = myTeams.firstWhere(
        (team) => team.teamId == event.activeTeamId,
        orElse: () => myTeams.first,
      );
      final members = selected.clubId == null
          ? <Member>[]
          : await _fetchMembers(selected.clubId!, selected.teamId);

      emit(
        state.copyWith(
          members: members,
          membersByTeamId: {selected.teamId: members},
          availableTeams: availableTeams,
          selectedTeamId: selected.teamId,
          selectedTeamName: selected.teamName,
          userRoleInSelectedTeam: selected.myRole ?? '',
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, permissionError: e.message));
    } catch (e) {
      debugPrint('Team load failed: $e');
      emit(
        state.copyWith(
          isLoading: false,
          permissionError: 'Could not load teams.',
        ),
      );
    }
  }

  Future<void> _onConfigureTeamAccess(
    ConfigureTeamAccess event,
    Emitter<TeamState> emit,
  ) async {
    emit(state.copyWith(currentUserId: event.userId));
    await _onLoadTeamMembers(
      LoadTeamMembers(activeTeamId: state.selectedTeamId),
      emit,
    );
  }

  void _onRegisterTeam(RegisterTeam event, Emitter<TeamState> emit) {
    final updatedTeams = [...state.availableTeams, event.team];
    emit(state.copyWith(availableTeams: updatedTeams));
  }

  Future<void> _onSwitchTeamContext(
    SwitchTeamContext event,
    Emitter<TeamState> emit,
  ) async {
    final team = state.availableTeams.firstWhere(
      (t) => t.id == event.teamId,
      orElse: () => state.availableTeams.isEmpty
          ? Team(
              country: '',
              club: 'My Team',
              sport: 'Basketball',
              category: '',
            )
          : state.availableTeams.first,
    );
    if (team.id.isEmpty) return;

    if (state.membersByTeamId.containsKey(team.id)) {
      emit(
        state.copyWith(
          selectedTeamId: team.id,
          selectedTeamName: team.club,
          userRoleInSelectedTeam: team.memberRoles['self'] ?? '',
          members: state.membersByTeamId[team.id],
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        selectedTeamId: team.id,
        selectedTeamName: team.club,
        userRoleInSelectedTeam: team.memberRoles['self'] ?? '',
        isLoading: true,
      ),
    );
    try {
      final apiTeam = (await _teamService.getMyTeams()).firstWhere(
        (t) => t.teamId == team.id,
      );
      final members = apiTeam.clubId == null
          ? <Member>[]
          : await _fetchMembers(apiTeam.clubId!, apiTeam.teamId);
      final updatedMap = Map<String, List<Member>>.from(state.membersByTeamId)
        ..[team.id] = members;
      emit(
        state.copyWith(
          isLoading: false,
          members: members,
          membersByTeamId: updatedMap,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          permissionError: 'Could not switch teams.',
        ),
      );
    }
  }

  Future<List<Member>> _fetchMembers(String clubId, String teamId) async {
    final dtos = await _teamService.getTeamMembers(clubId, teamId);
    return dtos
        .map(
          (dto) => Member(
            userId: dto.userId,
            email: dto.email,
            name: dto.name,
            role: dto.role,
            image: 'assets/profile.png',
            profileImageUrl: dto.profileImageUrl,
            position: dto.position,
            jerseyNumber: dto.jerseyNumber,
            injuryFlag: dto.isInjured,
            injuryType: dto.injuryType ?? '',
          ),
        )
        .toList();
  }

  void _onUpdateMemberStatus(
    UpdateMemberStatus event,
    Emitter<TeamState> emit,
  ) {
    if (event.index < 0 || event.index >= state.members.length) return;
    final updated = List<Member>.from(state.members);
    final member = updated[event.index];
    updated[event.index] = member.copyWith(isInSquad: event.isInSquad);
    final map = Map<String, List<Member>>.from(state.membersByTeamId)
      ..[state.selectedTeamId] = updated;
    emit(state.copyWith(members: updated, membersByTeamId: map));
  }

  void _onUpdateMemberData(UpdateMemberData event, Emitter<TeamState> emit) {
    if (event.index < 0 || event.index >= state.members.length) return;
    final updated = List<Member>.from(state.members);
    updated[event.index] = event.member;
    final map = Map<String, List<Member>>.from(state.membersByTeamId)
      ..[state.selectedTeamId] = updated;
    emit(state.copyWith(members: updated, membersByTeamId: map));
  }

  void _onAddTeamMember(AddTeamMember event, Emitter<TeamState> emit) {
    emit(
      state.copyWith(
        permissionError:
            'Members must be added through backend invitations, not local IDs.',
      ),
    );
  }

  Future<void> _onLeaveTeam(LeaveTeam event, Emitter<TeamState> emit) async {
    if (state.currentUserId.isEmpty) {
      emit(state.copyWith(permissionError: 'Could not identify your account.'));
      return;
    }

    emit(
      state.copyWith(
        isLoading: true,
        clearPermissionError: true,
        clearSuccessMessage: true,
      ),
    );
    try {
      final leavingTeam = state.availableTeams.firstWhere(
        (team) => team.id == event.teamId,
        orElse: () => Team(country: '', club: 'Team', sport: '', category: ''),
      );

      await _teamService.leaveTeam(
        event.clubId,
        event.teamId,
        state.currentUserId,
      );

      final remaining = state.availableTeams
          .where((team) => team.id != event.teamId)
          .toList();
      final nextTeam = remaining.isEmpty ? null : remaining.first;
      final nextMembers = nextTeam == null || nextTeam.clubId == null
          ? <Member>[]
          : await _fetchMembers(nextTeam.clubId!, nextTeam.id);

      emit(
        state.copyWith(
          isLoading: false,
          availableTeams: remaining,
          selectedTeamId: nextTeam?.id ?? '',
          selectedTeamName: nextTeam?.club ?? 'My Team',
          userRoleInSelectedTeam: nextTeam?.memberRoles['self'] ?? '',
          members: nextMembers,
          membersByTeamId: nextTeam == null
              ? const {}
              : {nextTeam.id: nextMembers},
          successMessage: 'You have left ${leavingTeam.club}',
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, permissionError: e.message));
    } catch (e) {
      debugPrint('Leave team failed: $e');
      emit(
        state.copyWith(
          isLoading: false,
          permissionError: 'Could not leave team. Please try again.',
        ),
      );
    }
  }

  Future<void> _onRemoveMember(RemoveMember event, Emitter<TeamState> emit) async {
    emit(
      state.copyWith(
        isLoading: true,
        clearPermissionError: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      await _teamService.leaveTeam(
        event.clubId,
        event.teamId,
        event.memberId,
      );

      final currentMembers = List<Member>.from(state.members)
          ..removeWhere((m) => m.userId == event.memberId);
      final updatedMap = Map<String, List<Member>>.from(state.membersByTeamId)
        ..[event.teamId] = currentMembers;

      emit(
        state.copyWith(
          isLoading: false,
          members: currentMembers,
          membersByTeamId: updatedMap,
          successMessage: 'Member removed successfully',
        ),
      );
    } catch (e) {
      emit(state.copyWith(permissionError: 'Failed to remove member: $e', isLoading: false));
    }
  }
}
