import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/design_tokens.dart';
import '../event/EventModel.dart';
import '../team/team_bloc.dart';
import '../members/MemberModel.dart';
import 'attendance_bloc.dart';

class AttendanceView extends StatelessWidget {
  final Event event;
  final String clubId;
  final String teamId;

  const AttendanceView({
    super.key,
    required this.event,
    required this.clubId,
    required this.teamId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final teamState = context.watch<TeamBloc>().state;
    final members = teamState.members;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Attendance', showTeamSwitcher: true),
      body: AppBackground(
        child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.type,
                    style: TextStyle(
                      fontFamily: 'Facon',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatDay(event.date)} • ${_formatTime(context, event.time)}',
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 14,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (clubId.isEmpty || teamId.isEmpty || event.eventId.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Attendance is available after this event is saved.',
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: BlocProvider(
                        create: (_) => AttendanceBloc()
                          ..add(LoadAttendance(
                            clubId: clubId,
                            teamId: teamId,
                            eventId: event.eventId,
                          )),
                        child: _AttendanceList(
                          members: members,
                          textColor: textColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  String _formatDay(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekDays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class _AttendanceList extends StatelessWidget {
  final List<Member> members;
  final Color textColor;

  const _AttendanceList({
    required this.members,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AttendanceBloc, AttendanceState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
        }
      },
      builder: (context, state) {
        if (state.isLoading && state.attendees.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (members.isEmpty) {
          return Center(
            child: Text(
              'No team members available for attendance.',
              style: TextStyle(color: textColor.withValues(alpha: 0.7)),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: members.length + 1, // +1 for header
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Attendance',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'SFPro',
                  ),
                ),
              );
            }
            final member = members[index - 1];
            final current = state.attendees
                .where((item) => item.playerUserId == member.userId)
                .toList();
            final status = current.isEmpty ? 'Absent' : current.first.status;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name, style: TextStyle(color: textColor)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: ['Present', 'Absent', 'Late', 'Excused']
                        .map(
                          (value) => ChoiceChip(
                            label: Text(value),
                            selected: status == value,
                            onSelected: (_) => context
                                .read<AttendanceBloc>()
                                .add(UpdatePlayerAttendance(
                                  playerUserId: member.userId,
                                  status: value,
                                )),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
