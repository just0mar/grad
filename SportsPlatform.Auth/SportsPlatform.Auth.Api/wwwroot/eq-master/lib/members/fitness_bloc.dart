import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/fitness_service.dart';

abstract class FitnessEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadFitnessRecords extends FitnessEvent {
  final String clubId;
  final String teamId;
  final String playerUserId;
  LoadFitnessRecords({
    required this.clubId,
    required this.teamId,
    required this.playerUserId,
  });

  @override
  List<Object?> get props => [clubId, teamId, playerUserId];
}

class CreateFitnessRecord extends FitnessEvent {
  final Map<String, dynamic> body;
  CreateFitnessRecord(this.body);

  @override
  List<Object?> get props => [body];
}

class FitnessState extends Equatable {
  final String? clubId;
  final String? teamId;
  final String? playerUserId;
  final List<FitnessRecordDto> records;
  final bool isLoading;
  final String? error;

  const FitnessState({
    this.clubId,
    this.teamId,
    this.playerUserId,
    this.records = const [],
    this.isLoading = false,
    this.error,
  });

  FitnessState copyWith({
    String? clubId,
    String? teamId,
    String? playerUserId,
    List<FitnessRecordDto>? records,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FitnessState(
      clubId: clubId ?? this.clubId,
      teamId: teamId ?? this.teamId,
      playerUserId: playerUserId ?? this.playerUserId,
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props =>
      [clubId, teamId, playerUserId, records, isLoading, error];
}

class FitnessBloc extends Bloc<FitnessEvent, FitnessState> {
  final FitnessService _fitnessService = FitnessService();

  FitnessBloc() : super(const FitnessState()) {
    on<LoadFitnessRecords>(_onLoad);
    on<CreateFitnessRecord>(_onCreate);
  }

  Future<void> _onLoad(
    LoadFitnessRecords event,
    Emitter<FitnessState> emit,
  ) async {
    emit(state.copyWith(
      clubId: event.clubId,
      teamId: event.teamId,
      playerUserId: event.playerUserId,
      isLoading: true,
      clearError: true,
    ));
    try {
      final records = await _fitnessService.getPlayerFitness(
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
        error: 'Could not load fitness records.',
      ));
    }
  }

  Future<void> _onCreate(
    CreateFitnessRecord event,
    Emitter<FitnessState> emit,
  ) async {
    if (state.clubId == null ||
        state.teamId == null ||
        state.playerUserId == null) {
      emit(state.copyWith(error: 'Select a team and player first.'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final record = await _fitnessService.createFitnessRecord(
        state.clubId!,
        state.teamId!,
        state.playerUserId!,
        event.body,
      );
      emit(state.copyWith(records: [record, ...state.records], isLoading: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Could not create fitness record.',
      ));
    }
  }
}
