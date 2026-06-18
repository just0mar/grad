import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/api_client.dart';
import '../services/event_service.dart';
import 'EventModel.dart';

abstract class EventEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadEvents extends EventEvent {
  final String? clubId;
  final String? teamId;

  LoadEvents({this.clubId, this.teamId});

  @override
  List<Object?> get props => [clubId, teamId];
}

class AddEvent extends EventEvent {
  final Event event;
  final String? clubId;
  final String? teamId;

  AddEvent(this.event, {this.clubId, this.teamId});

  @override
  List<Object?> get props => [event, clubId, teamId];
}

class SelectDay extends EventEvent {
  final DateTime selectedDay;
  final DateTime focusedDay;

  SelectDay(this.selectedDay, this.focusedDay);

  @override
  List<Object?> get props => [selectedDay, focusedDay];
}

class DeleteEvent extends EventEvent {
  final String clubId;
  final String teamId;
  final String eventId;
  DeleteEvent({
    required this.clubId,
    required this.teamId,
    required this.eventId,
  });

  @override
  List<Object?> get props => [clubId, teamId, eventId];
}

class UpdateEvent extends EventEvent {
  final String clubId;
  final String teamId;
  final Event event;
  final Map<String, dynamic> data;
  UpdateEvent({
    required this.clubId,
    required this.teamId,
    required this.event,
    required this.data,
  });

  @override
  List<Object?> get props => [clubId, teamId, event, data];
}

class EventState extends Equatable {
  final List<Event> events;
  final DateTime selectedDay;
  final DateTime focusedDay;
  final Map<DateTime, List<Event>> eventsByDay;
  final bool isLoading;
  final String? error;

  EventState({
    this.events = const [],
    DateTime? selectedDay,
    DateTime? focusedDay,
    this.eventsByDay = const {},
    this.upcomingEvents = const [],
    this.isLoading = false,
    this.error,
  })  : selectedDay = selectedDay ?? DateTime.now(),
        focusedDay = focusedDay ?? DateTime.now();

