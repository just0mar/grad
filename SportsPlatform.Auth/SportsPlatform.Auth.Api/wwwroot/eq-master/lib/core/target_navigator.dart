import 'package:eqq/core/app_localizations.dart';
import 'package:eqq/main.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../addteam/AddTeamModel.dart';
import '../event/EventModel.dart';
import '../event/EventView.dart';
import '../event/event_bloc.dart';
import '../gamehistory/GameDetailHistoryView.dart';
import '../match/MatchDetailView.dart';
import '../members/MemberModel.dart';
import '../members/PlayerProfileView.dart';
import '../plans/PlansView.dart';
import '../profile/ProfileView.dart';
import '../services/event_service.dart';
import '../services/plan_service.dart';
import '../services/stats_service.dart';
import '../session/session_bloc.dart';
import '../team/TeamView.dart';
import '../team/team_bloc.dart';
import '../teamstats/stats_bloc.dart';
import '../teamstats/TeamStatsView.dart';
import 'app_transitions.dart';

/// ─── Home focus signal ───────────────────────────────────────────────────────
/// Lets a pushed page (search / notifications) ask MainNavigation to jump back to
/// the Home tab and scroll to / highlight a specific announcement.
class HomeFocus {
  HomeFocus._();

  /// The id of the announcement that should be scrolled to & highlighted.
  static final ValueNotifier<String?> announcementId =
      ValueNotifier<String?>(null);

  /// Registered by MainNavigation; switches the bottom-nav back to Home.
  static VoidCallback? requestHome;

  /// Registered by MainNavigation; switches the bottom-nav to the Team tab.
  static VoidCallback? requestTeam;

  /// Jump to Home and focus the given announcement.
  static void focusAnnouncement(String? id) {
    announcementId.value = null; // reset so a repeat tap still fires listeners
    announcementId.value = (id == null || id.isEmpty) ? null : id;
    requestHome?.call();
  }
}

/// ─── Central target router ───────────────────────────────────────────────────
/// Single entry point used by Search results and Notification taps. Resolves a
/// logical target (by [type] + ids) to the correct screen, auto-switching the
/// active team first when the target lives on a different team.
Future<void> openTarget({
  required BuildContext context,
  required String type,
  String? targetId,
  String? clubId,
  String? teamId,
  String? title,
  String? subtitle,
  String? metadataJson,
}) async {
  final navigator = Navigator.of(context);
  final teamBloc = context.read<TeamBloc>();
  final messenger = ScaffoldMessenger.of(context);
  final key = _canonicalType(type);

  switch (key) {
    case 'announcement':
      // No standalone detail page — go Home and scroll to the card.
      HomeFocus.focusAnnouncement(targetId);
      navigator.popUntil((route) => route.isFirst);
      return;

    case 'team':
      await _ensureTeam(teamBloc, teamId);
      final team = _teamById(teamBloc.state, teamId) ??
          _selectedTeam(teamBloc.state);
      if (team == null) {
        _notFound(messenger, 'team');
        return;
      }
      navigator.push(AppPageRoute(
        child: TeamView(
          sport: team.sport,
          teamName: team.club,
          userRole: team.memberRoles['self'] ??
              teamBloc.state.userRoleInSelectedTeam,
        ),
      ));
      return;

    case 'plan':
      await _ensureTeam(teamBloc, teamId);
      navigator.push(AppPageRoute(child: const PlansView()));
      return;

    case 'stats':
      await _ensureTeam(teamBloc, teamId);
      final s = teamBloc.state;
      final team = _selectedTeam(s);
      navigator.push(AppPageRoute(
        child: TeamStats(
          sport: team?.sport ?? 'Basketball',
          teamName: team?.club ?? s.selectedTeamName,
          userRole: s.userRoleInSelectedTeam,
        ),
      ));
      return;

    case 'user':
      await _ensureTeam(teamBloc, teamId);
      final member = _memberById(teamBloc.state, targetId);
      if (member == null) {
        _notFound(messenger, 'profile');
        return;
      }
      final index = teamBloc.state.members
          .indexWhere((m) => m.userId == member.userId);
      if (_isPlayerRole(member.role)) {
        final viewerIsPlayer =
            _isPlayerRole(teamBloc.state.userRoleInSelectedTeam);
        navigator.push(AppPageRoute(
          child: PlayerProfileView(
            member: member,
            memberIndex: index >= 0 ? index : 0,
            showOnlyThroughFitToPlay: viewerIsPlayer,
          ),
        ));
      } else {
        navigator.push(AppPageRoute(
          child: ProfileView(plans: const [], viewedMember: member),
        ));
      }
      return;

    case 'event':
      await _ensureTeam(teamBloc, teamId);
      final resolvedClub = (clubId != null && clubId.isNotEmpty)
          ? clubId
          : _selectedTeam(teamBloc.state)?.clubId;
      final resolvedTeam = (teamId != null && teamId.isNotEmpty)
          ? teamId
          : teamBloc.state.selectedTeamId;
      if (resolvedClub == null ||
          resolvedClub.isEmpty ||
          resolvedTeam.isEmpty ||
          targetId == null ||
          targetId.isEmpty) {
        _notFound(messenger, 'event');
        return;
      }
      try {
        final dto =
            await EventService().getEvent(resolvedClub, resolvedTeam, targetId);
        navigator.push(AppPageRoute(
          child: MatchDetailView(event: Event.fromDto(dto)),
        ));
      } catch (_) {
        _notFound(messenger, 'event');
      }
      return;

    default:
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).cannotOpen.replaceAll('%s', '${title ?? type}'))),
      );
  }
}

