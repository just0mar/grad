import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import '../addevent/AddEventView.dart';
import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../match/MatchDetailView.dart';
import '../core/responsive_system.dart';
import '../team/team_bloc.dart';
import 'EventModel.dart';
import 'event_bloc.dart';
import '../core/app_transitions.dart';
import '../core/app_localizations.dart';
import 'package:intl/intl.dart';

class EventView extends StatelessWidget {
  /// When set (e.g. arriving from an event notification), the calendar opens
  /// with that day's bottom sheet already expanded.
  final DateTime? focusDate;

  const EventView({super.key, this.focusDate});

  @override
  Widget build(BuildContext context) {
    return _EventViewContent(focusDate: focusDate);
  }
}

/// Invisible one-shot helper that opens the day sheet after the first frame.
class _DaySheetAutoOpener extends StatefulWidget {
  final VoidCallback onReady;
  const _DaySheetAutoOpener({super.key, required this.onReady});

  @override
  State<_DaySheetAutoOpener> createState() => _DaySheetAutoOpenerState();
}

class _DaySheetAutoOpenerState extends State<_DaySheetAutoOpener> {
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || _fired) return;
      _fired = true;
      widget.onReady();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _EventViewContent extends StatelessWidget {
  final DateTime? focusDate;

  const _EventViewContent({this.focusDate});

  Color _getEventColor(String type) {
    switch (type.trim()) {
      case "Match":
        return Colors.blue.shade900;
      case "Training":
        return Colors.green.shade900;
      case "Meeting":
        return Colors.green.shade400;
      case "Test":
        return const Color(0xFF082E6F);
      default:
        return Colors.grey;
    }
  }

  IconData _getEventIcon(String type) {
    switch (type.trim()) {
      case "Match":
        return Icons.sports_soccer;
      case "Training":
        return Icons.fitness_center;
      case "Meeting":
        return Icons.event_note;
      case "Test":
        return Icons.science;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = ResponsiveSystem.pagePadding(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: t.eventsTitle, showTeamSwitcher: true),
      body: BlocConsumer<EventBloc, EventState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          return AppBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: padding,
                child: Column(
                  children: [
                    if (focusDate != null)
                      _DaySheetAutoOpener(
                        key: const ValueKey('event-day-auto-opener'),
                        onReady: () {
                          if (!context.mounted) return;
                          final freshState = context.read<EventBloc>().state;
                          context
                              .read<EventBloc>()
                              .add(SelectDay(focusDate!, focusDate!));
                          _showDayBottomSheet(
                            context,
                            focusDate!,
                            freshState,
                            isDark,
                          );
                        },
                      ),
                    if (state.isLoading)
                      const LinearProgressIndicator(minHeight: 3),
                    _buildCalendarContainer(context, state, isDark),
                    const SizedBox(height: 16),
                    _buildLegend(context, isDark),
                    // Bottom spacer so the floating add-event button doesn't
                    // overlap the calendar/legend.
                    const SizedBox(height: 88),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendarContainer(
    BuildContext context,
    EventState state,
    bool isDark,
  ) {
    final calBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: calBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TableCalendar<Event>(
        locale: AppLocalizations.of(context).localeName,
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: state.focusedDay,
        selectedDayPredicate: (day) => isSameDay(state.selectedDay, day),
        eventLoader: (day) =>
            state.eventsByDay[DateTime(day.year, day.month, day.day)] ?? [],
        // Keep the calendar a fixed height across months (always render 6 rows)
        // so the layout below it doesn't jump between 5- and 6-week months.
        sixWeekMonthsEnforced: true,
        // Explicit week start so weekday headers line up with the dates.
        startingDayOfWeek: StartingDayOfWeek.monday,
        rowHeight: 60,
        calendarStyle: CalendarStyle(
          cellMargin: const EdgeInsets.all(4),
          defaultDecoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(10),
          ),
          weekendDecoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(10),
          ),
          todayDecoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(10),
          ),
          defaultTextStyle: TextStyle(color: textColor, fontFamily: 'SFPro'),
          weekendTextStyle: TextStyle(color: textColor, fontFamily: 'SFPro'),
          todayTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Facon',
            fontSize: 20,
            color: textColor,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
          rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
        ),
        onDaySelected: (selected, focused) {
          context.read<EventBloc>().add(SelectDay(selected, focused));
          _showDayBottomSheet(context, selected, state, isDark);
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return const SizedBox();
            return Positioned(
              bottom: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: events.take(3).map((e) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _getEventColor(e.type),
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final t = AppLocalizations.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _legendItem(t.match, Colors.blue.shade900, textColor),
        _legendItem(t.training, Colors.green.shade900, textColor),
        _legendItem(t.meeting, Colors.green.shade400, textColor),
        _legendItem(t.test, const Color(0xFF082E6F), textColor),
      ],
    );
  }

  Widget _legendItem(String label, Color color, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }

  // ─── Google Calendar-style bottom sheet when tapping a day ───
  void _showDayBottomSheet(
    BuildContext context,
    DateTime selectedDay,
    EventState state,
    bool isDark,
  ) {
    final dayKey = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final eventsForDay = state.eventsByDay[dayKey] ?? [];
    final textColor = isDark ? Colors.white : Colors.black;
    final sheetBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;

    final teamState = context.read<TeamBloc>().state;
    final role = teamState.userRoleInSelectedTeam.trim();
    // Adding events is restricted to managers only.
    final canAdd = role == 'ClubManager' || role == 'TeamManager';

    final t = AppLocalizations.of(context);
    final dayTitle = DateFormat('EEEE, MMMM d', t.localeName).format(selectedDay);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── drag handle ──
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dayTitle,
                      style: TextStyle(
                        fontFamily: 'Facon',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (canAdd)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToAddEvent(context, selectedDay);
                      },
                      icon: const Icon(Icons.add, color: Colors.green),
                      label: Text(
                        t.add,
                        style: const TextStyle(
                          color: Colors.green,
                          fontFamily: 'SFPro',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── event list ──
            if (eventsForDay.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 40,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t.noEventsOnThisDay,
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 15,
                        color: textColor.withValues(alpha: 0.5),
                      ),
                    ),
                    if (canAdd) ...[
                      const SizedBox(height: 16),
                      AnimatedButton.primary(child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToAddEvent(context, selectedDay);
                        },
                        icon: const Icon(Icons.add, size: 20),
                        label: Text(
                          t.addEvent,
                          style: const TextStyle(fontFamily: 'SFPro', fontSize: 14),
                        ),
                      )),
                    ],
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: eventsForDay.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final event = eventsForDay[i];
                    final color = _getEventColor(event.type);
                    final icon = _getEventIcon(event.type);
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      // The whole card is tappable and opens the match details
                      // page for this event.
                      //
                      // Capture the navigator BEFORE popping the bottom sheet so
                      // we don't rely on a context whose route is being removed,
                      // and defer the push to the next frame so the sheet's modal
                      // barrier is fully torn down first. Doing both in the same
                      // synchronous step can leave a stale barrier on the overlay,
                      // which renders as a black/blank page.
                      onTap: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          navigator.push(
                            AppPageRoute(
                              child: MatchDetailView(event: event),
                            ),
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: color.withValues(alpha: isDark ? 0.25 : 0.08),
                          border: BorderDirectional(
                            start: BorderSide(color: color, width: 4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, color: color, size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.type,
                                    style: TextStyle(
                                      fontFamily: 'SFPro',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${event.time.format(context)} — ${event.description}',
                                    style: TextStyle(
                                      fontFamily: 'SFPro',
                                      fontSize: 13,
                                      color: textColor.withValues(alpha: 0.65),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: textColor.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToAddEvent(
    BuildContext context,
    DateTime prefilledDate,
  ) async {
    final result = await Navigator.push(
      context,
      AppPageRoute(child: AddEventView(initialDate: prefilledDate)),
    );
    if (result == null || result is! Event) return;
    if (!context.mounted) return;

    final teamState = context.read<TeamBloc>().state;
    final selectedTeams = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();

    context.read<EventBloc>().add(
      AddEvent(
        result,
        clubId: selectedTeams.isEmpty ? null : selectedTeams.first.clubId,
        teamId: teamState.selectedTeamId,
      ),
    );
  }

}
