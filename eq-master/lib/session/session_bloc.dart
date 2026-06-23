import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/club_service.dart';
import '../services/team_service.dart';
import '../services/file_cache_service.dart';

abstract class SessionEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SessionRestoreRequested extends SessionEvent {}

class SessionStarted extends SessionEvent {
  final AuthResponse auth;
  SessionStarted(this.auth);

  @override
  List<Object?> get props => [auth];
}

class SessionLogoutRequested extends SessionEvent {}

class SessionRefreshContext extends SessionEvent {}

class SessionTeamSelected extends SessionEvent {
  final String teamId;
  SessionTeamSelected(this.teamId);

  @override
  List<Object?> get props => [teamId];
}

class SessionUserUpdated extends SessionEvent {
  final UserInfo user;

  SessionUserUpdated(this.user);

  @override
  List<Object?> get props => [user];
}

enum SessionStatus { unknown, authenticated, unauthenticated }

class SessionState extends Equatable {
  final SessionStatus status;
  final UserInfo? user;
  final List<ClubDto> clubs;
  final List<TeamDto> teams;
  final String? activeTeamId;
  final String? activeClubId;

  const SessionState({
    this.status = SessionStatus.unknown,
    this.user,
    this.clubs = const [],
    this.teams = const [],
    this.activeTeamId,
    this.activeClubId,
  });

  TeamDto? get activeTeam {
    if (activeTeamId == null) return null;
    for (final team in teams) {
      if (team.teamId == activeTeamId) return team;
    }
    return null;
  }

  String? get currentRole => activeTeam?.myRole ?? clubs.firstOrNull?.myRole;
  bool get hasContext => clubs.isNotEmpty || teams.isNotEmpty;

  SessionState copyWith({
    SessionStatus? status,
    UserInfo? user,
    List<ClubDto>? clubs,
    List<TeamDto>? teams,
    String? activeTeamId,
    String? activeClubId,
    bool clearUser = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      user: clearUser ? null : user ?? this.user,
      clubs: clubs ?? this.clubs,
      teams: teams ?? this.teams,
      activeTeamId: activeTeamId ?? this.activeTeamId,
      activeClubId: activeClubId ?? this.activeClubId,
    );
  }