  EventState copyWith({
    List<Event>? events,
    DateTime? selectedDay,
    DateTime? focusedDay,
    Map<DateTime, List<Event>>? eventsByDay,
    List<Event>? upcomingEvents,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return EventState(
      events: events ?? this.events,
      selectedDay: selectedDay ?? this.selectedDay,
      focusedDay: focusedDay ?? this.focusedDay,
      eventsByDay: eventsByDay ?? this.eventsByDay,
      upcomingEvents: upcomingEvents ?? this.upcomingEvents,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  /// Pre-computed upcoming events list.
  final List<Event> upcomingEvents;

  @override
  List<Object?> get props => [
        events,
        selectedDay,
        focusedDay,
        eventsByDay,
        upcomingEvents,
        isLoading,
        error,
      ];
}

class EventBloc extends Bloc<EventEvent, EventState> {
  final EventService _eventService = EventService();

  EventBloc() : super(EventState()) {
    on<LoadEvents>(_onLoadEvents);
    on<AddEvent>(_onAddEvent);
    on<SelectDay>(_onSelectDay);
    on<DeleteEvent>(_onDeleteEvent);
    on<UpdateEvent>(_onUpdateEvent);
  }

  Future<void> _onLoadEvents(
    LoadEvents event,
    Emitter<EventState> emit,
  ) async {
    if ((event.clubId ?? '').isEmpty || (event.teamId ?? '').isEmpty) {
      emit(state.copyWith(
        events: const [],
        eventsByDay: const {},
        isLoading: false,
        clearError: true,
      ));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final dtos = await _eventService.getTeamEvents(event.clubId!, event.teamId!);
      final events = dtos.map(Event.fromDto).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      emit(state.copyWith(
        events: events,
        eventsByDay: _rebuildEventsByDay(events),
        upcomingEvents: _computeUpcoming(events),
        isLoading: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Could not load events.',
      ));
    }
  }

  Future<void> _onAddEvent(AddEvent event, Emitter<EventState> emit) async {
    if ((event.clubId ?? '').isEmpty || (event.teamId ?? '').isEmpty) {
      emit(state.copyWith(error: 'Select a team before creating an event.'));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final season =
          await _eventService.getCurrentTeamSeason(event.clubId!, event.teamId!);
      final startAt = DateTime(
        event.event.date.year,
        event.event.date.month,
        event.event.date.day,
        event.event.time.hour,
        event.event.time.minute,
      );
      final body = <String, dynamic>{
        'seasonId': season.seasonId,
        'title': event.event.description.isNotEmpty
            ? event.event.description
            : event.event.type,
        'eventType': event.event.type,
        // Send instants as UTC so the server stores the exact moment picked,
        // independent of the server's local timezone.
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt':
            startAt.add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'description': event.event.description,
        'timezone': DateTime.now().timeZoneName,
      };
      if (event.event.location?.isNotEmpty == true) {
        body['location'] = event.event.location;
      }
      if (event.event.locationLatitude != null) {
        body['locationLatitude'] = event.event.locationLatitude;
      }
      if (event.event.locationLongitude != null) {
        body['locationLongitude'] = event.event.locationLongitude;
      }
      if (event.event.recurrenceRule != null) {
        body['recurrenceRule'] = event.event.recurrenceRule;
      }
      if (event.event.recurrenceEndDate != null) {
        // A recurrence end is a calendar date, not an instant. Pin it to UTC
        // midday so the date can't roll over a day in either direction.
        final d = event.event.recurrenceEndDate!;
        body['recurrenceEndDate'] =
            DateTime.utc(d.year, d.month, d.day, 12).toIso8601String();
      }
      final dto = await _eventService.createEvent(
        event.clubId!,
        event.teamId!,
        body,
      );
      final newEvents = List<Event>.from(state.events)..add(Event.fromDto(dto));
      newEvents.sort((a, b) => a.date.compareTo(b.date));
      emit(state.copyWith(
        events: newEvents,
        eventsByDay: _rebuildEventsByDay(newEvents),
        upcomingEvents: _computeUpcoming(newEvents),
        isLoading: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not create event.'));
    }
  }

  void _onSelectDay(SelectDay event, Emitter<EventState> emit) {
    emit(state.copyWith(
      selectedDay: event.selectedDay,
      focusedDay: event.focusedDay,
    ));
  }

  Future<void> _onDeleteEvent(
    DeleteEvent event,
    Emitter<EventState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _eventService.deleteEvent(
        event.clubId,
        event.teamId,
        event.eventId,
      );
      final events =
          state.events.where((item) => item.eventId != event.eventId).toList();
      emit(state.copyWith(
        events: events,
        eventsByDay: _rebuildEventsByDay(events),
        upcomingEvents: _computeUpcoming(events),
        isLoading: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not delete event.'));
    }
  }

  Future<void> _onUpdateEvent(
    UpdateEvent event,
    Emitter<EventState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final startAt = DateTime(
        event.event.date.year,
        event.event.date.month,
        event.event.date.day,
        event.event.time.hour,
        event.event.time.minute,
      );
      final dto = await _eventService.updateEvent(
        event.clubId,
        event.teamId,
        event.event.eventId,
        {
          'seasonId': event.event.seasonId,
          'title': event.data['title'] ?? event.event.description,
          'eventType': event.data['eventType'] ?? event.event.type,
          'startAt': startAt.toUtc().toIso8601String(),
          'endAt':
              startAt.add(const Duration(hours: 2)).toUtc().toIso8601String(),
          'description': event.data['description'] ?? event.event.description,
          if (event.event.location?.isNotEmpty == true)
            'location': event.event.location,
          if (event.event.locationLatitude != null)
            'locationLatitude': event.event.locationLatitude,
          if (event.event.locationLongitude != null)
            'locationLongitude': event.event.locationLongitude,
          'timezone': DateTime.now().timeZoneName,
          if (event.event.recurrenceRule != null)
            'recurrenceRule': event.event.recurrenceRule,
          if (event.event.recurrenceEndDate != null)
            'recurrenceEndDate': DateTime.utc(
              event.event.recurrenceEndDate!.year,
              event.event.recurrenceEndDate!.month,
              event.event.recurrenceEndDate!.day,
              12,
            ).toIso8601String(),
        },
      );
      final updated = Event.fromDto(dto);
      final events = state.events
          .map((item) => item.eventId == updated.eventId ? updated : item)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      emit(state.copyWith(
        events: events,
        eventsByDay: _rebuildEventsByDay(events),
        upcomingEvents: _computeUpcoming(events),
        isLoading: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not update event.'));
    }
  }

  // Calendar bounds the UI scrolls between (see EventView's firstDay/lastDay).
  // Recurring occurrences are materialized across this whole range so every
  // visible occurrence — not just the first — gets a marker and a tappable card.
  static final DateTime _calendarRangeStart = DateTime(2020, 1, 1);
  static final DateTime _calendarRangeEnd = DateTime(2030, 12, 31);

  Map<DateTime, List<Event>> _rebuildEventsByDay(List<Event> events) {
    final map = <DateTime, List<Event>>{};

    void addToDay(Event e) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      map.putIfAbsent(day, () => []).add(e);
    }

    for (final event in events) {
      // Always place the original (first) occurrence on its own day.
      addToDay(event);

      // Expand recurring events into per-day virtual instances across the
      // entire visible calendar range. _expandRecurringForWeek already skips
      // the original date and stops at recurrenceEndDate, so every later
      // occurrence (next Friday, the one after, …) now lands on the calendar
      // and its card carries the parent eventId, making it tappable.
      if (event.recurrenceRule != null && event.recurrenceRule!.isNotEmpty) {
        final occurrences = _expandRecurringForWeek(
          event,
          _calendarRangeStart,
          _calendarRangeEnd,
        );
        for (final occ in occurrences) {
          addToDay(occ);
        }
      }
    }
    return map;
  }

  /// Pre-compute upcoming events for a rolling 7-day window (today plus the
  /// next 7 days), including virtual instances generated from recurring events.
  /// Sorted by date with today's events first.
  static List<Event> _computeUpcoming(List<Event> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Rolling window: today through the next 7 days (exclusive end).
    final rangeEnd = today.add(const Duration(days: 8));

    final List<Event> thisWeek = [];

    for (final e in events) {
      final eventDay = DateTime(e.date.year, e.date.month, e.date.day);

      // Add the original event if it falls within the rolling window
      if (!eventDay.isBefore(today) && eventDay.isBefore(rangeEnd)) {
        thisWeek.add(e);
      }

      // Expand recurring events into virtual instances for the window
      if (e.recurrenceRule != null && e.recurrenceRule!.isNotEmpty) {
        final generated = _expandRecurringForWeek(e, today, rangeEnd);
        thisWeek.addAll(generated);
      }
    }

    // Deduplicate: if a recurring event already has a real instance on a day,
    // don't add a virtual one for the same day + same eventId.
    final seen = <String>{};
    final deduped = <Event>[];
    for (final e in thisWeek) {
      final dayKey =
          '${e.eventId}_${e.date.year}-${e.date.month}-${e.date.day}';
      if (seen.add(dayKey)) deduped.add(e);
    }

    // Sort: today first, then by date ascending
    deduped.sort((a, b) {
      final aDay = DateTime(a.date.year, a.date.month, a.date.day);
      final bDay = DateTime(b.date.year, b.date.month, b.date.day);
      final aIsToday = aDay == today;
      final bIsToday = bDay == today;
      if (aIsToday && !bIsToday) return -1;
      if (!aIsToday && bIsToday) return 1;
      return a.date.compareTo(b.date);
    });

    return deduped;
  }

  /// Expand a weekly recurring event into virtual instances for the given
  /// date range [rangeStart, rangeEnd). Only supports FREQ=WEEKLY;BYDAY=...
  static List<Event> _expandRecurringForWeek(
    Event event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final rule = event.recurrenceRule!;
    if (!rule.contains('FREQ=WEEKLY')) return [];

    // Parse BYDAY (e.g. "MO", "SU,TU,TH")
    final byDayMatch = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(rule);
    if (byDayMatch == null) return [];

    final dayAbbrevs = byDayMatch.group(1)!.split(',');
    const abbrevToWeekday = {
      'MO': DateTime.monday,
      'TU': DateTime.tuesday,
      'WE': DateTime.wednesday,
      'TH': DateTime.thursday,
      'FR': DateTime.friday,
      'SA': DateTime.saturday,
      'SU': DateTime.sunday,
    };

    final targetWeekdays = <int>[];
    for (final abbr in dayAbbrevs) {
      final wd = abbrevToWeekday[abbr.trim()];
      if (wd != null) targetWeekdays.add(wd);
    }

    // Don't generate instances before the original event date
    final eventStartDay = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    final endDate = event.recurrenceEndDate;

    final results = <Event>[];
    // Iterate anchored at midday: adding Duration(days: 1) to a local DateTime
    // can drift ±1h across daylight-saving transitions, and over a multi-year
    // range that drift could otherwise push a date across midnight and
    // skip/duplicate a day. Noon anchoring keeps `d.day` stable.
    final iterEnd = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day, 12);
    for (var d = DateTime(
          rangeStart.year,
          rangeStart.month,
          rangeStart.day,
          12,
        );
        d.isBefore(iterEnd);
        d = d.add(const Duration(days: 1))) {
      if (!targetWeekdays.contains(d.weekday)) continue;
      if (d.isBefore(eventStartDay)) continue;
      // Compare by calendar day (not instant) so the recurrence end date is
      // inclusive regardless of the time-of-day it was stored with.
      if (endDate != null) {
        final endDay = DateTime(endDate.year, endDate.month, endDate.day);
        final dDay = DateTime(d.year, d.month, d.day);
        if (dDay.isAfter(endDay)) continue;
      }

      // Skip the original event's own date (already added above)
      if (d.year == eventStartDay.year &&
          d.month == eventStartDay.month &&
          d.day == eventStartDay.day) continue;

      // Create a virtual instance with the same time but on this day
      final virtualDate = DateTime(
        d.year,
        d.month,
        d.day,
        event.date.hour,
        event.date.minute,
      );
      results.add(Event(
        eventId: event.eventId,
        teamId: event.teamId,
        seasonId: event.seasonId,
        type: event.type,
        date: virtualDate,
        time: event.time,
        description: event.description,
        location: event.location,
        locationLatitude: event.locationLatitude,
        locationLongitude: event.locationLongitude,
        recurrenceRule: event.recurrenceRule,
        recurrenceEndDate: event.recurrenceEndDate,
      ));
    }

    return results;
  }
}
