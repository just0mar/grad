import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/api_client.dart';
import '../services/event_service.dart';
import '../services/stats_service.dart';
import '../models/api_models.dart';

// ── Events ──

abstract class StatsEntryEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SetStatsCategory extends StatsEntryEvent {
  final String category; // "game" | "training"
  SetStatsCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class SetStatsMode extends StatsEntryEvent {
  final String mode; // "per_game" | "cumulative"
  SetStatsMode(this.mode);

  @override
  List<Object?> get props => [mode];
}

class LoadEligibleStatsEvents extends StatsEntryEvent {
  final String clubId;
  final String teamId;
  final String? preferredEventId;
  LoadEligibleStatsEvents({
    required this.clubId,
    required this.teamId,
    this.preferredEventId,
  });

  @override
  List<Object?> get props => [clubId, teamId, preferredEventId];
}

class SetSelectedStatsEvent extends StatsEntryEvent {
  final String? eventId;
  SetSelectedStatsEvent(this.eventId);

  @override
  List<Object?> get props => [eventId];
}

class SubmitManualStats extends StatsEntryEvent {
  final String clubId;
  final String teamId;
  final Map<String, dynamic> stats;
  SubmitManualStats({
    required this.clubId,
    required this.teamId,
    required this.stats,
  });

  @override
  List<Object?> get props => [clubId, teamId, stats];
}

class UploadPdf extends StatsEntryEvent {
  final String clubId;
  final String teamId;
  final String filePath;
  final String fileName;
  UploadPdf({
    required this.clubId,
    required this.teamId,
    required this.filePath,
    required this.fileName,
  });

  @override
  List<Object?> get props => [clubId, teamId, filePath, fileName];
}

class ConfirmExtractedData extends StatsEntryEvent {
  final String clubId;
  final String teamId;
  final String eventId;
  final String category;
  final List<Map<String, dynamic>> rows;
  ConfirmExtractedData({
    required this.clubId,
    required this.teamId,
    required this.eventId,
    required this.category,
    required this.rows,
  });

  @override
  List<Object?> get props => [clubId, teamId, eventId, category, rows];
}

class ClearEntryMessages extends StatsEntryEvent {}

// ── State ──

class StatsEntryState extends Equatable {
  final String category;   // "game" | "training"
  final String mode;        // "per_game" | "cumulative"
  final bool isSubmitting;
  final bool isUploading;
  final bool isLoadingEvents;
  final List<EventDto> events;
  final String? selectedEventId;
  final List<Map<String, dynamic>>? extractedPreview;
  final int? extractedPlayerCount;
  final int? extractedTeamTotalCount;
  final String? uploadedPdfPath;
  final String? uploadedPdfFileName;
  final String? error;
  final String? successMessage;

  const StatsEntryState({
    this.category = 'game',
    this.mode = 'per_game',
    this.isSubmitting = false,
    this.isUploading = false,
    this.isLoadingEvents = false,
    this.events = const [],
    this.selectedEventId,
    this.extractedPreview,
    this.extractedPlayerCount,
    this.extractedTeamTotalCount,
    this.uploadedPdfPath,
    this.uploadedPdfFileName,
    this.error,
    this.successMessage,
  });