/// ─── Notification router ─────────────────────────────────────────────────────
/// Notifications share Search's destinations but a few types are smarter:
///   • fitness  → the player's profile, scrolled to the Fitness Records section
///   • medical  → the player's profile, scrolled to the Medical Records section
///   • event    → the calendar with that day's pop-up open
/// Everything else delegates to [openTarget].
Future<void> openNotification({
  required BuildContext context,
  required String type,
  String? targetType,
  String? targetId,
  String? clubId,
  String? teamId,
  String? title,
  String? subtitle,
  String? metadataJson,
}) async {
  final navigator = Navigator.of(context);
  final teamBloc = context.read<TeamBloc>();
  final session = context.read<SessionBloc>().state;
  final eventBloc = context.read<EventBloc>();
  final category = _notificationCategory(targetType, type, title, subtitle);

  switch (category) {
    case 'fitness':
    case 'medical':
      await _ensureTeam(teamBloc, teamId);
      final affected = _memberById(teamBloc.state, targetId);
      final Member member;
      int index;
      if (affected != null) {
        member = affected;
        index = teamBloc.state.members
            .indexWhere((m) => m.userId == affected.userId);
      } else {
        final userId = session.user?.userId ?? teamBloc.state.currentUserId;
        index = teamBloc.state.members.indexWhere((m) => m.userId == userId);
        member = index >= 0
            ? teamBloc.state.members[index]
            : Member(
                userId: userId,
                email: session.user?.email ?? '',
                name: session.user?.name ?? '',
                role: 'Player',
                profileImageUrl: session.user?.profileImageUrl,
              );
      }
      navigator.push(AppPageRoute(
        child: PlayerProfileView(
          member: member,
          memberIndex: index >= 0 ? index : 0,
          initialSection: category,
        ),
      ));
      return;

    case 'event':
      await _ensureTeam(teamBloc, teamId);
      final resolvedClub = (clubId != null && clubId.isNotEmpty)
          ? clubId
          : _selectedTeam(teamBloc.state)?.clubId;
      final resolvedTeam = (teamId != null && teamId.isNotEmpty)
          ? teamId
          : teamBloc.state.selectedTeamId;
      if (resolvedClub != null &&
          resolvedClub.isNotEmpty &&
          resolvedTeam.isNotEmpty) {
        eventBloc.add(LoadEvents(clubId: resolvedClub, teamId: resolvedTeam));
      }
      final date = await _resolveEventDate(
        metadataJson: metadataJson,
        clubId: resolvedClub,
        teamId: resolvedTeam,
        eventId: targetId,
      );
      navigator.push(AppPageRoute(child: EventView(focusDate: date)));
      return;

    case 'plan':
      await _ensureTeam(teamBloc, teamId);
      final planClub = (clubId != null && clubId.isNotEmpty)
          ? clubId
          : _selectedTeam(teamBloc.state)?.clubId;
      final planTeam = (teamId != null && teamId.isNotEmpty)
          ? teamId
          : teamBloc.state.selectedTeamId;
      if (planClub != null &&
          planClub.isNotEmpty &&
          planTeam.isNotEmpty &&
          targetId != null &&
          targetId.isNotEmpty) {
        try {
          final plans = await PlanService().getTeamPlans(planClub, planTeam);
          final matches = plans.where((p) => p.planId == targetId);
          if (matches.isNotEmpty) {
            navigator.push(
              AppPageRoute(child: PlanDetailView(plan: matches.first)),
            );
            return;
          }
        } catch (_) {
          // fall through to the plans list
        }
      }
      navigator.push(AppPageRoute(child: const PlansView()));
      return;

    case 'stats':
      await _ensureTeam(teamBloc, teamId);
      final statsClub = (clubId != null && clubId.isNotEmpty)
          ? clubId
          : _selectedTeam(teamBloc.state)?.clubId;
      final statsTeam = (teamId != null && teamId.isNotEmpty)
          ? teamId
          : teamBloc.state.selectedTeamId;
      if (statsClub != null &&
          statsClub.isNotEmpty &&
          statsTeam.isNotEmpty &&
          targetId != null &&
          targetId.isNotEmpty) {
        try {
          final rows = await StatsService().getMatchHistory(statsClub, statsTeam);
          for (final raw in rows) {
            final row = Map<String, dynamic>.from(raw as Map);
            if (_rowMatchesTarget(row, targetId)) {
              final game = gameHistoryFromRow(row);
              if (game != null) {
                navigator.push(AppPageRoute(
                  child: GameDetailHistoryView(
                    game: game,
                    userRole: teamBloc.state.userRoleInSelectedTeam,
                  ),
                ));
                return;
              }
            }
          }
        } catch (_) {
          // fall through to the stats list
        }
      }
      final statsState = teamBloc.state;
      final statsSelected = _selectedTeam(statsState);
      navigator.push(AppPageRoute(
        child: TeamStats(
          sport: statsSelected?.sport ?? 'Basketball',
          teamName: statsSelected?.club ?? statsState.selectedTeamName,
          userRole: statsState.userRoleInSelectedTeam,
        ),
      ));
      return;

    case 'lineup':
      await _ensureTeam(teamBloc, teamId);
      final lineupClub = (clubId != null && clubId.isNotEmpty)
          ? clubId
          : _selectedTeam(teamBloc.state)?.clubId;
      final lineupTeam = (teamId != null && teamId.isNotEmpty)
          ? teamId
          : teamBloc.state.selectedTeamId;
      // A lineup is attached to a match — resolve that match, then open its
      // details page (same destination as tapping the match).
      String? matchEventId;
      if (lineupClub != null &&
          lineupClub.isNotEmpty &&
          lineupTeam.isNotEmpty &&
          targetId != null &&
          targetId.isNotEmpty) {
        try {
          final lineups =
              await PlanService().getLineups(lineupClub, lineupTeam);
          final byLineup = lineups.where((l) => l.lineupId == targetId);
          if (byLineup.isNotEmpty) {
            matchEventId = byLineup.first.eventId;
          } else {
            final byEvent = lineups.where((l) => l.eventId == targetId);
            if (byEvent.isNotEmpty) matchEventId = targetId;
          }
        } catch (_) {
          // fall through — try targetId directly as an event id
        }
      }
      matchEventId ??= targetId;
      if (lineupClub != null &&
          lineupClub.isNotEmpty &&
          lineupTeam.isNotEmpty &&
          matchEventId != null &&
          matchEventId.isNotEmpty) {
        try {
          final dto = await EventService()
              .getEvent(lineupClub, lineupTeam, matchEventId);
          navigator.push(AppPageRoute(
            child: MatchDetailView(event: Event.fromDto(dto)),
          ));
          return;
        } catch (_) {
          // fall through to the calendar
        }
      }
      navigator.push(AppPageRoute(child: const EventView()));
      return;

    case 'announcement':
      HomeFocus.focusAnnouncement(targetId);
      navigator.popUntil((route) => route.isFirst);
      return;

    default:
      await openTarget(
        context: context,
        type: (targetType != null && targetType.isNotEmpty) ? targetType : type,
        targetId: targetId,
        clubId: clubId,
        teamId: teamId,
        title: title,
        subtitle: subtitle,
        metadataJson: metadataJson,
      );
  }
}

