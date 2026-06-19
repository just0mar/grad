import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/plan_service.dart';

abstract class PlansEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadPlans extends PlansEvent {
  final String clubId;
  final String teamId;
  LoadPlans({required this.clubId, required this.teamId});

  @override
  List<Object?> get props => [clubId, teamId];
}

class CreatePlan extends PlansEvent {
  final String title;
  final String description;
  final String visibility;
  final String category;
  final List<String> attachmentPaths;
  final String? tacticalBoardData;
  CreatePlan({
    required this.title,
    required this.description,
    required this.visibility,
    this.category = 'Offensive',
    this.attachmentPaths = const [],
    this.tacticalBoardData,
  });

  @override
  List<Object?> get props => [
    title,
    description,
    visibility,
    category,
    attachmentPaths,
    tacticalBoardData,
  ];
}

class UpdatePlan extends PlansEvent {
  final String planId;
  final String title;
  final String description;
  final String visibility;
  final String category;
  final List<String> attachmentPaths;
  final List<String> discardedDocumentIds;
  final String? tacticalBoardData;

  UpdatePlan({
    required this.planId,
    required this.title,
    required this.description,
    required this.visibility,
    required this.category,
    this.attachmentPaths = const [],
    this.discardedDocumentIds = const [],
    this.tacticalBoardData,
  });

  @override
  List<Object?> get props => [
    planId,
    title,
    description,
    visibility,
    category,
    attachmentPaths,
    discardedDocumentIds,
    tacticalBoardData,
  ];
}

class DeletePlan extends PlansEvent {
  final String planId;
  DeletePlan(this.planId);

  @override
  List<Object?> get props => [planId];
}

class PlansState extends Equatable {
  final String? clubId;
  final String? teamId;
  final List<PlanDto> plans;
  final bool isLoading;
  final String? error;

  const PlansState({
    this.clubId,
    this.teamId,
    this.plans = const [],
    this.isLoading = false,
    this.error,
  });

  PlansState copyWith({
    String? clubId,
    String? teamId,
    List<PlanDto>? plans,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PlansState(
      clubId: clubId ?? this.clubId,
      teamId: teamId ?? this.teamId,
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [clubId, teamId, plans, isLoading, error];
}

class PlansBloc extends Bloc<PlansEvent, PlansState> {
  final PlanService _planService = PlanService();

  PlansBloc() : super(const PlansState()) {
    on<LoadPlans>(_onLoad);
    on<CreatePlan>(_onCreate);
    on<UpdatePlan>(_onUpdate);
    on<DeletePlan>(_onDelete);
  }

  Future<void> _onLoad(LoadPlans event, Emitter<PlansState> emit) async {
    emit(
      state.copyWith(
        clubId: event.clubId,
        teamId: event.teamId,
        isLoading: true,
        clearError: true,
      ),
    );
    try {
      final plans = await _planService.getTeamPlans(event.clubId, event.teamId);
      emit(state.copyWith(plans: plans, isLoading: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not load plans.'));
    }
  }

  Future<void> _onCreate(CreatePlan event, Emitter<PlansState> emit) async {
    final clubId = state.clubId;
    final teamId = state.teamId;
    if (clubId == null || teamId == null) {
      emit(state.copyWith(error: 'Select a team before adding plans.'));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final created = await _planService.createPlan(clubId, teamId, {
        'title': event.title,
        'description': event.description,
        'content': _encodePlanContent(
          description: event.description,
          category: event.category,
          tacticalBoardData: event.tacticalBoardData,
        ),
        'visibility': event.visibility,
      });

      // Upload attachments if any
      final failedUploads = <String>[];
      for (final path in event.attachmentPaths) {
        final fileName = path.split(RegExp(r'[/\\]')).last;
        try {
          await _planService.uploadPlanDocument(
            clubId,
            teamId,
            created.planId,
            path,
            fileName,
          );
        } catch (_) {
          failedUploads.add(fileName);
        }
      }

      // Re-fetch to get the plan with documents populated
      if (event.attachmentPaths.isNotEmpty) {
        final plans = await _planService.getTeamPlans(clubId, teamId);
        emit(state.copyWith(
          plans: plans,
          isLoading: false,
          error: failedUploads.isNotEmpty
              ? 'Failed to upload: ${failedUploads.join(", ")}'
              : null,
        ));
      } else {
        emit(
          state.copyWith(plans: [created, ...state.plans], isLoading: false),
        );
      }
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not add plan.'));
    }
  }

  Future<void> _onUpdate(UpdatePlan event, Emitter<PlansState> emit) async {
    final clubId = state.clubId;
    final teamId = state.teamId;
    if (clubId == null || teamId == null) {
      emit(state.copyWith(error: 'Select a team before editing plans.'));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final updated = await _planService
          .updatePlan(clubId, teamId, event.planId, {
            'title': event.title,
            'description': event.description,
            'content': _encodePlanContent(
              description: event.description,
              category: event.category,
              tacticalBoardData: event.tacticalBoardData,
            ),
            'visibility': event.visibility,
          });

      // Delete any documents the user discarded while editing.
      for (final documentId in event.discardedDocumentIds) {
        try {
          await _planService.deletePlanDocument(
            clubId,
            teamId,
            event.planId,
            documentId,
          );
        } catch (_) {
          // Best-effort: ignore individual delete failures.
        }
      }

      final failedUploads = <String>[];
      for (final path in event.attachmentPaths) {
        final fileName = path.split(RegExp(r'[/\\]')).last;
        try {
          await _planService.uploadPlanDocument(
            clubId,
            teamId,
            updated.planId,
            path,
            fileName,
          );
        } catch (_) {
          failedUploads.add(fileName);
        }
      }

      final plans = await _planService.getTeamPlans(clubId, teamId);
      emit(state.copyWith(
        plans: plans,
        isLoading: false,
        error: failedUploads.isNotEmpty
            ? 'Failed to upload: ${failedUploads.join(", ")}'
            : null,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not edit plan.'));
    }
  }

  Future<void> _onDelete(DeletePlan event, Emitter<PlansState> emit) async {
    final clubId = state.clubId;
    final teamId = state.teamId;
    if (clubId == null || teamId == null) {
      emit(state.copyWith(error: 'Select a team before deleting plans.'));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _planService.deletePlan(clubId, teamId, event.planId);
      emit(
        state.copyWith(
          plans: state.plans
              .where((plan) => plan.planId != event.planId)
              .toList(),
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not delete plan.'));
    }
  }
}

String _encodePlanContent({
  required String description,
  required String category,
  required String? tacticalBoardData,
}) {
  return jsonEncode({
    'description': description,
    'category': category,
    'tacticalBoardData': tacticalBoardData,
  });
}