  StatsEntryState copyWith({
    String? category,
    String? mode,
    bool? isSubmitting,
    bool? isUploading,
    bool? isLoadingEvents,
    List<EventDto>? events,
    String? selectedEventId,
    List<Map<String, dynamic>>? extractedPreview,
    int? extractedPlayerCount,
    int? extractedTeamTotalCount,
    String? uploadedPdfPath,
    String? uploadedPdfFileName,
    String? error,
    String? successMessage,
    bool clearPreview = false,
    bool clearSelectedEvent = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return StatsEntryState(
      category: category ?? this.category,
      mode: mode ?? this.mode,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isUploading: isUploading ?? this.isUploading,
      isLoadingEvents: isLoadingEvents ?? this.isLoadingEvents,
      events: events ?? this.events,
      selectedEventId: clearSelectedEvent ? null : selectedEventId ?? this.selectedEventId,
      extractedPreview: clearPreview ? null : extractedPreview ?? this.extractedPreview,
      extractedPlayerCount: clearPreview ? null : extractedPlayerCount ?? this.extractedPlayerCount,
      extractedTeamTotalCount: clearPreview ? null : extractedTeamTotalCount ?? this.extractedTeamTotalCount,
      uploadedPdfPath: clearPreview ? null : uploadedPdfPath ?? this.uploadedPdfPath,
      uploadedPdfFileName: clearPreview ? null : uploadedPdfFileName ?? this.uploadedPdfFileName,
      error: clearError ? null : error ?? this.error,
      successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
    category, mode, isSubmitting, isUploading, isLoadingEvents, events, selectedEventId,
    extractedPreview, extractedPlayerCount, extractedTeamTotalCount,
    uploadedPdfPath, uploadedPdfFileName,
    error, successMessage,
  ];
}

// ── Bloc ──

class StatsEntryBloc extends Bloc<StatsEntryEvent, StatsEntryState> {
  final StatsService _statsService = StatsService();
  final EventService _eventService = EventService();

  StatsEntryBloc() : super(const StatsEntryState()) {
    on<SetStatsCategory>(_onSetCategory);
    on<SetStatsMode>(_onSetMode);
    on<LoadEligibleStatsEvents>(_onLoadEvents);
    on<SetSelectedStatsEvent>(_onSetSelectedEvent);
    on<SubmitManualStats>(_onSubmitManual);
    on<UploadPdf>(_onUploadPdf);
    on<ConfirmExtractedData>(_onConfirmExtracted);
    on<ClearEntryMessages>((_, emit) {
      emit(state.copyWith(clearError: true, clearSuccess: true));
    });
  }

  void _onSetCategory(SetStatsCategory event, Emitter<StatsEntryState> emit) {
    final matchingEvents =
        state.events.where((e) => _eventMatchesCategory(e, event.category)).toList();
    final currentStillMatches = matchingEvents
        .any((e) => e.eventId == state.selectedEventId);
    emit(state.copyWith(
      category: event.category,
      selectedEventId: currentStillMatches || matchingEvents.isEmpty
          ? state.selectedEventId
          : matchingEvents.first.eventId,
      clearPreview: true,
      clearSelectedEvent: matchingEvents.isEmpty,
    ));
  }

  void _onSetMode(SetStatsMode event, Emitter<StatsEntryState> emit) {
    emit(state.copyWith(mode: event.mode));
  }

  Future<void> _onLoadEvents(
    LoadEligibleStatsEvents event,
    Emitter<StatsEntryState> emit,
  ) async {
    emit(state.copyWith(isLoadingEvents: true, clearError: true));
    try {
      final now = DateTime.now();
      final events = await _eventService.getTeamEvents(
        event.clubId,
        event.teamId,
        from: now.subtract(const Duration(days: 365)),
        to: now.add(const Duration(days: 365)),
      );
      final eligible = events
          .where((event) {
            final type = event.eventType.toLowerCase();
            return type == 'match' || type == 'training';
          })
          .toList()
        ..sort((a, b) => b.startAt.compareTo(a.startAt));
      final preferred = event.preferredEventId;
      final selected = preferred != null &&
              eligible.any((item) => item.eventId == preferred)
          ? preferred
          : (eligible.isEmpty ? null : eligible.first.eventId);
      emit(state.copyWith(
        isLoadingEvents: false,
        events: eligible,
        selectedEventId: selected,
        clearSelectedEvent: eligible.isEmpty,
        error: eligible.isEmpty ? 'No match or training events found for this team.' : null,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoadingEvents: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoadingEvents: false, error: 'Could not load events.'));
    }
  }

  void _onSetSelectedEvent(
    SetSelectedStatsEvent event,
    Emitter<StatsEntryState> emit,
  ) {
    emit(state.copyWith(selectedEventId: event.eventId));
  }

  Future<void> _onSubmitManual(
    SubmitManualStats event,
    Emitter<StatsEntryState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true));
    try {
      final body = {
        ...event.stats,
        'category': state.category,
      };
      await _statsService.createBasketballStats(event.clubId, event.teamId, body);
      emit(state.copyWith(
        isSubmitting: false,
        successMessage: 'Stats saved successfully.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isSubmitting: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isSubmitting: false, error: 'Could not save stats.'));
    }
  }

  Future<void> _onUploadPdf(
    UploadPdf event,
    Emitter<StatsEntryState> emit,
  ) async {
    emit(state.copyWith(isUploading: true, clearError: true, clearSuccess: true, clearPreview: true));
    try {
      final result = await _statsService.extractBasketballPdf(
        event.clubId,
        event.teamId,
        event.filePath,
        event.fileName,
      );

      final rows = (result['rows'] as List?)
          ?.map((r) => Map<String, dynamic>.from(r as Map))
          .toList() ?? [];

      final canSave = result['canSave'] == true;
      final message = result['message'] as String? ?? '';

      emit(state.copyWith(
        isUploading: false,
        extractedPreview: rows,
        extractedPlayerCount: result['playerCount'] as int?,
        extractedTeamTotalCount: result['teamTotalCount'] as int?,
        uploadedPdfPath: event.filePath,
        uploadedPdfFileName: event.fileName,
        successMessage: canSave ? message : null,
        error: canSave ? null : message,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isUploading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isUploading: false, error: 'PDF extraction failed.'));
    }
  }

  Future<void> _onConfirmExtracted(
    ConfirmExtractedData event,
    Emitter<StatsEntryState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true));
    try {
      await _statsService.confirmBasketballUpload(event.clubId, event.teamId, {
        'eventId': event.eventId,
        'category': event.category,
        'rows': event.rows,
      });

      // Best-effort: persist the original PDF so the future "Ask Equipo"
      // chatbot can be served the raw document. Never block confirm on this.
      final pdfPath = state.uploadedPdfPath;
      final pdfName = state.uploadedPdfFileName;
      if (pdfPath != null && pdfName != null) {
        try {
          await _statsService.uploadRawStatsPdf(
            event.clubId,
            event.teamId,
            event.eventId,
            pdfPath,
            pdfName,
          );
        } catch (_) {
          // Ignore: the stats themselves are saved; the raw PDF is optional.
        }
      }

      emit(state.copyWith(
        isSubmitting: false,
        successMessage: 'Extracted stats saved successfully.',
        clearPreview: true,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isSubmitting: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isSubmitting: false, error: 'Could not save extracted stats.'));
    }
  }
}

bool _eventMatchesCategory(EventDto event, String category) {
  final type = event.eventType.toLowerCase();
  return category == 'training' ? type == 'training' : type == 'match';
}