// ─── helpers ──────────────────────────────────────────────────────────────────

String _notificationCategory(
  String? targetType,
  String type,
  String? title,
  String? subtitle,
) {
  final hay =
      '${targetType ?? ''} $type ${title ?? ''} ${subtitle ?? ''}'.toLowerCase();
  if (hay.contains('fitness')) return 'fitness';
  if (hay.contains('medical') || hay.contains('injury')) return 'medical';
  if (hay.contains('announce')) return 'announcement';
  if (hay.contains('stat')) return 'stats';
  if (hay.contains('lineup') || hay.contains('line up')) return 'lineup';
  if (hay.contains('plan')) return 'plan';
  if (hay.contains('event') ||
      hay.contains('match') ||
      hay.contains('training') ||
      hay.contains('fixture')) {
    return 'event';
  }
  return 'other';
}

/// Whether a raw match-stats row corresponds to [targetId]. A stats
/// notification's targetId is the matchStatsId, but the row also carries the
/// eventId, so we accept either (plus a few key spellings) to be safe.
bool _rowMatchesTarget(Map<String, dynamic> row, String targetId) {
  for (final k in const [
    'matchStatsId',
    'eventId',
    'id',
    'matchId',
    'eventStatId',
    'statId',
  ]) {
    final v = row[k];
    if (v != null && v.toString() == targetId) return true;
  }
  return false;
}