  @override
  List<Object?> get props =>
      [status, user, clubs, teams, activeTeamId, activeClubId];
}

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final ApiClient _api = ApiClient.instance;
  final ClubService _clubService = ClubService();
  final TeamService _teamService = TeamService();

  SessionBloc() : super(const SessionState()) {
    on<SessionRestoreRequested>(_onRestore);
    on<SessionStarted>(_onStarted);
    on<SessionLogoutRequested>(_onLogout);
    on<SessionRefreshContext>(_onRefreshContext);
    on<SessionTeamSelected>(_onTeamSelected);
    on<SessionUserUpdated>(_onUserUpdated);
  }

  Future<void> _onRestore(
    SessionRestoreRequested event,
    Emitter<SessionState> emit,
  ) async {
    final token = await _api.accessToken;
    final userJson = await _api.getUser();
    if (token == null || userJson == null) {
      emit(const SessionState(status: SessionStatus.unauthenticated));
      return;
    }

    try {
      final user = UserInfo.fromJson(jsonDecode(userJson));
      final context = await _loadContext();
      final savedTeamId = await _api.getActiveTeam();
      final savedClubId = await _api.getActiveClub();
      final activeTeamId = _resolveTeamId(context.teams, savedTeamId);
      final activeClubId = _resolveClubId(
        context.clubs,
        context.teams,
        activeTeamId,
        savedClubId,
      );

      emit(SessionState(
        status: SessionStatus.authenticated,
        user: user,
        clubs: context.clubs,
        teams: context.teams,
        activeTeamId: activeTeamId,
        activeClubId: activeClubId,
      ));
    } catch (e) {
      debugPrint('Session restore failed: $e');
      await _api.clearSession();
      emit(const SessionState(status: SessionStatus.unauthenticated));
    }
  }

  Future<void> _onStarted(
    SessionStarted event,
    Emitter<SessionState> emit,
  ) async {
    final token = event.auth.accessToken;
    final user = event.auth.user;
    if (token == null || user == null) {
      emit(const SessionState(status: SessionStatus.unauthenticated));
      return;
    }

    await _api.saveTokens(
      accessToken: token,
      refreshToken: event.auth.refreshToken ?? '',
    );
    await _api.saveUser(jsonEncode(user.toJson()));

    final context = await _loadContext();
    final activeTeamId = _resolveTeamId(context.teams, null);
    final activeClubId = _resolveClubId(
      context.clubs,
      context.teams,
      activeTeamId,
      null,
    );
    if (activeTeamId != null) await _api.saveActiveTeam(activeTeamId);
    if (activeClubId != null) await _api.saveActiveClub(activeClubId);

    emit(SessionState(
      status: SessionStatus.authenticated,
      user: user,
      clubs: context.clubs,
      teams: context.teams,
      activeTeamId: activeTeamId,
      activeClubId: activeClubId,
    ));
  }

  Future<void> _onLogout(
    SessionLogoutRequested event,
    Emitter<SessionState> emit,
  ) async {
    final refreshToken = await _api.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await AuthService().logout(refreshToken);
      } catch (_) {}
    }
    
    // Wipe local storage cache securely on logout
    try {
      await FileCacheService.instance.clearCache();
    } catch (_) {}

    await _api.clearSession();
    emit(const SessionState(status: SessionStatus.unauthenticated));
  }

  Future<void> _onRefreshContext(
    SessionRefreshContext event,
    Emitter<SessionState> emit,
  ) async {
    try {
      final context = await _loadContext();
      final activeTeamId = _resolveTeamId(context.teams, state.activeTeamId);
      final activeClubId = _resolveClubId(
        context.clubs,
        context.teams,
        activeTeamId,
        state.activeClubId,
      );
      emit(state.copyWith(
        clubs: context.clubs,
        teams: context.teams,
        activeTeamId: activeTeamId,
        activeClubId: activeClubId,
      ));
    } catch (e) {
      debugPrint('Session context refresh failed: $e');
    }
  }

  Future<void> _onTeamSelected(
    SessionTeamSelected event,
    Emitter<SessionState> emit,
  ) async {
    final team = state.teams.firstWhereOrNull((t) => t.teamId == event.teamId);
    if (team == null) return;
    await _api.saveActiveTeam(team.teamId);
    if (team.clubId != null) await _api.saveActiveClub(team.clubId!);
    emit(state.copyWith(
      activeTeamId: team.teamId,
      activeClubId: team.clubId,
    ));
  }

  Future<void> _onUserUpdated(
    SessionUserUpdated event,
    Emitter<SessionState> emit,
  ) async {
    await _api.saveUser(jsonEncode(event.user.toJson()));
    emit(state.copyWith(user: event.user));
  }

  Future<_LoadedContext> _loadContext() async {
    var clubs = <ClubDto>[];
    var teams = <TeamDto>[];
    try {
      clubs = await _clubService.getMyClubs();
    } catch (e) {
      debugPrint('Could not load clubs: $e');
    }
    try {
      teams = await _teamService.getMyTeams();
    } catch (e) {
      debugPrint('Could not load teams: $e');
    }
    return _LoadedContext(clubs, teams);
  }

  String? _resolveTeamId(List<TeamDto> teams, String? preferred) {
    if (teams.isEmpty) return null;
    if (preferred != null && teams.any((t) => t.teamId == preferred)) {
      return preferred;
    }
    return teams.first.teamId;
  }

  String? _resolveClubId(
    List<ClubDto> clubs,
    List<TeamDto> teams,
    String? teamId,
    String? preferred,
  ) {
    if (teamId != null) {
      final team = teams.firstWhereOrNull((t) => t.teamId == teamId);
      if (team?.clubId != null) return team!.clubId;
    }
    if (preferred != null && clubs.any((c) => c.clubId == preferred)) {
      return preferred;
    }
    return clubs.firstOrNull?.clubId;
  }
}

class _LoadedContext {
  final List<ClubDto> clubs;
  final List<TeamDto> teams;

  const _LoadedContext(this.clubs, this.teams);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;

  T? firstWhereOrNull(bool Function(T value) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}
