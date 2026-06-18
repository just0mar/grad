import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/design_tokens.dart';
import '../event/event_bloc.dart';
import '../event/EventModel.dart';
import '../core/app_transitions.dart';
import '../match/MatchDetailView.dart';

class DayEventsDetailView extends StatelessWidget {
  final DateTime date;
  final List<Event> events;

  const DayEventsDetailView({
    super.key,
    required this.date,
    required this.events,
  });

  static const List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final weekDay = _weekDays[date.weekday - 1];
    final month = _months[date.month - 1];
    final dateTitle = '$weekDay, $month ${date.day}';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(title: "Events"),
      body: AppBackground(
        child: SafeArea(
            child: BlocBuilder<EventBloc, EventState>(
              builder: (context, eventState) {
                final dayKey = DateTime(date.year, date.month, date.day);
                final eventsForDay = eventState.eventsByDay[dayKey] ?? [];
                if (eventsForDay.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  });
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── date header ──
                      Text(
                        dateTitle,
                        style: TextStyle(
                          fontFamily: 'Facon',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${eventsForDay.length} event${eventsForDay.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 14,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (eventsForDay.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No events on this day.',
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              fontSize: 14,
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        )
                      else
                        ...eventsForDay.map(
                          (event) => _buildEventDetailCard(
                            context,
                            event,
                            isDark,
                            textColor,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
    );
  }

  Widget _buildEventDetailCard(
    BuildContext context,
    Event event,
    bool isDark,
    Color textColor,
  ) {
    final icon = _typeIcon(event.type);
    final timeStr = _formatTime(event.time);
    final dayLabel = _formatDayLabel(event.date);
    final typeColor = _typeColor(event.type);
    final detailTitle = '${event.type} Details';

    return AnimatedPressable(
      onTap: () => Navigator.push(
        context,
        AppPageRoute(
          child: MatchDetailView(event: event, title: detailTitle),
        ),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [typeColor, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: typeColor.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── faded icon behind content ──
              Positioned(
                right: 10,
                top: 5,
                bottom: 5,
                child: Icon(
                  icon,
                  size: 110,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── type icon + label (no box) ──
                    Row(
                      children: [
                        Icon(icon, color: Colors.black87, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          event.type.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Facon',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── time ──
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.black.withValues(alpha: 0.6),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontFamily: 'SFPro',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── description ──
                    if (event.description.isNotEmpty)
                      Text(
                        event.description,
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 14,
                          color: Colors.black.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _typeColor(String type) {
    switch (type.trim()) {
      case 'Match':
        return Colors.blue.shade900;
      case 'Training':
        return Colors.green.shade900;
      case 'Meeting':
        return Colors.green.shade400;
      case 'Test':
        return const Color(0xFF082E6F);
      default:
        return Colors.grey.shade700;
    }
  }

  static IconData _typeIcon(String type) {
    switch (type.trim()) {
      case 'Match':
        return Icons.sports_soccer;
      case 'Training':
        return Icons.fitness_center;
      case 'Meeting':
        return Icons.event_note;
      case 'Test':
        return Icons.science;
      default:
        return Icons.event;
    }
  }

  static String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  static String _formatDayLabel(DateTime date) {
    const weekDays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${weekDays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}
