import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/api_client.dart';
import '../services/invitation_service.dart';

abstract class JoinTeamEvent extends Equatable {
  const JoinTeamEvent();

  @override
  List<Object?> get props => [];
}

class LoadJoinRequests extends JoinTeamEvent {}

class AcceptRequest extends JoinTeamEvent {
  final int index;

  const AcceptRequest(this.index);

  @override
  List<Object?> get props => [index];
}

class RejectRequest extends JoinTeamEvent {
  final int index;

  const RejectRequest(this.index);

  @override
  List<Object?> get props => [index];
}

class JoinTeamState extends Equatable {
  final List<Map<String, dynamic>> requests;
  final bool isLoading;
  final String? error;
  final String? message;

  const JoinTeamState({
    this.requests = const [],
    this.isLoading = false,
    this.error,
    this.message,
  });

  JoinTeamState copyWith({
    List<Map<String, dynamic>>? requests,
    bool? isLoading,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return JoinTeamState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [requests, isLoading, error, message];
}

class JoinTeamBloc extends Bloc<JoinTeamEvent, JoinTeamState> {
  final InvitationService _invitationService = InvitationService();

  JoinTeamBloc() : super(const JoinTeamState()) {
    on<LoadJoinRequests>(_onLoadJoinRequests);
    on<AcceptRequest>(_onAcceptRequest);
    on<RejectRequest>(_onRejectRequest);
  }

  Future<void> _onLoadJoinRequests(
    LoadJoinRequests event,
    Emitter<JoinTeamState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearMessage: true));
    try {
      final invitations = await _invitationService.getMyInvitations();
      emit(state.copyWith(
        requests: invitations
            .map(
              (invite) => {
                'team': invite.teamName ?? invite.clubName,
                'members': invite.role,
                'token': invite.token,
                'invitationId': invite.invitationId,
                'email': invite.email,
                'role': invite.role,
                'clubName': invite.clubName,
                'teamName': invite.teamName,
                'playerPosition': invite.playerPosition,
                'jerseyNumber': invite.jerseyNumber,
                'inviterName': invite.inviterName,
                'status': invite.status,
                'expiresAt': invite.expiresAt?.toIso8601String(),
                'createdAt': invite.createdAt?.toIso8601String(),
              },
            )
            .toList(),
        isLoading: false,
      ));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Could not load invitations.',
        clearMessage: true,
      ));
    }
  }

  Future<void> _onAcceptRequest(
    AcceptRequest event,
    Emitter<JoinTeamState> emit,
  ) async {
    if (event.index < 0 || event.index >= state.requests.length) return;
    final request = state.requests[event.index];
    try {
      await _invitationService.acceptInvitation('${request['token']}');
      final updated = List<Map<String, dynamic>>.from(state.requests)
        ..removeAt(event.index);
      emit(state.copyWith(
        requests: updated,
        message: 'Invitation accepted.',
        clearError: true,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        error: e.message,
        clearMessage: true,
      ));
    } catch (_) {
      emit(state.copyWith(
        error: 'Could not accept invitation.',
        clearMessage: true,
      ));
    }
  }

  Future<void> _onRejectRequest(
    RejectRequest event,
    Emitter<JoinTeamState> emit,
  ) async {
    if (event.index < 0 || event.index >= state.requests.length) return;
    final request = state.requests[event.index];
    try {
      await _invitationService.denyInvitation('${request['token']}');
      final updated = List<Map<String, dynamic>>.from(state.requests)
        ..removeAt(event.index);
      emit(state.copyWith(
        requests: updated,
        message: 'Invitation declined.',
        clearError: true,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        error: e.message,
        clearMessage: true,
      ));
    } catch (_) {
      emit(state.copyWith(
        error: 'Could not decline invitation.',
        clearMessage: true,
      ));
    }
  }

  Future<bool> joinTeamById(String id) async {
    return false;
  }
}
