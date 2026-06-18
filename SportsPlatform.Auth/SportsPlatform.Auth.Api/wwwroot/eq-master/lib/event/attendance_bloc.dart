import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/attendance_service.dart';

abstract class AttendanceEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadAttendance extends AttendanceEvent {
  final String clubId;
  final String teamId;
  final String eventId;
  LoadAttendance({
    required this.clubId,
    required this.teamId,
    required this.eventId,
  });

  @override
  List<Object?> get props => [clubId, teamId, eventId];
}

class RecordAttendance extends AttendanceEvent {
  final List<Map<String, dynamic>> entries;
  RecordAttendance(this.entries);

  @override
  List<Object?> get props => [entries];
}

class UpdatePlayerAttendance extends AttendanceEvent {
  final String playerUserId;
  final String status;
  UpdatePlayerAttendance({required this.playerUserId, required this.status});

  @override
  List<Object?> get props => [playerUserId, status];
}

class AttendanceState extends Equatable {
  final String? clubId;
  final String? teamId;
  final String? eventId;
  final List<AttendanceDto> attendees;
  final bool isLoading;
  final String? error;

  const AttendanceState({
    this.clubId,
    this.teamId,
    this.eventId,
    this.attendees = const [],
    this.isLoading = false,
    this.error,
  });

  AttendanceState copyWith({
    String? clubId,
    String? teamId,
    String? eventId,
    List<AttendanceDto>? attendees,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AttendanceState(
      clubId: clubId ?? this.clubId,
      teamId: teamId ?? this.teamId,
      eventId: eventId ?? this.eventId,
      attendees: attendees ?? this.attendees,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props =>
      [clubId, teamId, eventId, attendees, isLoading, error];
}

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final AttendanceService _attendanceService = AttendanceService();

  AttendanceBloc() : super(const AttendanceState()) {
    on<LoadAttendance>(_onLoad);
    on<RecordAttendance>(_onRecord);
    on<UpdatePlayerAttendance>(_onUpdate);
  }

  Future<void> _onLoad(
    LoadAttendance event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(state.copyWith(
      clubId: event.clubId,
      teamId: event.teamId,
      eventId: event.eventId,
      isLoading: true,
      clearError: true,
    ));
    await _reloadAttendance(emit);
  }

  Future<void> _onRecord(
    RecordAttendance event,
    Emitter<AttendanceState> emit,
  ) async {
    if (!_hasContext) {
      emit(state.copyWith(error: 'Select an event first.'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _attendanceService.recordAttendance(
        state.clubId!,
        state.teamId!,
        state.eventId!,
        {'entries': event.entries},
      );
      await _reloadAttendance(emit);
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not save attendance.'));
    }
  }

  Future<void> _onUpdate(
    UpdatePlayerAttendance event,
    Emitter<AttendanceState> emit,
  ) async {
    if (!_hasContext) {
      emit(state.copyWith(error: 'Select an event first.'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _attendanceService.updateAttendance(
        state.clubId!,
        state.teamId!,
        state.eventId!,
        event.playerUserId,
        {'status': event.status},
      );
      await _reloadAttendance(emit);
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not update attendance.'));
    }
  }

  /// Shared reload helper — avoids `add()` chaining race conditions.
  Future<void> _reloadAttendance(Emitter<AttendanceState> emit) async {
    try {
      final attendees = await _attendanceService.getEventAttendance(
        state.clubId!,
        state.teamId!,
        state.eventId!,
      );
      emit(state.copyWith(attendees: attendees, isLoading: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Could not load attendance.',
      ));
    }
  }

  bool get _hasContext =>
      state.clubId != null && state.teamId != null && state.eventId != null;
}