Future<DateTime?> _resolveEventDate({
  String? metadataJson,
  String? clubId,
  String? teamId,
  String? eventId,
}) async {
  final fromMeta = _dateFromMetadata(metadataJson);
  if (fromMeta != null) return fromMeta;
  if (clubId != null &&
      clubId.isNotEmpty &&
      teamId != null &&
      teamId.isNotEmpty &&
      eventId != null &&
      eventId.isNotEmpty) {
    try {
      final dto = await EventService().getEvent(clubId, teamId, eventId);
      return dto.startAt;
    } catch (_) {
      // Event may have been deleted — fall through.
    }
  }
  return null;
}

DateTime? _dateFromMetadata(String? metadataJson) {
  if (metadataJson == null || metadataJson.isEmpty) return null;
  try {
    final decoded = jsonDecode(metadataJson);
    if (decoded is Map) {
      for (final k in const [
        'date',
        'startAt',
        'startsAt',
        'eventDate',
        'start',
        'occurredAt',
      ]) {
        final v = decoded[k];
        if (v != null) {
          final d = DateTime.tryParse(v.toString());
          if (d != null) return d;
        }
      }
    }
  } catch (_) {
    // not JSON / unexpected shape — ignore.
  }
  return null;
}


String _canonicalType(String raw) {
  final t = raw.trim().toLowerCase();
  if (t.contains('announcement')) return 'announcement';
  if (t.contains('team')) return 'team';
  if (t.contains('plan') || t.contains('lineup')) return 'plan';
  if (t.contains('stat')) return 'stats';
  if (t.contains('event') || t.contains('match') || t.contains('training')) {
    return 'event';
  }
  if (t.contains('user') ||
      t.contains('player') ||
      t.contains('member') ||
      t.contains('profile')) {
    return 'user';
  }
  return t;
}

/// Switches the active team to [teamId] (if known) and waits for the bloc to
/// settle. Best-effort: returns quietly on timeout or unknown team.
Future<void> _ensureTeam(TeamBloc teamBloc, String? teamId) async {
  if (teamId == null || teamId.isEmpty) return;
  if (teamBloc.state.selectedTeamId == teamId) return;
  final known = teamBloc.state.availableTeams.any((t) => t.id == teamId);
  if (!known) return;

  teamBloc.add(SwitchTeamContext(teamId));
  try {
    await teamBloc.stream
        .firstWhere((s) => s.selectedTeamId == teamId && !s.isLoading)
        .timeout(const Duration(seconds: 6));
  } catch (_) {
    // ignore — navigate with whatever state we have
  }
}

Team? _teamById(TeamState state, String? teamId) {
  if (teamId == null || teamId.isEmpty) return null;
  final matches = state.availableTeams.where((t) => t.id == teamId);
  return matches.isEmpty ? null : matches.first;
}

Team? _selectedTeam(TeamState state) {
  final matches =
      state.availableTeams.where((t) => t.id == state.selectedTeamId);
  return matches.isEmpty ? null : matches.first;
}

Member? _memberById(TeamState state, String? userId) {
  if (userId == null || userId.isEmpty) return null;
  for (final m in state.members) {
    if (m.userId == userId) return m;
  }
  return null;
}

bool _isPlayerRole(String role) =>
    role.trim().replaceAll(' ', '').toLowerCase() == 'player';

void _notFound(ScaffoldMessengerState messenger, String what) {
  messenger.showSnackBar(
    SnackBar(content: Text('Could not open this $what.')),
  );
}
