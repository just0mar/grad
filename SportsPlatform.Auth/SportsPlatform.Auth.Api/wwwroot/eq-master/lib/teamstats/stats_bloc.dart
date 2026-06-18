import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../gamehistory/GameHistoryModel.dart';
import '../services/api_client.dart';
import '../services/stats_service.dart';

abstract class StatsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadStats extends StatsEvent {
  final String sport;
  final String? clubId;
  final String? teamId;

  LoadStats(this.sport, {this.clubId, this.teamId});

  @override
  List<Object?> get props => [sport, clubId, teamId];
}

class UpdateTableStats extends StatsEvent {
  final List<Map<String, dynamic>> tableRows;

  UpdateTableStats(this.tableRows);

  @override
  List<Object?> get props => [tableRows];
}

class SetStatsTypeFilter extends StatsEvent {
  final String category; // "game" | "training"
  SetStatsTypeFilter(this.category);

  @override
  List<Object?> get props => [category];
}

class LoadMatchDetail extends StatsEvent {
  final String clubId;
  final String teamId;
  final String eventId;
  LoadMatchDetail({
    required this.clubId,
    required this.teamId,
    required this.eventId,
  });

  @override
  List<Object?> get props => [clubId, teamId, eventId];
}

class LoadPlayerStats extends StatsEvent {
  final String clubId;
  final String teamId;
  final String playerId;
  LoadPlayerStats({
    required this.clubId,
    required this.teamId,
    required this.playerId,
  });

  @override
  List<Object?> get props => [clubId, teamId, playerId];
}

class LoadPlayerMatchHistory extends StatsEvent {
  final String clubId;
  final String teamId;
  final String playerId;
  LoadPlayerMatchHistory({
    required this.clubId,
    required this.teamId,
    required this.playerId,
  });

  @override
  List<Object?> get props => [clubId, teamId, playerId];
}

class RefreshStats extends StatsEvent {
  final String sport;
  final String? clubId;
  final String? teamId;
  RefreshStats(this.sport, {this.clubId, this.teamId});

  @override
  List<Object?> get props => [sport, clubId, teamId];
}

class StatsState extends Equatable {
  final List<Map<String, dynamic>> tableRows;
  final List<Map<String, dynamic>> chartLines;
  final List<GameHistory> gameHistory;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic> matchDetail;
  final Map<String, dynamic> playerStats;
  final List<dynamic> playerMatchHistory;
  final List<Map<String, dynamic>> rawStatsHistory;
  final String statsTypeFilter;

  const StatsState({
    this.tableRows = const [],
    this.chartLines = const [],
    this.gameHistory = const [],
    this.isLoading = false,
    this.error,
    this.matchDetail = const {},
    this.playerStats = const {},
    this.playerMatchHistory = const [],
    this.rawStatsHistory = const [],
    this.statsTypeFilter = 'game',
  });

  StatsState copyWith({
    List<Map<String, dynamic>>? tableRows,
    List<Map<String, dynamic>>? chartLines,
    List<GameHistory>? gameHistory,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? matchDetail,
    Map<String, dynamic>? playerStats,
    List<dynamic>? playerMatchHistory,
    List<Map<String, dynamic>>? rawStatsHistory,
    String? statsTypeFilter,
    bool clearError = false,
  }) {
    return StatsState(
      tableRows: tableRows ?? this.tableRows,
      chartLines: chartLines ?? this.chartLines,
      gameHistory: gameHistory ?? this.gameHistory,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      matchDetail: matchDetail ?? this.matchDetail,
      playerStats: playerStats ?? this.playerStats,
      playerMatchHistory: playerMatchHistory ?? this.playerMatchHistory,
      rawStatsHistory: rawStatsHistory ?? this.rawStatsHistory,
      statsTypeFilter: statsTypeFilter ?? this.statsTypeFilter,
    );
  }

  @override
  List<Object?> get props =>
      [
        tableRows,
        chartLines,
        gameHistory,
        isLoading,
        error,
        matchDetail,
        playerStats,
        playerMatchHistory,
        rawStatsHistory,
        statsTypeFilter,
      ];
}

class StatsBloc extends Bloc<StatsEvent, StatsState> {
  final StatsService _statsService = StatsService();

  StatsBloc() : super(const StatsState()) {
    on<LoadStats>(_onLoadStats);
    on<UpdateTableStats>(_onUpdateTableStats);
    on<SetStatsTypeFilter>(_onSetStatsTypeFilter);
    on<LoadMatchDetail>(_onLoadMatchDetail);
    on<LoadPlayerStats>(_onLoadPlayerStats);
    on<LoadPlayerMatchHistory>(_onLoadPlayerMatchHistory);
    on<RefreshStats>((event, emit) => _onLoadStats(
      LoadStats(event.sport, clubId: event.clubId, teamId: event.teamId),
      emit,
    ));
  }

