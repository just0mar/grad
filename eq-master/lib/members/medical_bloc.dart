import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/medical_service.dart';

abstract class MedicalEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadMedicalRecords extends MedicalEvent {
  final String clubId;
  final String teamId;
  final String playerUserId;
  LoadMedicalRecords({
    required this.clubId,
    required this.teamId,
    required this.playerUserId,
  });

  @override
  List<Object?> get props => [clubId, teamId, playerUserId];
}

class CreateMedicalRecord extends MedicalEvent {
  final String injuryType;
  final String diagnosis;
  final String recoveryTips;
  CreateMedicalRecord({
    required this.injuryType,
    required this.diagnosis,
    required this.recoveryTips,
  });

  @override
  List<Object?> get props => [injuryType, diagnosis, recoveryTips];
}

class UpdateMedicalRecord extends MedicalEvent {
  final String recordId;
  final String injuryType;
  final String diagnosis;
  final String recoveryTips;
  UpdateMedicalRecord({
    required this.recordId,
    required this.injuryType,
    required this.diagnosis,
    required this.recoveryTips,
  });

  @override
  List<Object?> get props => [recordId, injuryType, diagnosis, recoveryTips];
}

class UpdateClearance extends MedicalEvent {
  final String recordId;
  final bool cleared;
  UpdateClearance({required this.recordId, required this.cleared});

  @override
  List<Object?> get props => [recordId, cleared];
}

class MedicalState extends Equatable {
  final String? clubId;
  final String? teamId;
  final String? playerUserId;
  final List<MedicalRecordDto> records;
  final bool isLoading;
  final String? error;

  const MedicalState({
    this.clubId,
    this.teamId,
    this.playerUserId,
    this.records = const [],
    this.isLoading = false,
    this.error,
  });

  MedicalState copyWith({
    String? clubId,
    String? teamId,
    String? playerUserId,
    List<MedicalRecordDto>? records,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MedicalState(
      clubId: clubId ?? this.clubId,
      teamId: teamId ?? this.teamId,
      playerUserId: playerUserId ?? this.playerUserId,
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        clubId,
        teamId,
        playerUserId,
        records,
        isLoading,
        error,
      ];
}

class MedicalBloc extends Bloc<MedicalEvent, MedicalState> {
  final MedicalService _medicalService = MedicalService();

  MedicalBloc() : super(const MedicalState()) {
    on<LoadMedicalRecords>(_onLoad);
    on<CreateMedicalRecord>(_onCreate);
    on<UpdateMedicalRecord>(_onUpdate);
    on<UpdateClearance>(_onClearance);
  }

  Future<void> _onLoad(
    LoadMedicalRecords event,
    Emitter<MedicalState> emit,
  ) async {
    emit(state.copyWith(
      clubId: event.clubId,
      teamId: event.teamId,
      playerUserId: event.playerUserId,
      isLoading: true,
      clearError: true,
    ));
    try {
      final records = await _medicalService.getPlayerMedical(
        event.clubId,
        event.teamId,
        event.playerUserId,
      );
      emit(state.copyWith(records: records, isLoading: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Could not load medical records.',
      ));
    }
  }

  Future<void> _onCreate(
    CreateMedicalRecord event,
    Emitter<MedicalState> emit,
  ) async {
    final context = _contextOrNull();
    if (context == null) {
      emit(state.copyWith(error: 'Select a team and player first.'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final record = await _medicalService.createMedicalRecord(
        context.clubId,
        context.teamId,
        context.playerUserId,
        _body(event.injuryType, event.diagnosis, event.recoveryTips),
      );
      emit(state.copyWith(records: [record, ...state.records], isLoading: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Could not create medical record.',
      ));
    }
  }

  Future<void> _onUpdate(
    UpdateMedicalRecord event,
    Emitter<MedicalState> emit,
  ) async {
    final context = _contextOrNull();
    if (context == null) {
      emit(state.copyWith(error: 'Select a team and player first.'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final record = await _medicalService.updateMedicalRecord(
        context.clubId,
        context.teamId,
        event.recordId,
        _body(event.injuryType, event.diagnosis, event.recoveryTips),
      );
      emit(state.copyWith(
        records: state.records
            .map((item) => item.recordId == record.recordId ? record : item)
            .toList(),
        isLoading: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Could not update medical record.',
      ));
    }
  }

  Future<void> _onClearance(
    UpdateClearance event,
    Emitter<MedicalState> emit,
  ) async {
    final context = _contextOrNull();
    if (context == null) {
      emit(state.copyWith(error: 'Select a team and player first.'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _medicalService.updateClearance(
        context.clubId,
        context.teamId,
        event.recordId,
        event.cleared,
      );
      await _reloadRecords(emit, context);
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Could not update clearance.',
      ));
    }
  }

  /// Shared reload helper — avoids `add()` chaining race conditions.
  Future<void> _reloadRecords(
    Emitter<MedicalState> emit,
    _MedicalContext context,
  ) async {
    try {
      final records = await _medicalService.getPlayerMedical(
        context.clubId,
        context.teamId,
        context.playerUserId,
      );
      emit(state.copyWith(records: records, isLoading: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Could not load medical records.',
      ));
    }
  }

  Map<String, dynamic> _body(
    String injuryType,
    String diagnosis,
    String recoveryTips,
  ) {
    return {
      'recordDate': DateTime.now().toIso8601String(),
      'injuryType': injuryType,
      'diagnosis': diagnosis,
      'recoveryTips': recoveryTips,
    };
  }

  _MedicalContext? _contextOrNull() {
    final clubId = state.clubId;
    final teamId = state.teamId;
    final playerUserId = state.playerUserId;
    if (clubId == null || teamId == null || playerUserId == null) return null;
    return _MedicalContext(clubId, teamId, playerUserId);
  }
}

class _MedicalContext {
  final String clubId;
  final String teamId;
  final String playerUserId;

  const _MedicalContext(this.clubId, this.teamId, this.playerUserId);
}
