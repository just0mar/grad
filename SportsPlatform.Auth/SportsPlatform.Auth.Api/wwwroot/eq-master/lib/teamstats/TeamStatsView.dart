import 'package:eqq/gamehistory/GameDetailHistoryView.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/app_localizations.dart';
import '../core/animated_button.dart';
import '../core/app_transitions.dart';
import '../team/team_bloc.dart';
import 'stats_bloc.dart';

class TeamStats extends StatelessWidget {
  final String sport;
  final String teamName;
  final String userRole;

  const TeamStats({
    super.key,
    required this.sport,
    required this.teamName,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    final teamState = context.read<TeamBloc>().state;
    final selectedTeams = teamState.availableTeams
        .where((team) => team.id == teamState.selectedTeamId)
        .toList();
    return BlocProvider(
      create: (context) => StatsBloc()
        ..add(
          LoadStats(
            sport,
            clubId: selectedTeams.isEmpty ? null : selectedTeams.first.clubId,
            teamId: teamState.selectedTeamId,
          ),
        ),
      child: _TeamStatsContent(
        sport: sport,
        teamName: teamName,
        userRole: userRole,
      ),
    );
  }
}

class _TeamStatsContent extends StatefulWidget {
  final String sport;
  final String teamName;
  final String userRole;

  const _TeamStatsContent({
    required this.sport,
    required this.teamName,
    required this.userRole,
  });

  @override
  State<_TeamStatsContent> createState() => _TeamStatsContentState();
}

class _TeamStatsContentState extends State<_TeamStatsContent> {
  void _showEditDialog(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color textColor,
    List<Map<String, dynamic>> tableRows,
  ) {
    final lastGameControllers = tableRows
        .map((r) => TextEditingController(text: r["lastGame"] as String))
        .toList();
    final cumulativeControllers = tableRows
        .map((r) => TextEditingController(text: r["cumulative"] as String))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(AppLocalizations.of(context).editStats, style: TextStyle(color: textColor)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).stat,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).lastGame,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).cumulative,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Divider(color: isDark ? Colors.white24 : Colors.grey),
              ...List.generate(tableRows.length, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tableRows[i]["title"] as String,
                          style: TextStyle(fontSize: 13, color: textColor),
                        ),
                      ),
                      SizedBox(
                        width: 76,
                        child: TextField(
                          controller: lastGameControllers[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: textColor),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0A1F15)
                                : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 76,
                        child: TextField(
                          controller: cumulativeControllers[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: textColor),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0A1F15)
                                : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              final List<Map<String, dynamic>> updatedRows = [];
              for (int i = 0; i < tableRows.length; i++) {
                updatedRows.add({
                  "title": tableRows[i]["title"],
                  "lastGame": lastGameControllers[i].text,
                  "cumulative": cumulativeControllers[i].text,
                });
              }
              context.read<StatsBloc>().add(UpdateTableStats(updatedRows));
              Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white54 : Colors.black45;

    return BlocConsumer<StatsBloc, StatsState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChartCard(isDark, cardBg, textColor, subtitleColor, state),
                const SizedBox(height: 20),
                _buildStatsTable(
                  context,
                  isDark,
                  cardBg,
                  textColor,
                  subtitleColor,
                  state,
                ),
                const SizedBox(height: 24),
                _buildGameHistory(
                  isDark,
                  cardBg,
                  textColor,
                  subtitleColor,
                  state,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartCard(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    StatsState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).statistics(widget.teamName),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                state.statsTypeFilter == 'training' ? AppLocalizations.of(context).training : AppLocalizations.of(context).matches,
                style: TextStyle(fontSize: 13, color: subtitleColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.25,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 10, color: subtitleColor),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 10, color: subtitleColor),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: state.chartLines.map((line) {
                  final spots = (line["spots"] as List<double>)
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble() + 1, e.value))
                      .toList();
                  return LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: line["color"] as Color,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: line["color"] as Color,
                            strokeWidth: 0,
                          ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...state.chartLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: line["color"] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          line["label"] as String,
                          style: TextStyle(fontSize: 12, color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: subtitleColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTable(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    StatsState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                state.statsTypeFilter == 'training'
                    ? AppLocalizations.of(context).trainingTeamStats
                    : AppLocalizations.of(context).matchTeamStats,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).title,
                  style: TextStyle(color: subtitleColor, fontSize: 13),
                ),
              ),
              SizedBox(
                width: 80,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).lastEntry,
                    style: TextStyle(color: subtitleColor, fontSize: 13),
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).cumulative,
                    style: TextStyle(color: subtitleColor, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...state.tableRows.map(
          (row) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row["title"] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Text(
                      row["lastGame"] as String,
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Text(
                      row["cumulative"] as String,
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameHistory(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    StatsState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).gameHistoryTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        ...state.gameHistory.map((game) {
          final hasOpponentScore = game.theirScore >= 0;
          final bool won = hasOpponentScore && game.ourScore > game.theirScore;
          final scoreLabel = hasOpponentScore
              ? "${game.ourScore} - ${game.theirScore}"
              : "${game.ourScore} - -";
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              AppPageRoute(
                child: GameDetailHistoryView(
                  game: game,
                  userRole: widget.userRole,
                ),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).vsOpponent(game.opponent),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          game.date,
                          style: TextStyle(color: subtitleColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: !hasOpponentScore
                          ? (isDark ? Colors.white10 : Colors.grey.shade200)
                          : won
                              ? (isDark
                                  ? Colors.green.shade900
                                  : Colors.green.shade200)
                              : (isDark
                                  ? Colors.red.shade900
                                  : Colors.red.shade100),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      scoreLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: !hasOpponentScore
                            ? subtitleColor
                            : won
                                ? (isDark
                                    ? Colors.greenAccent
                                    : Colors.green.shade900)
                                : (isDark
                                    ? Colors.redAccent
                                    : Colors.red.shade900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl 
                      ? Icons.chevron_left 
                      : Icons.chevron_right, 
                    color: subtitleColor
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