  Future<void> _onLoadStats(
    LoadStats event,
    Emitter<StatsState> emit,
  ) async {
    if ((event.clubId ?? '').isEmpty || (event.teamId ?? '').isEmpty) {
      emit(state.copyWith(
        tableRows: const [],
        chartLines: const [],
        gameHistory: const [],
        clearError: true,
      ));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final matches =
          await _statsService.getMatchHistory(event.clubId!, event.teamId!);
      final rawHistory =
          matches.map((raw) => Map<String, dynamic>.from(raw as Map)).toList();
      final visible = _visibleHistory(rawHistory, state.statsTypeFilter);
      emit(state.copyWith(
        rawStatsHistory: rawHistory,
        tableRows: _buildBasketballTableRows(visible),
        chartLines: _buildChartLines(visible),
        gameHistory: _buildGameHistory(visible, event.clubId!, event.teamId!),
        isLoading: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not load stats.'));
    }
  }

  void _onUpdateTableStats(UpdateTableStats event, Emitter<StatsState> emit) {
    emit(state.copyWith(tableRows: event.tableRows));
  }

  void _onSetStatsTypeFilter(
    SetStatsTypeFilter event,
    Emitter<StatsState> emit,
  ) {
    final visible = _visibleHistory(state.rawStatsHistory, event.category);
    // Extract clubId/teamId from the raw data if available
    final firstRow = state.rawStatsHistory.isNotEmpty ? state.rawStatsHistory.first : <String, dynamic>{};
    final clubId = firstRow['clubId']?.toString() ?? '';
    final teamId = firstRow['teamId']?.toString() ?? '';
    emit(state.copyWith(
      statsTypeFilter: event.category,
      tableRows: _buildBasketballTableRows(visible),
      chartLines: _buildChartLines(visible),
      gameHistory: _buildGameHistory(visible, clubId, teamId),
    ));
  }

  Future<void> _onLoadMatchDetail(
    LoadMatchDetail event,
    Emitter<StatsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final raw = await _statsService.getMatchStats(
        event.clubId,
        event.teamId,
        event.eventId,
      );
      emit(state.copyWith(
        isLoading: false,
        matchDetail: Map<String, dynamic>.from(raw as Map),
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not load match stats.'));
    }
  }

  Future<void> _onLoadPlayerStats(
    LoadPlayerStats event,
    Emitter<StatsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final raw = await _statsService.getPlayerAggregate(
        event.clubId,
        event.teamId,
        event.playerId,
      );
      emit(state.copyWith(
        isLoading: false,
        playerStats: Map<String, dynamic>.from(raw as Map),
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not load player stats.'));
    }
  }

  Future<void> _onLoadPlayerMatchHistory(
    LoadPlayerMatchHistory event,
    Emitter<StatsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final raw = await _statsService.getPlayerMatchHistory(
        event.clubId,
        event.teamId,
        event.playerId,
      );
      emit(state.copyWith(isLoading: false, playerMatchHistory: raw));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Could not load player match history.',
      ));
    }
  }
}

const List<_BasketballStatDef> _teamBasketballStats = [
  _BasketballStatDef('points', 'Points'),
  _BasketballStatDef('totalRebounds', 'Total Rebounds'),
  _BasketballStatDef('offensiveRebounds', 'Offensive Rebounds'),
  _BasketballStatDef('defensiveRebounds', 'Defensive Rebounds'),
  _BasketballStatDef('basketballAssists', 'Assists'),
  _BasketballStatDef('steals', 'Steals'),
  _BasketballStatDef('blocks', 'Blocks'),
  _BasketballStatDef('turnovers', 'Turnovers'),
  _BasketballStatDef('personalFouls', 'Personal Fouls'),
  _BasketballStatDef('foulsDrawn', 'Fouls Drawn'),
  _BasketballStatDef('efficiency', 'Efficiency'),
  _BasketballStatDef('twoPtMA', '2-Point Field Goals', isMadeAttempt: true),
  _BasketballStatDef('threePtMA', '3-Point Field Goals', isMadeAttempt: true),
  _BasketballStatDef('ftMA', 'Free Throws', isMadeAttempt: true),
];

List<Map<String, dynamic>> _visibleHistory(
  List<Map<String, dynamic>> rows,
  String category,
) {
  return rows
      .where((row) => _rowCategory(row) == category)
      .where(_hasBasketballStats)
      .toList()
    ..sort((a, b) => _rowDate(b).compareTo(_rowDate(a)));
}

String _rowCategory(Map<String, dynamic> row) {
  final category = row['category']?.toString().toLowerCase();
  if (category == 'game' || category == 'training') return category!;
  final eventType = row['eventType']?.toString().toLowerCase();
  return eventType == 'training' ? 'training' : 'game';
}

DateTime _rowDate(Map<String, dynamic> row) {
  return DateTime.tryParse('${row['updatedAt'] ?? row['createdAt'] ?? row['eventStartAt'] ?? ''}') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

bool _hasBasketballStats(Map<String, dynamic> row) {
  if (_asInt(row['playerCount']) > 0) return true;
  return _teamBasketballStats.any((stat) {
    final value = row[stat.key];
    return value != null && value.toString().trim().isNotEmpty;
  });
}

List<Map<String, dynamic>> _buildBasketballTableRows(
  List<Map<String, dynamic>> rows,
) {
  if (rows.isEmpty) {
    return _teamBasketballStats
        .map((stat) => {
              'title': stat.label,
              'lastGame': '-',
              'cumulative': '-',
            })
        .toList();
  }

  final last = rows.first;
  return _teamBasketballStats.map((stat) {
    return {
      'title': stat.label,
      'lastGame': _formatStatValue(last[stat.key]),
      'cumulative': stat.isMadeAttempt
          ? _sumMadeAttempt(rows.map((row) => row[stat.key]))
          : '${rows.fold<int>(0, (sum, row) => sum + _asInt(row[stat.key]))}',
    };
  }).toList();
}

List<Map<String, dynamic>> _buildChartLines(List<Map<String, dynamic>> rows) {
  final ordered = rows.reversed.toList();
  final chartStats = [
    _teamBasketballStats[0],
    _teamBasketballStats[1],
    _teamBasketballStats[4],
  ];
  final colors = [Colors.blue.shade700, Colors.green.shade400, Colors.orange];

  return chartStats.asMap().entries.map((entry) {
    final stat = entry.value;
    final values = ordered.map((row) => _asInt(row[stat.key]).toDouble()).toList();
    return {
      'label': stat.label,
      'color': colors[entry.key],
      'spots': values.isEmpty ? const <double>[0] : values,
    };
  }).toList();
}

/// Public helper used by the notification router to open a single match's
/// detail page (the same [GameHistory] reached by tapping a game on the stats
/// screen). Returns null when the row carries no usable data.
GameHistory? gameHistoryFromRow(Map<String, dynamic> row) {
  final clubId = row['clubId']?.toString() ?? '';
  final teamId = row['teamId']?.toString() ?? '';
  final built = _buildGameHistory([row], clubId, teamId);
  return built.isEmpty ? null : built.first;
}

List<GameHistory> _buildGameHistory(List<Map<String, dynamic>> rows, String clubId, String teamId) {
  return rows.map((map) {
    return GameHistory(
      eventId: (map['eventId'] ?? map['id'])?.toString(),
      clubId: clubId.isNotEmpty ? clubId : map['clubId']?.toString(),
      teamId: teamId.isNotEmpty ? teamId : map['teamId']?.toString(),
      opponent: _opponentLabel(map),
      date: _formatDate(_rowDate(map)),
      ourScore: (map['ourScore'] as num?)?.toInt() ??
          (map['teamScore'] as num?)?.toInt() ??
          0,
      theirScore: (map['theirScore'] as num?)?.toInt() ??
          (map['opponentScore'] as num?)?.toInt() ??
          -1,
      stats: _teamBasketballStats
          .map((stat) => {
                'title': stat.label,
                'value': _formatStatValue(map[stat.key]),
              })
          .toList(),
      videos: const [],
    );
  }).toList();
}

String _opponentLabel(Map<String, dynamic> row) {
  final direct = row['opponent'] ?? row['opponentName'];
  final directText = direct?.toString().trim() ?? '';
  if (directText.isNotEmpty) return directText;

  final matchup = row['matchup']?.toString().trim() ?? '';
  final matchupParts = matchup.split(RegExp(r'\s+vs\s+', caseSensitive: false));
  if (matchupParts.length == 2 && matchupParts[1].trim().isNotEmpty) {
    return matchupParts[1].trim();
  }

  final eventTitle = row['eventTitle']?.toString().trim() ?? '';
  if (eventTitle.isNotEmpty && eventTitle.toLowerCase() != 'match') {
    return eventTitle;
  }
  return 'Opponent';
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return '';
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _formatStatValue(dynamic value) {
  if (value == null) return '-';
  final text = value.toString().trim();
  return text.isEmpty ? '-' : text;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _sumMadeAttempt(Iterable<dynamic> values) {
  var made = 0;
  var attempted = 0;
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    final parts = text.split('/');
    if (parts.length != 2) continue;
    made += int.tryParse(parts[0].trim()) ?? 0;
    attempted += int.tryParse(parts[1].trim()) ?? 0;
  }
  return attempted == 0 ? '-' : '$made/$attempted';
}

class _BasketballStatDef {
  final String key;
  final String label;
  final bool isMadeAttempt;

  const _BasketballStatDef(
    this.key,
    this.label, {
    this.isMadeAttempt = false,
  });
}
