import 'package:eqq/core/app_localizations.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../addevent/AddEventView.dart';
import '../addplans/AddPlansView.dart';
import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/app_transitions.dart';
import '../core/design_tokens.dart';
import '../event/EventModel.dart';
import '../event/attendance_bloc.dart';
import '../location/location_point.dart';
import '../location/route_map_view.dart';
import '../members/MemberModel.dart';
import '../models/api_models.dart';
import '../plans/PlansView.dart';
import '../services/api_client.dart';
import '../services/event_document_service.dart';
import '../services/file_cache_service.dart';
import '../services/event_service.dart';
import '../services/plan_service.dart';
import '../services/stats_service.dart';
import '../team/team_bloc.dart';

class MatchDetailView extends StatefulWidget {
  final Event event;
  final String? title;

  const MatchDetailView({super.key, required this.event, this.title});

  @override
  State<MatchDetailView> createState() => _MatchDetailViewState();
}

class _MatchDetailViewState extends State<MatchDetailView>
    with TickerProviderStateMixin {
  Event get event => widget.event;

  // ── squad state ──
  bool _showReserves = false;
  final Set<String> _starterIds = {};
  final Set<String> _reserveIds = {};
  bool _squadInitialised = false;
  bool _isSquadEditing = false;
  Set<String> _starterSnapshot = {};
  Set<String> _reserveSnapshot = {};
  bool _squadSaving = false;
  String? _existingLineupId;

  // ── attendance state ──
  bool _isAttendanceEditing = false;
  Map<String, String> _localAttendance = {};
  Map<String, String> _attendanceSnapshot = {};
  bool _attendanceSaving = false;

  // ── document state ──
  final EventDocumentService _docService = EventDocumentService();
  final PlanService _planService = PlanService();
  List<EventDocumentDto> _documents = [];
  List<PlanDto> _eventPlans = [];
  bool _docsLoading = false;
  bool _plansLoading = false;
  bool _uploading = false;
  bool _planSaving = false;

  // ── analyst stats state ──
  final StatsService _statsService = StatsService();
  final EventService _eventService = EventService();
  bool _statsUploading = false;
  List<Map<String, dynamic>>? _extractedRows;
  int _extractedPlayerCount = 0;
  int _extractedTeamTotalCount = 0;
  int _savedExtractedRowCount = 0;
  String? _statsError;
  bool _statsConfirming = false;
  bool _statsSaved = false;
  bool _statsDeleting = false;

  // ── raw stats PDF state ──
  String? _pendingPdfPath; // file just picked, persisted after confirm
  Uint8List? _pendingPdfBytes;
  String? _pendingPdfName;
  bool _hasRawPdf = false;
  String? _rawPdfFileName;
  bool _openingRawPdf = false;

  // ── event edit/delete state ──
  bool _eventUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _loadEventPlans();
    _loadExistingSquad();
    _loadExistingStats();
  }

  // ── Event timing helpers ──
  DateTime get _eventStart => DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        event.time.hour,
        event.time.minute,
      );

  bool get _hasEventStarted => DateTime.now().isAfter(_eventStart);

  // Saved stats can be deleted up to 24h after the match start.
  bool get _canDeleteStats =>
      DateTime.now().isBefore(_eventStart.add(const Duration(hours: 24)));

  void _loadExistingStats() {
    final teamState = context.read<TeamBloc>().state;
    final selected = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();
    final clubId = selected.isEmpty ? null : selected.first.clubId;
    if (clubId == null ||
        teamState.selectedTeamId.isEmpty ||
        event.eventId.isEmpty) {
      return;
    }
    _statsService
        .getMatchStats(clubId, teamState.selectedTeamId, event.eventId)
        .then((data) {
          if (!mounted) return;
          if (data != null && data is Map && data.isNotEmpty) {
            setState(() {
              _statsSaved = true;
              _hasRawPdf = data['hasRawPdf'] == true;
              _rawPdfFileName = data['rawPdfFileName']?.toString();
            });
          }
        })
        .catchError((_) {});
  }

  // ── Event edit/delete (staff, before kickoff) ──

  Widget _eventActionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _editEvent(String? clubId, String teamId) async {
    if (clubId == null || teamId.isEmpty || event.eventId.isEmpty) return;
    final updated = await Navigator.push<Event>(
      context,
      AppPageRoute(child: AddEventView(initialEvent: event)),
    );
    if (updated == null || !mounted) return;

    setState(() => _eventUpdating = true);
    try {
      final startAt = DateTime(
        updated.date.year,
        updated.date.month,
        updated.date.day,
        updated.time.hour,
        updated.time.minute,
      );
      await _eventService.updateEvent(clubId, teamId, event.eventId, {
        'seasonId': event.seasonId,
        'title': updated.description.isNotEmpty
            ? updated.description
            : updated.type,
        'eventType': updated.type,
        'startAt': startAt.toIso8601String(),
        'endAt': startAt.add(const Duration(hours: 2)).toIso8601String(),
        'description': updated.description,
        if (updated.location?.isNotEmpty == true) 'location': updated.location,
        if (updated.locationLatitude != null)
          'locationLatitude': updated.locationLatitude,
        if (updated.locationLongitude != null)
          'locationLongitude': updated.locationLongitude,
        'timezone': DateTime.now().timeZoneName,
        if (updated.recurrenceRule != null)
          'recurrenceRule': updated.recurrenceRule,
        if (updated.recurrenceEndDate != null)
          'recurrenceEndDate': updated.recurrenceEndDate!.toIso8601String(),
      });
      if (!mounted) return;
      setState(() => _eventUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).eventUpdated)),
      );
      // Return to the previous screen so it reloads the refreshed event.
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _eventUpdating = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).eventUpdateError(e.toString()))));
      }
    }
  }

  Future<void> _deleteEvent(String? clubId, String teamId) async {
    if (clubId == null || teamId.isEmpty || event.eventId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteEventTitle),
        content: const Text(
          'This will permanently delete this event and everything attached '
          'to it. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _eventUpdating = true);
    try {
      await _eventService.deleteEvent(clubId, teamId, event.eventId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).eventDeleted)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _eventUpdating = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).eventDeleteError(e.toString()))));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SQUAD LOGIC
  // ═══════════════════════════════════════════════════════════════════════

  void _initSquadFromMembers(List<Member> players) {
    if (_squadInitialised) return;
    _squadInitialised = true;
    // Seed from existing member isInSquad flags as fallback
    for (final p in players) {
      if (p.isInjured) continue;
      if (p.isInSquad) _starterIds.add(p.userId);
    }
  }

  void _loadExistingSquad() {
    // Attempt to load lineup for this event from backend
    final teamState = context.read<TeamBloc>().state;
    final selected = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();
    final clubId = selected.isEmpty ? null : selected.first.clubId;
    if (clubId == null || teamState.selectedTeamId.isEmpty) return;
    if (event.eventId.isEmpty) return;

    _planService
        .getLineups(clubId, teamState.selectedTeamId)
        .then((lineups) {
          if (!mounted) return;
          final matching = lineups
              .where((l) => l.eventId == event.eventId)
              .toList();
          if (matching.isEmpty) return;
          final lineup = matching.first;
          setState(() {
            _existingLineupId = lineup.lineupId;
            _starterIds.clear();
            _reserveIds.clear();
            for (final p in lineup.players) {
              if (p.unit == 'Reserve') {
                _reserveIds.add(p.userId);
              } else {
                _starterIds.add(p.userId);
              }
            }
            _squadInitialised = true;
          });
        })
        .catchError((_) {});
  }

  void _enterSquadEditMode() {
    setState(() {
      _isSquadEditing = true;
      _starterSnapshot = Set.from(_starterIds);
      _reserveSnapshot = Set.from(_reserveIds);
    });
  }

  void _discardSquad() {
    setState(() {
      _isSquadEditing = false;
      _starterIds
        ..clear()
        ..addAll(_starterSnapshot);
      _reserveIds
        ..clear()
        ..addAll(_reserveSnapshot);
    });
  }

  Future<void> _saveSquad(BuildContext context) async {
    final teamState = context.read<TeamBloc>().state;
    final selected = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();
    final clubId = selected.isEmpty ? null : selected.first.clubId;
    if (clubId == null) return;

    setState(() => _squadSaving = true);

    // Build player list for lineup API
    final players = <Map<String, dynamic>>[];
    int order = 0;
    for (final id in _starterIds) {
      final member = teamState.members.where((m) => m.userId == id).toList();
      var pos = member.isNotEmpty ? (member.first.position ?? '') : '';
      if (pos.trim().isEmpty) pos = 'Unassigned';
      players.add({
        'playerUserId': id,
        'position': pos,
        'unit': 'Starting',
        'sortOrder': order++,
      });
    }
    for (final id in _reserveIds) {
      final member = teamState.members.where((m) => m.userId == id).toList();
      var pos = member.isNotEmpty ? (member.first.position ?? '') : '';
      if (pos.trim().isEmpty) pos = 'Unassigned';
      players.add({
        'playerUserId': id,
        'position': pos,
        'unit': 'Reserve',
        'sortOrder': order++,
      });
    }

    final body = {
      'eventId': event.eventId,
      'title': 'Game Squad - ${event.description}',
      'visibility': 'TeamVisible',
      'players': players,
    };

    try {
      LineupDto result;
      if (_existingLineupId != null) {
        result = await _planService.updateLineup(
          clubId,
          teamState.selectedTeamId,
          _existingLineupId!,
          body,
        );
      } else {
        result = await _planService.createLineup(
          clubId,
          teamState.selectedTeamId,
          body,
        );
      }
      _existingLineupId = result.lineupId;

      // Also update local member squad state
      final allMembers = teamState.members;
      for (int i = 0; i < allMembers.length; i++) {
        final m = allMembers[i];
        if (m.role != 'Player' || m.isInjured) continue;
        final shouldBeInSquad =
            _starterIds.contains(m.userId) || _reserveIds.contains(m.userId);
        if (m.isInSquad != shouldBeInSquad) {
          context.read<TeamBloc>().add(UpdateMemberStatus(i, shouldBeInSquad));
        }
      }

      if (mounted) {
        setState(() {
          _isSquadEditing = false;
          _squadSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).squadSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _squadSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).squadSaveError(e.toString()))));
      }
    }
  }

  void _togglePlayer(String userId) {
    if (!_isSquadEditing) return;
    
    if (!_showReserves) {
      if (_starterIds.contains(userId)) {
        setState(() => _starterIds.remove(userId));
      } else {
        if (_starterIds.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).squadSaveError('Maximum 5 starters allowed.'))),
          );
          return;
        }
        setState(() {
          _reserveIds.remove(userId);
          _starterIds.add(userId);
        });
      }
    } else {
      if (_reserveIds.contains(userId)) {
        setState(() => _reserveIds.remove(userId));
      } else {
        setState(() {
          _starterIds.remove(userId);
          _reserveIds.add(userId);
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ATTENDANCE LOGIC
  // ═══════════════════════════════════════════════════════════════════════

  bool _canEditAttendance() {
    // Attendance can be edited until 24 hours after the event starts.
    final cutoff = _eventStart.add(const Duration(hours: 24));
    return DateTime.now().isBefore(cutoff);
  }

  void _enterAttendanceEditMode(List<AttendanceDto> attendees) {
    setState(() {
      _isAttendanceEditing = true;
      _localAttendance = {};
      for (final a in attendees) {
        _localAttendance[a.playerUserId] = a.status;
      }
      _attendanceSnapshot = Map.from(_localAttendance);
    });
  }

  void _discardAttendance() {
    setState(() {
      _isAttendanceEditing = false;
      _localAttendance = Map.from(_attendanceSnapshot);
    });
  }

  Future<void> _saveAttendance(BuildContext ctx) async {
    setState(() => _attendanceSaving = true);
    try {
      final bloc = ctx.read<AttendanceBloc>();

      // Collect ALL attendance entries (changed + unchanged) and send
      // them as a single batch. This avoids the race condition where
      // multiple individual UpdatePlayerAttendance events trigger
      // concurrent reloads that overwrite each other.
      final allEntries = _localAttendance.entries
          .map((e) => {'playerUserId': e.key, 'status': e.value})
          .toList();

      if (allEntries.isNotEmpty) {
        bloc.add(RecordAttendance(allEntries));

        // Wait for the bloc to finish its API call and reload from server.
        // This ensures the BlocConsumer rebuilds with fresh data before we
        // exit edit mode.
        await bloc.stream
            .firstWhere((s) => !s.isLoading)
            .timeout(const Duration(seconds: 10));
      }

      if (mounted) {
        setState(() {
          _attendanceSnapshot = Map.from(_localAttendance);
          _isAttendanceEditing = false;
          _attendanceSaving = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).attendanceSaved)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _attendanceSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).attendanceSaveError(e.toString()))),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  DOCUMENT LOGIC
  // ═══════════════════════════════════════════════════════════════════════

  void _loadDocuments() {
    final teamState = context.read<TeamBloc>().state;
    final selected = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();
    final clubId = selected.isEmpty ? null : selected.first.clubId;
    if (clubId == null ||
        teamState.selectedTeamId.isEmpty ||
        event.eventId.isEmpty)
      return;

    setState(() => _docsLoading = true);
    _docService
        .getEventDocuments(clubId, teamState.selectedTeamId, event.eventId)
        .then((docs) {
          if (mounted)
            setState(() {
              _documents = docs;
              _docsLoading = false;
            });
        })
        .catchError((_) {
          if (mounted) setState(() => _docsLoading = false);
        });
  }

  void _loadEventPlans() {
    final teamState = context.read<TeamBloc>().state;
    final selected = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();
    final clubId = selected.isEmpty ? null : selected.first.clubId;
    if (clubId == null ||
        teamState.selectedTeamId.isEmpty ||
        event.eventId.isEmpty)
      return;

    setState(() => _plansLoading = true);
    _planService
        .getEventPlans(clubId, teamState.selectedTeamId, event.eventId)
        .then((plans) {
          if (mounted)
            setState(() {
              _eventPlans = plans;
              _plansLoading = false;
            });
        })
        .catchError((_) {
          if (mounted) setState(() => _plansLoading = false);
        });
  }

  Future<void> _openAddPlanFlow() async {
    final teamState = context.read<TeamBloc>().state;
    final selected = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();
    final clubId = selected.isEmpty ? null : selected.first.clubId;
    if (clubId == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: AppRadius.all(AppRadius.xl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_add,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Add a plan',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Attach one you already have, or build a new one',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
                child: Column(
                  children: [
                    _buildPlanFlowOption(
                      ctx,
                      icon: Icons.playlist_add_check_rounded,
                      title: 'Choose existing plan',
                      subtitle: 'Pick from your team-visible plans',
                      value: 'existing',
                      isDark: isDark,
                      textColor: textColor,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _buildPlanFlowOption(
                      ctx,
                      icon: Icons.add_circle_outline_rounded,
                      title: 'Make a new plan',
                      subtitle: 'Create a plan and attach it here',
                      value: 'new',
                      isDark: isDark,
                      textColor: textColor,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
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
    if (!mounted || action == null) return;
    if (action == 'existing') {
      await _chooseExistingPlan(clubId, teamState);
    } else {
      await _createAndAttachPlan(clubId, teamState);
    }
  }

  Widget _buildPlanFlowOption(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required bool isDark,
    required Color textColor,
  }) {
    return AnimatedPressable(
      onTap: () => Navigator.pop(ctx, value),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: AppRadius.all(AppRadius.lg),
          border: Border.all(
            color: AppColors.brand.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.15),
                borderRadius: AppRadius.all(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.brand, size: 24),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary(ctx),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseExistingPlan(String clubId, TeamState teamState) async {
    setState(() => _planSaving = true);
    try {
      final attachedIds = _eventPlans.map((p) => p.planId).toSet();
      final allPlans = await _planService.getTeamPlans(
        clubId,
        teamState.selectedTeamId,
      );
      final visiblePlans = allPlans
          .where(
            (p) =>
                p.visibility == 'TeamVisible' &&
                p.createdBy == teamState.currentUserId &&
                !attachedIds.contains(p.planId),
          )
          .toList();
      if (!mounted) return;
      setState(() => _planSaving = false);
      if (visiblePlans.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).noTeamVisiblePlans)),
        );
        return;
      }

      final chosen = await showModalBottomSheet<PlanDto>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        barrierColor: Colors.black.withValues(alpha: 0.15),
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black;
          
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: AppRadius.all(AppRadius.xl),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Select Plan',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
                      itemCount: visiblePlans.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final plan = visiblePlans[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(ctx, plan),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.brand,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.assignment, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        plan.title,
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        plan.description?.isNotEmpty == true
                                            ? plan.description!
                                            : 'Team-visible plan',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (chosen != null) {
        await _attachPlan(clubId, teamState.selectedTeamId, chosen.planId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _planSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).loadPlansError(e.toString()))));
      }
    }
  }

  Future<void> _createAndAttachPlan(String clubId, TeamState teamState) async {
    final result = await Navigator.push(
      context,
      AppPageRoute(
        child: const AddPlanScreen(initialVisibility: 'TeamVisible'),
      ),
    );
    if (result is! Map<String, dynamic> || !mounted) return;

    setState(() => _planSaving = true);
    try {
      final tacticalBoardData = result['tacticalBoardData']?.toString();
      final content = {
        'description': result['description']?.toString() ?? '',
        'category': result['category']?.toString() ?? 'Offensive',
        if (tacticalBoardData != null) 'tacticalBoardData': tacticalBoardData,
      };
      final created = await _planService
          .createPlan(clubId, teamState.selectedTeamId, {
            'title': result['title']?.toString() ?? '',
            'description': result['description']?.toString() ?? '',
            'content': jsonEncode(content),
            'visibility': 'TeamVisible',
          });
      final attachments =
          (result['attachments'] as List?)?.cast<PlatformFile>() ?? [];
      for (final file in attachments) {
        await _planService.uploadPlanDocument(
          clubId,
          teamState.selectedTeamId,
          created.planId,
          file,
        );
      }
      await _attachPlan(clubId, teamState.selectedTeamId, created.planId);
    } catch (e) {
      if (mounted) {
        setState(() => _planSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).addPlanError(e.toString()))));
      }
    }
  }

  Future<void> _attachPlan(String clubId, String teamId, String planId) async {
    setState(() => _planSaving = true);
    try {
      await _planService.attachEventPlan(clubId, teamId, event.eventId, planId);
      final plans = await _planService.getEventPlans(
        clubId,
        teamId,
        event.eventId,
      );
      if (mounted) {
        setState(() {
          _eventPlans = plans;
          _planSaving = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).planAddedToMatch)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _planSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).attachPlanError(e.toString()))));
      }
    }
  }

  Future<void> _pickAndUploadDocument() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final String? path = kIsWeb ? null : file.path;
    if (path == null && file.bytes == null) return;
    if (!mounted) return;

    final description = await _askDocumentDescription(file.name);
    if (description == null) return;

    final teamState = context.read<TeamBloc>().state;
    final selected = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();
    final clubId = selected.isEmpty ? null : selected.first.clubId;
    if (clubId == null) return;

    setState(() => _uploading = true);
    try {
      final doc = await _docService.uploadDocument(
          clubId,
          teamState.selectedTeamId,
          event.eventId,
          file,
          description,
        );
      if (mounted) {
        setState(() {
          _documents.insert(0, doc);
          _uploading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).documentUploaded)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).uploadFailed(e.toString()))));
      }
    }
  }

  Future<String?> _askDocumentDescription(String fileName) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.15), // Reduced opacity
      builder: (ctx) => _DocumentDescriptionBottomSheet(fileName: fileName),
    );
  }

  Future<void> _openDocument(EventDocumentDto doc) async {
    try {
      // Show a loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context).downloadingDocument),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      // Use FileCacheService to get the file instantly if downloaded before
      final fileCache = FileCacheService.instance;
      final tempFile = await fileCache.getFile('/events/documents/${doc.documentId}/download');
      
      if (!mounted) return;

      // Dismiss the loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Open with the device's default app
      final result = await OpenFilex.open(
        tempFile.path,
        type: doc.contentType,
      );

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).openFileError(result.message))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).openDocumentError(e.toString()))));
      }
    }
  }

  Future<void> _deleteDocument(EventDocumentDto doc) async {
    final teamState = context.read<TeamBloc>().state;
    final selected = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();
    final clubId = selected.isEmpty ? null : selected.first.clubId;
    if (clubId == null) return;

    try {
      await _docService.deleteDocument(
        clubId,
        teamState.selectedTeamId,
        event.eventId,
        doc.documentId,
      );
      if (mounted) {
        setState(
          () => _documents.removeWhere((d) => d.documentId == doc.documentId),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).documentDeleted)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).deleteFailed(e.toString()))));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;

    return BlocBuilder<TeamBloc, TeamState>(
      builder: (context, teamState) {
        final role = teamState.userRoleInSelectedTeam.trim();
        final roleKey = role.replaceAll(RegExp(r'\s+'), '').toLowerCase();
        final isCoach = roleKey == 'coach';
        final isTeamManager = roleKey == 'teammanager';
        final isAnalyst = roleKey == 'analyst' || roleKey == 'teamanalyst';
        final isStaff =
            isCoach ||
            isTeamManager ||
            isAnalyst ||
            roleKey == 'clubmanager' ||
            roleKey == 'teamdoctor' ||
            roleKey == 'fitnesscoach';
        final players = teamState.members
            .where((m) => m.role == 'Player')
            .toList();
        final allMembers = teamState.members;
        final selected = teamState.availableTeams
            .where((t) => t.id == teamState.selectedTeamId)
            .toList();
        final clubId = selected.isEmpty ? null : selected.first.clubId;

        _initSquadFromMembers(players);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: CustomAppBar(
            title: widget.title ?? 'Match Details',
            showBackButton: true,
          ),
          body: AppBackground(
            child: SafeArea(
              child: SingleChildScrollView(
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
                    _buildEventCard(context, isStaff, clubId,
                        teamState.selectedTeamId),
                    const SizedBox(height: 28),

                    // ── GAME SQUAD (Match only) ──
                    if (event.type.trim() == 'Match') ...[
                      _buildSquadHeader(textColor, isCoach),
                      const SizedBox(height: 12),
                      if (isCoach)
                        _buildCoachSquadSection(
                          context,
                          players,
                          isDark,
                          cardBg,
                          textColor,
                          teamState,
                        )
                      else
                        _buildViewerSquadSection(
                          players,
                          isDark,
                          cardBg,
                          textColor,
                        ),
                      const SizedBox(height: 28),
                    ],

                    // ── ATTENDANCE (team manager only) ──
                    if (isTeamManager) ...[
                      _buildAttendanceSection(
                        context,
                        allMembers,
                        clubId,
                        teamState.selectedTeamId,
                        isDark,
                        cardBg,
                        textColor,
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── PLANS (match events) ──
                    if (event.type.trim() == 'Match') ...[
                      _buildPlansSection(isDark, cardBg, textColor, isCoach),
                      const SizedBox(height: 28),
                    ],

                    // ── MATCH STATS (analyst only, match events) ──
                    if (event.type.trim() == 'Match' && isAnalyst) ...[
                      _buildAnalystStatsSection(
                        context,
                        isDark,
                        cardBg,
                        textColor,
                        clubId,
                        teamState.selectedTeamId,
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── DOCUMENTS & UPLOADS ──
                    _buildDocumentSection(isDark, cardBg, textColor, isStaff),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SQUAD HEADER — only discard icon at top when editing
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSquadHeader(Color textColor, bool isCoach) {
    return Row(
      children: [
        Text(
          'GAME SQUAD',
          style: TextStyle(
            fontFamily: 'Facon',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: textColor,
          ),
        ),
        const Spacer(),
        if (isCoach) ...[
          if (_isSquadEditing)
            _styledIconButton(
              icon: Icons.close_rounded,
              color: Colors.red,
              bgColor: Colors.red.withValues(alpha: 0.12),
              tooltip: 'Discard',
              onTap: _discardSquad,
            )
          else
            _styledIconButton(
              icon: Icons.edit_rounded,
              color: textColor.withValues(alpha: 0.6),
              bgColor: textColor.withValues(alpha: 0.06),
              tooltip: 'Edit squad',
              onTap: _enterSquadEditMode,
            ),
        ],
      ],
    );
  }

  Widget _styledIconButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return AnimatedButton.icon(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  EVENT CARD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildEventCard(
    BuildContext context,
    bool isStaff,
    String? clubId,
    String teamId,
  ) {
    final typeColor = _typeColor(event.type);
    // Staff can edit/delete the event itself until it starts.
    final showEventActions =
        isStaff && !_hasEventStarted && event.eventId.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: typeColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_typeIcon(event.type), color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                event.type.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 12,
                  fontFamily: 'SFPro',
                ),
              ),
              if (showEventActions) ...[
                const Spacer(),
                _eventActionIcon(
                  icon: Icons.edit_rounded,
                  tooltip: 'Edit event',
                  onTap: _eventUpdating
                      ? null
                      : () => _editEvent(clubId, teamId),
                ),
                const SizedBox(width: 8),
                _eventActionIcon(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete event',
                  onTap: _eventUpdating
                      ? null
                      : () => _deleteEvent(clubId, teamId),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${event.date.day}/${event.date.month}/${event.date.year}  ${event.time.format(context)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'SFPro',
            ),
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              event.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontFamily: 'SFPro',
              ),
            ),
          ],
          if (event.location != null && event.location!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildLocationRow(context),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationRow(BuildContext context) {
    final hasCoords =
        event.locationLatitude != null && event.locationLongitude != null;
    final row = Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          color: Colors.white.withValues(alpha: 0.7),
          size: 16,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            event.location!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontFamily: 'SFPro',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasCoords) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.directions_outlined,
            color: Colors.white.withValues(alpha: 0.9),
            size: 16,
          ),
          const SizedBox(width: 2),
          Text(
            'Route',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'SFPro',
            ),
          ),
        ],
      ],
    );

    if (!hasCoords) return row;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openRouteMap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }

  Future<void> _openRouteMap(BuildContext context) async {
    final url = 'https://maps.google.com/?q=${event.locationLatitude},${event.locationLongitude}';
    try {
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).openMapError)));
        }
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  VIEWER (non-coach): toggle → filtered cards (view only)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildViewerSquadSection(
    List<Member> players,
    bool isDark,
    Color cardBg,
    Color textColor,
  ) {
    final starters = players
        .where((p) => !p.isInjured && _starterIds.contains(p.userId))
        .toList();
    final reserves = players
        .where((p) => !p.isInjured && _reserveIds.contains(p.userId))
        .toList();
    final visible = _showReserves ? reserves : starters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSquadToggle(
          isDark,
          textColor,
          starterCount: starters.length,
          reserveCount: reserves.length,
        ),
        const SizedBox(height: 14),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: visible.isEmpty
              ? _buildEmptyBox(
                  isDark,
                  cardBg,
                  _showReserves
                      ? 'No reserves selected.'
                      : 'No starters selected.',
                  Icons.groups_outlined,
                )
              : _buildPlayerGrid(
                  visible,
                  isDark,
                  cardBg,
                  textColor,
                  tappable: false,
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  COACH: pool → toggle → selected → save button
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCoachSquadSection(
    BuildContext context,
    List<Member> players,
    bool isDark,
    Color cardBg,
    Color textColor,
    TeamState teamState,
  ) {
    final eligible = players.where((p) => !p.isInjured).toList();
    final injured = players.where((p) => p.isInjured).toList();
    final pool = eligible
        .where(
          (p) =>
              !_starterIds.contains(p.userId) &&
              !_reserveIds.contains(p.userId),
        )
        .toList();
    final starters = eligible
        .where((p) => _starterIds.contains(p.userId))
        .toList();
    final reserves = eligible
        .where((p) => _reserveIds.contains(p.userId))
        .toList();
    final selectedList = _showReserves ? reserves : starters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Unassigned pool (edit mode only) ──
        if (_isSquadEditing && (pool.isNotEmpty || injured.isNotEmpty)) ...[
          Text(
            'AVAILABLE PLAYERS',
            style: TextStyle(
              fontFamily: 'SFPro',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: textColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                if (pool.isNotEmpty)
                  _buildPlayerGrid(
                    pool,
                    isDark,
                    cardBg,
                    textColor,
                    tappable: true,
                  ),
                if (pool.isNotEmpty && injured.isNotEmpty)
                  const SizedBox(height: 14),
                if (injured.isNotEmpty)
                  _buildPlayerGrid(
                    injured,
                    isDark,
                    cardBg,
                    textColor,
                    tappable: false,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Toggle ──
        _buildSquadToggle(
          isDark,
          textColor,
          starterCount: starters.length,
          reserveCount: reserves.length,
        ),
        const SizedBox(height: 14),

        // ── Selected cards ──
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: selectedList.isEmpty
              ? _buildEmptyBox(
                  isDark,
                  cardBg,
                  _isSquadEditing
                      ? (_showReserves
                            ? 'Tap a player above to add as reserve.'
                            : 'Tap a player above to add as starter.')
                      : (_showReserves
                            ? 'No reserves selected.'
                            : 'No starters selected.'),
                  Icons.groups_outlined,
                )
              : _buildPlayerGrid(
                  selectedList,
                  isDark,
                  cardBg,
                  textColor,
                  tappable: _isSquadEditing,
                  isSelected: true,
                ),
        ),

        // ── Save button (edit mode only) — rounded auth-style ──
        if (_isSquadEditing) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: AnimatedButton.primary(
              child: ElevatedButton(
                onPressed: _squadSaving ? null : () => _saveSquad(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _squadSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Save Squad',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SQUAD TOGGLE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSquadToggle(
    bool isDark,
    Color textColor, {
    int starterCount = 0,
    int reserveCount = 0,
  }) {
    final containerBg = isDark ? const Color(0xFF1B3A2D) : Colors.grey.shade200;
    final activeBg = isDark ? Colors.green.shade700 : Colors.green;
    final activeText = Colors.white;
    final inactiveText = textColor.withValues(alpha: 0.55);

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: _showReserves ? halfWidth : 0,
                top: 0,
                bottom: 0,
                width: halfWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: activeBg,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: activeBg.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showReserves = false),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: !_showReserves ? activeText : inactiveText,
                          ),
                          child: Text(AppLocalizations.of(context).startersCount(starterCount)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showReserves = true),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _showReserves ? activeText : inactiveText,
                          ),
                          child: Text(AppLocalizations.of(context).reservesCount(reserveCount)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PLAYER GRID
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPlayerGrid(
    List<Member> players,
    bool isDark,
    Color cardBg,
    Color textColor, {
    required bool tappable,
    bool isSelected = false,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: players.length,
      itemBuilder: (context, index) {
        return _buildPlayerCard(
          players[index],
          isDark,
          cardBg,
          textColor,
          tappable: tappable,
          isSelected: isSelected,
        );
      },
    );
  }

  Widget _buildPlayerCard(
    Member member,
    bool isDark,
    Color cardBg,
    Color textColor, {
    required bool tappable,
    bool isSelected = false,
  }) {
    final profileUrl = ApiClient.resolveUrl(member.profileImageUrl);
    final hasPhoto = profileUrl != null && profileUrl.isNotEmpty;
    final posLabel = (member.position != null && member.position!.isNotEmpty)
        ? member.position!
        : null;
    final jerseyLabel = member.jerseyNumber != null
        ? '#${member.jerseyNumber}'
        : null;
    final isInjured = member.isInjured;
    final bool isStarter = _starterIds.contains(member.userId);
    final bool isReserve = _reserveIds.contains(member.userId);

    BorderSide borderSide;
    if (isInjured) {
      borderSide = BorderSide(
        color: Colors.red.withValues(alpha: 0.4),
        width: 1.2,
      );
    } else if (isSelected && isStarter) {
      borderSide = BorderSide(
        color: Colors.green.withValues(alpha: 0.5),
        width: 1.5,
      );
    } else if (isSelected && isReserve) {
      borderSide = BorderSide(
        color: Colors.orange.withValues(alpha: 0.5),
        width: 1.5,
      );
    } else {
      borderSide = BorderSide.none;
    }

    return AnimatedPressable(
      onTap: tappable && !isInjured ? () => _togglePlayer(member.userId) : null,
      child: Card(
        key: ValueKey('squad-${member.userId}'),
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: borderSide,
        ),
        elevation: 4,
        margin: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: isDark
                          ? Colors.white12
                          : Colors.grey.shade200,
                      backgroundImage: hasPhoto
                          ? NetworkImage(profileUrl)
                          : null,
                      child: !hasPhoto
                          ? Icon(
                              Icons.person,
                              size: 30,
                              color: isDark ? Colors.white54 : Colors.grey,
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        member.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isInjured
                              ? (isDark ? Colors.white24 : Colors.black38)
                              : textColor,
                          fontFamily: 'SFPro',
                        ),
                      ),
                    ),
                    if (posLabel != null)
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          posLabel,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey,
                            fontFamily: 'SFPro',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (jerseyLabel != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          jerseyLabel,
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── injured badge ──
            if (isInjured)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

            // ── selected indicator ──
            if (isSelected && !isInjured)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isStarter ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ATTENDANCE TITLE ROW (title + edit/discard aligned)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _attendanceTitleRow(
    Color textColor, {
    required bool canEdit,
    required List<AttendanceDto> attendees,
  }) {
    return Row(
      children: [
        Text(
          'ATTENDANCE',
          style: TextStyle(
            fontFamily: 'Facon',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: textColor,
          ),
        ),
        const Spacer(),
        if (canEdit) ...[
          if (_isAttendanceEditing)
            _styledIconButton(
              icon: Icons.close_rounded,
              color: Colors.red,
              bgColor: Colors.red.withValues(alpha: 0.12),
              tooltip: 'Discard',
              onTap: _discardAttendance,
            )
          else
            _styledIconButton(
              icon: Icons.edit_rounded,
              color: textColor.withValues(alpha: 0.6),
              bgColor: textColor.withValues(alpha: 0.06),
              tooltip: 'Edit attendance',
              onTap: () => _enterAttendanceEditMode(attendees),
            ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ATTENDANCE SECTION
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAttendanceSection(
    BuildContext context,
    List<Member> allMembers,
    String? clubId,
    String teamId,
    bool isDark,
    Color cardBg,
    Color textColor,
  ) {
    if ((clubId ?? '').isEmpty || teamId.isEmpty || event.eventId.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _attendanceTitleRow(textColor, canEdit: false, attendees: const []),
          const SizedBox(height: 12),
          _buildEmptyBox(
            isDark,
            cardBg,
            'Attendance is available after this event is saved.',
            Icons.event_busy_outlined,
          ),
        ],
      );
    }

    final canEdit = _canEditAttendance();
    final players = allMembers.where((m) => m.role == 'Player').toList();

    return BlocProvider(
      create: (_) => AttendanceBloc()
        ..add(
          LoadAttendance(
            clubId: clubId!,
            teamId: teamId,
            eventId: event.eventId,
          ),
        ),
      child: BlocConsumer<AttendanceBloc, AttendanceState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, attState) {
          if (attState.isLoading && attState.attendees.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _attendanceTitleRow(
                  textColor,
                  canEdit: false,
                  attendees: const [],
                ),
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (players.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _attendanceTitleRow(
                  textColor,
                  canEdit: false,
                  attendees: const [],
                ),
                const SizedBox(height: 12),
                Text(
                  'No players available.',
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with edit/discard inline
              _attendanceTitleRow(
                textColor,
                canEdit: canEdit,
                attendees: attState.attendees,
              ),
              const SizedBox(height: 12),

              ...players.map((member) {
                final existing = attState.attendees
                    .where((a) => a.playerUserId == member.userId)
                    .toList();
                final serverStatus = existing.isEmpty
                    ? 'Present'
                    : existing.first.status;
                final status = _isAttendanceEditing
                    ? (_localAttendance[member.userId] ?? serverStatus)
                    : serverStatus;
                final profileUrl = ApiClient.resolveUrl(member.profileImageUrl);
                final hasPhoto = profileUrl != null && profileUrl.isNotEmpty;

                final statusColor = _attendanceColor(status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.15 : 0.06,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    // IntrinsicHeight gives the Row a bounded height so the
                    // stretch alignment (used to make the accent strip fill the
                    // card height) works inside the scrolling column. Without it
                    // the Row is given unbounded height and stretch throws
                    // "BoxConstraints forces an infinite height".
                    child: IntrinsicHeight(
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // status accent strip
                        Container(width: 4, color: statusColor),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.7),
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                              backgroundImage: hasPhoto
                                  ? NetworkImage(profileUrl)
                                  : null,
                              child: !hasPhoto
                                  ? Icon(
                                      Icons.person,
                                      size: 22,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name,
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  member.role,
                                  style: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontSize: 12,
                                    color: textColor.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isAttendanceEditing)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _attendanceColor(
                                  status,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: _attendanceColor(status),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_isAttendanceEditing) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: ['Present', 'Absent', 'Late', 'Excused']
                              .map((val) {
                                final isChipSelected = status == val;
                                return ChoiceChip(
                                  label: Text(val),
                                  selected: isChipSelected,
                                  selectedColor: _attendanceColor(val),
                                  backgroundColor: cardBg,
                                  side: BorderSide(
                                    color: isChipSelected
                                        ? _attendanceColor(val)
                                        : (isDark
                                              ? Colors.white12
                                              : Colors.black12),
                                  ),
                                  labelStyle: TextStyle(
                                    fontFamily: 'SFPro',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: isChipSelected
                                        ? Colors.white
                                        : textColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  onSelected: (_) {
                                    setState(() {
                                      _localAttendance[member.userId] = val;
                                    });
                                  },
                                );
                              })
                              .toList(),
                        ),
                      ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),
                  ),
                );
              }),

              // Save button (edit mode only)
              if (_isAttendanceEditing) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AnimatedButton.primary(
                    child: ElevatedButton(
                      onPressed: _attendanceSaving
                          ? null
                          : () => _saveAttendance(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _attendanceSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Save Attendance',
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ANALYST STATS SECTION
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPlansSection(
    bool isDark,
    Color cardBg,
    Color textColor,
    bool isCoach,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PLANS',
          style: TextStyle(
            fontFamily: 'Facon',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        if (_plansLoading || _planSaving)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (_eventPlans.isNotEmpty)
            ..._eventPlans.map(
              (plan) => _buildPlanTile(plan, isDark, cardBg, textColor),
            ),
          if (isCoach)
            GestureDetector(
              onTap: _planSaving ? null : _openAddPlanFlow,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_add,
                      size: 36,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add a plan',
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 14,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!isCoach && _eventPlans.isEmpty)
            _buildEmptyBox(
              isDark,
              cardBg,
              'No plan added for this match yet.',
              Icons.assignment_outlined,
            )
        ],
      ],
    );
  }

  Widget _buildPlanTile(
    PlanDto plan,
    bool isDark,
    Color cardBg,
    Color textColor,
  ) {
    final category = plan.category;
    final color = category == 'Defensive' ? Colors.blue : Colors.green;
    return AnimatedPressable(
      onTap: () => Navigator.push(
        context,
        AppPageRoute(child: PlanDetailView(plan: plan)),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                category == 'Defensive'
                    ? Icons.shield
                    : Icons.sports_basketball,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.description?.isNotEmpty == true
                        ? plan.description!
                        : '$category plan',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 12,
                      height: 1.25,
                      color: textColor.withValues(alpha: 0.58),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By ${plan.creatorName}',
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 11,
                      color: textColor.withValues(alpha: 0.42),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: textColor.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadStats(String? clubId, String teamId) async {
    print('DEBUG: _pickAndUploadStats started! clubId=$clubId, teamId=$teamId, eventId=${event.eventId}');
    if (clubId == null || teamId.isEmpty || event.eventId.isEmpty) {
      print('DEBUG: Returning early due to null/empty IDs!');
      return;
    }

    print('DEBUG: Opening FilePicker...');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    
    print('DEBUG: FilePicker result: ${result?.files.length} files');
    if (result == null || result.files.isEmpty) return;
    
    final file = result.files.first;
    final String? path = kIsWeb ? null : file.path;
    print('DEBUG: Picked file: ${file.name}, has bytes: ${file.bytes != null}');
    if (path == null && file.bytes == null) {
      print('DEBUG: File has no path and no bytes, returning early!');
      return;
    }

    setState(() {
      _statsUploading = true;
      _statsError = null;
      _extractedRows = null;
      _pendingPdfPath = path;
      _pendingPdfBytes = file.bytes;
      _pendingPdfName = file.name;
    });

    try {
      final response = await _statsService.extractBasketballPdf(
        clubId,
        teamId,
        path,
        file.bytes,
        file.name,
      );
      final rows =
          (response['rows'] as List?)
              ?.map((r) => Map<String, dynamic>.from(r as Map))
              .toList() ??
          [];
      if (mounted) {
        setState(() {
          _extractedRows = rows;
          _extractedPlayerCount =
              (response['playerCount'] as int?) ?? _countPlayerRows(rows);
          _extractedTeamTotalCount =
              (response['teamTotalCount'] as int?) ?? _countTeamRows(rows);
          _statsUploading = false;
        });
        await _showExtractedStatsDialog(clubId, teamId);
      }
    } catch (e) {
      print('UPLOAD ERROR: $e');
      if (mounted) {
        setState(() {
          _statsUploading = false;
          _statsError = e.toString();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).statsUploadFailed(e.toString()))));
      }
    }
  }

  Future<void> _confirmExtractedStats(String? clubId, String teamId) async {
    if (clubId == null ||
        teamId.isEmpty ||
        event.eventId.isEmpty ||
        _extractedRows == null) {
      return;
    }

    final rows = _extractedRows!;
    setState(() => _statsConfirming = true);
    try {
      await _statsService.confirmBasketballUpload(clubId, teamId, {
        'eventId': event.eventId,
        'category': 'game',
        'rows': rows,
      });

      // Best-effort: attach the original PDF so it can be re-opened later.
      // A failure here must not block the (already-saved) stats flow.
      var rawPdfSaved = false;
      if (_pendingPdfPath != null || _pendingPdfBytes != null) {
        try {
          await _statsService.uploadRawStatsPdf(
            clubId,
            teamId,
            event.eventId,
            _pendingPdfPath,
            _pendingPdfBytes,
            _pendingPdfName ?? 'match-stats.pdf',
          );
          rawPdfSaved = true;
        } catch (_) {
          rawPdfSaved = false;
        }
      }

      if (mounted) {
        setState(() {
          _savedExtractedRowCount = rows.length;
          _statsConfirming = false;
          _statsSaved = true;
          if (rawPdfSaved) {
            _hasRawPdf = true;
            _rawPdfFileName = _pendingPdfName;
          }
          _pendingPdfPath = null;
          _pendingPdfBytes = null;
          _pendingPdfName = null;
          _extractedRows = null;
          _extractedPlayerCount = 0;
          _extractedTeamTotalCount = 0;
          _statsError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).statsSavedForMatch)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statsConfirming = false;
          _statsError = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveStatsError(e.toString()))),
        );
      }
    }
  }

  Future<void> _showExtractedStatsDialog(String? clubId, String teamId) async {
    if (_extractedRows == null || !mounted) return;
    final ourTeamName = context.read<TeamBloc>().state.selectedTeamName;
    final edited = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (ctx) => _ExtractedStatsDialog(
        rows: _extractedRows!,
        playerCount: _extractedPlayerCount,
        teamTotalCount: _extractedTeamTotalCount,
        ourTeamName: ourTeamName,
      ),
    );

    if (!mounted) return;
    if (edited == null) {
      // Discarded
      setState(() {
        _extractedRows = null;
        _extractedPlayerCount = 0;
        _extractedTeamTotalCount = 0;
        _statsError = null;
      });
      return;
    }
    // Saved (possibly with inline edits)
    setState(() => _extractedRows = edited);
    await _confirmExtractedStats(clubId, teamId);
  }

  Future<void> _deleteSavedStats(String? clubId, String teamId) async {
    if (clubId == null || teamId.isEmpty || event.eventId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(AppLocalizations.of(context).deleteMatchStatsTitle),
        content: const Text(
          'This permanently removes the saved stats for this match. '
          'Use this if the wrong file was uploaded.',
          style: TextStyle(fontFamily: 'SFPro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _statsDeleting = true);
    try {
      await _statsService.deleteMatchStats(clubId, teamId, event.eventId);
      if (mounted) {
        setState(() {
          _statsDeleting = false;
          _statsSaved = false;
          _savedExtractedRowCount = 0;
          _hasRawPdf = false;
          _rawPdfFileName = null;
          _statsError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).matchStatsDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statsDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).deleteStatsError(e.toString()))),
        );
      }
    }
  }

  int _countPlayerRows(List<Map<String, dynamic>> rows) {
    return rows
        .where((r) => r['rowType'] == 'player' || r['row_type'] == 'player')
        .length;
  }

  int _countTeamRows(List<Map<String, dynamic>> rows) {
    return rows
        .where(
          (r) => r['rowType'] == 'team_total' || r['row_type'] == 'team_total',
        )
        .length;
  }

  Widget _buildAnalystStatsSection(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color textColor,
    String? clubId,
    String teamId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MATCH STATS',
          style: TextStyle(
            fontFamily: 'Facon',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),

        // ── Tappable upload box (no separate button) ──
        AnimatedPressable(
          onTap: _statsUploading ? null : () => _pickAndUploadStats(clubId, teamId),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                _statsUploading
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 36,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                const SizedBox(height: 8),
                Text(
                  _statsUploading
                      ? 'Extracting...'
                      : 'Tap to upload FIBA Box Score PDF',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                if (!_statsUploading) ...[
                  const SizedBox(height: 4),
                  Text(
                    _statsSaved
                        ? 'Stats saved. Tap to replace with a new file.'
                        : 'Player stats are auto-extracted, then you confirm.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 12,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Error ──
        if (_statsError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _statsError!,
              style: const TextStyle(
                fontFamily: 'SFPro',
                fontSize: 13,
                color: Colors.red,
              ),
            ),
          ),

        // ── Saved state card (with 24h-gated delete) ──
        if (_statsSaved) _buildSavedStatsCard(isDark, cardBg, textColor, clubId, teamId),
      ],
    );
  }

  Future<void> _openRawStatsPdf(String? clubId, String teamId) async {
    if (clubId == null || teamId.isEmpty || event.eventId.isEmpty) return;
    if (_openingRawPdf) return;
    setState(() => _openingRawPdf = true);
    try {
      final file =
          await _statsService.downloadRawStatsPdf(clubId, teamId, event.eventId);
      if (!mounted) return;

      final tempDir = await getTemporaryDirectory();
      final rawName = _rawPdfFileName?.trim().isNotEmpty == true
          ? _rawPdfFileName!.trim()
          : file.fileName;
      final sanitizedName = rawName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final tempFile = File('${tempDir.path}/$sanitizedName');
      await tempFile.writeAsBytes(file.bytes);

      final result =
          await OpenFilex.open(tempFile.path, type: file.contentType);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).openFileError(result.message))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).openMatchStatsPdfError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _openingRawPdf = false);
    }
  }

  Widget _buildSavedStatsCard(
    bool isDark,
    Color cardBg,
    Color textColor,
    String? clubId,
    String teamId,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _savedExtractedRowCount > 0
                      ? 'Stats saved ($_savedExtractedRowCount rows).'
                      : 'Stats saved for this match.',
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          if (_hasRawPdf) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openingRawPdf
                    ? null
                    : () => _openRawStatsPdf(clubId, teamId),
                icon: _openingRawPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(
                  _openingRawPdf ? 'Opening...' : 'Open original PDF',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (_canDeleteStats)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _statsDeleting
                    ? null
                    : () => _deleteSavedStats(clubId, teamId),
                icon: _statsDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(_statsDeleting ? 'Deleting...' : 'Delete stats'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            Text(
              'The delete window (24h after the match) has closed.',
              style: TextStyle(
                fontFamily: 'SFPro',
                fontSize: 12,
                color: textColor.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  DOCUMENT SECTION
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildDocumentSection(
    bool isDark,
    Color cardBg,
    Color textColor,
    bool isStaff,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DOCUMENTS',
          style: TextStyle(
            fontFamily: 'Facon',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),

        // ── Upload container (staff only) ──
        if (isStaff)
          GestureDetector(
            onTap: _uploading ? null : _pickAndUploadDocument,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  _uploading
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Icon(
                          Icons.cloud_upload_outlined,
                          size: 36,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                  const SizedBox(height: 8),
                  Text(
                    _uploading ? 'Uploading...' : 'Tap to upload a document',
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Document list ──
        if (_docsLoading)
          const Center(child: CircularProgressIndicator())
        else if (_documents.isEmpty && !isStaff)
          _buildEmptyBox(
            isDark,
            cardBg,
            'No documents uploaded yet.',
            Icons.folder_open_outlined,
          )
        else if (_documents.isNotEmpty)
          ..._documents.map(
            (doc) =>
                _buildDocumentTile(doc, isDark, cardBg, textColor, isStaff),
          ),
      ],
    );
  }

  Widget _buildDocumentTile(
    EventDocumentDto doc,
    bool isDark,
    Color cardBg,
    Color textColor,
    bool isStaff,
  ) {
    final icon = _docIcon(doc.contentType);
    final size = _formatFileSize(doc.fileSize);
    final uploadedOn =
        '${doc.createdAt.day}/${doc.createdAt.month}/${doc.createdAt.year}';
    final uploader = doc.uploadedBy?.isNotEmpty == true
        ? doc.uploadedBy!
        : 'Team staff';
    final role = doc.uploadedByRole?.isNotEmpty == true
        ? doc.uploadedByRole!
        : 'Staff';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openDocument(doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 70,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.originalFileName,
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$size - $uploadedOn',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.52),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$uploader - $role',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.52),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isStaff)
                  AnimatedButton.icon(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _deleteDocument(doc),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Colors.red.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (doc.description?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                doc.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'SFPro',
                  fontSize: 13,
                  height: 1.3,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildEmptyBox(
    bool isDark,
    Color cardBg,
    String label,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  static Color _attendanceColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green;
      case 'Absent':
        return Colors.red;
      case 'Late':
        return Colors.orange;
      case 'Excused':
        return Colors.blue;
      default:
        return Colors.grey;
    }
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

  static IconData _docIcon(String contentType) {
    if (contentType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (contentType.contains('image')) return Icons.image_outlined;
    if (contentType.contains('video')) return Icons.videocam_outlined;
    if (contentType.contains('word') || contentType.contains('document')) {
      return Icons.description_outlined;
    }
    if (contentType.contains('sheet') || contentType.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EXTRACTED STATS — decorative, editable confirmation dialog
// ═══════════════════════════════════════════════════════════════════════════

/// A readable column in the box-score view. [keys] lists the candidate
/// row keys (camelCase as returned by the API, plus snake_case fallbacks)
/// that hold this value.
class _StatCol {
  final String label; // short header, e.g. "REB"
  final String fullName; // tooltip, e.g. "Total Rebounds"
  final List<String> keys;
  final bool numeric;
  const _StatCol(this.label, this.fullName, this.keys, {this.numeric = true});
}

/// One team's rows, plus whether we decided it's "us".
class _TeamGroup {
  final String key; // stable grouping key (team code based)
  final String teamName;
  final bool isUs;
  final bool autoMatched;
  final int? teamScore;
  final List<int> rowIndices;
  const _TeamGroup({
    required this.key,
    required this.teamName,
    required this.isUs,
    required this.autoMatched,
    required this.teamScore,
    required this.rowIndices,
  });
}

class _ExtractedStatsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final int playerCount;
  final int teamTotalCount;

  /// The name of the team the analyst is working with (the selected team in
  /// the app). Used to decide which side of the PDF is "us" vs the opponent.
  final String ourTeamName;

  const _ExtractedStatsDialog({
    required this.rows,
    required this.playerCount,
    required this.teamTotalCount,
    required this.ourTeamName,
  });

  @override
  State<_ExtractedStatsDialog> createState() => _ExtractedStatsDialogState();
}

class _ExtractedStatsDialogState extends State<_ExtractedStatsDialog> {
  late List<Map<String, dynamic>> _rows;
  bool _editing = false;
  final Map<String, TextEditingController> _controllers = {};

  // Team grouping (built once in initState, order preserved as discovered).
  // Rows are grouped by a STABLE key derived from the FIBA team code so the
  // same team can't fragment into two groups when the extractor reports its
  // name slightly differently (e.g. "Egypt" vs "EGYPT (EGY) Head Coach …").
  final List<String> _teamOrder = [];
  final Map<String, List<int>> _teamRows = {};
  final Map<String, int?> _teamScores = {};
  final Map<String, String> _teamNames = {}; // key -> cleanest display name
  final Map<String, String> _teamCodes = {}; // key -> team code
  String? _ourKey; // which team is "us"
  bool _autoMatched = false; // whether _ourKey was matched by name/code

  // Readable box-score columns, in FIBA order. Each lists camelCase keys
  // first (as the API returns) with snake_case fallbacks.
  static const List<_StatCol> _statCols = [
    _StatCol('MIN', 'Minutes played', ['minutes', 'min'], numeric: false),
    _StatCol('PTS', 'Points', ['points', 'pts']),
    _StatCol('2PT', '2-point made / attempted', ['twoPtMA', '2p_ma'],
        numeric: false),
    _StatCol('3PT', '3-point made / attempted', ['threePtMA', '3p_ma'],
        numeric: false),
    _StatCol('FT', 'Free throws made / attempted', ['ftMA', 'ft_ma'],
        numeric: false),
    _StatCol('OR', 'Offensive rebounds',
        ['offensiveRebounds', 'teamOffReb', 'or']),
    _StatCol('DR', 'Defensive rebounds',
        ['defensiveRebounds', 'teamDefReb', 'dr']),
    _StatCol('REB', 'Total rebounds', ['totalRebounds', 'teamReb', 'reb']),
    _StatCol('AST', 'Assists', ['assists', 'ast']),
    _StatCol('TO', 'Turnovers', ['turnovers', 'to']),
    _StatCol('STL', 'Steals', ['steals', 'stl']),
    _StatCol('BLK', 'Blocks', ['blocks', 'blk']),
    _StatCol('PF', 'Personal fouls', ['personalFouls', 'teamPF', 'pf']),
    _StatCol('FD', 'Fouls drawn', ['foulsDrawn', 'teamFD', 'fd']),
    _StatCol('EFF', 'Efficiency', ['efficiency', 'eff']),
  ];

  @override
  void initState() {
    super.initState();
    _rows = widget.rows.map((r) => Map<String, dynamic>.from(r)).toList();
    _buildGroups();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Reads the first non-null value among [keys], trying exact then
  /// case-insensitive matches so the dialog works whatever casing the
  /// backend uses.
  dynamic _lookup(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      if (row.containsKey(k) && row[k] != null) return row[k];
    }
    for (final k in keys) {
      final lk = k.toLowerCase();
      for (final entry in row.entries) {
        if (entry.key.toLowerCase() == lk && entry.value != null) {
          return entry.value;
        }
      }
    }
    return null;
  }

  /// Returns the actual key present in [row] for one of [keys] (so edits are
  /// written back onto the real key), falling back to the first candidate.
  String _resolveKey(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      if (row.containsKey(k)) return k;
    }
    for (final k in keys) {
      final lk = k.toLowerCase();
      for (final rk in row.keys) {
        if (rk.toLowerCase() == lk) return rk;
      }
    }
    return keys.first;
  }

  bool _truthy(dynamic v) =>
      v == true || v == 1 || v == '1' || v?.toString().toLowerCase() == 'true';

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Higher score = stronger evidence this team is "us".
  int _matchScore(String ourNorm, String teamName, String teamCode) {
    if (ourNorm.isEmpty) return 0;
    final n = _normalize(teamName);
    if (n.isNotEmpty) {
      if (n == ourNorm) return 100;
      if (ourNorm.contains(n) || n.contains(ourNorm)) return 60;
    }
    final c = _normalize(teamCode);
    if (c.length >= 3 && ourNorm.contains(c)) return 40;
    return 0;
  }

  void _buildGroups() {
    _teamOrder.clear();
    _teamRows.clear();
    _teamScores.clear();
    _teamNames.clear();
    _teamCodes.clear();

    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final name = (_lookup(row, const ['teamName', 'team_name']) ?? '')
          .toString()
          .trim();
      final code = (_lookup(row, const ['teamCode', 'team_code']) ?? '')
          .toString()
          .trim();

      // Stable grouping key: prefer the FIBA team code (identical across the
      // team's rows), then a normalized name, then a catch-all bucket.
      final String key;
      if (code.isNotEmpty) {
        key = 'code:${code.toUpperCase()}';
      } else if (name.isNotEmpty) {
        key = 'name:${_normalize(name)}';
      } else {
        key = 'unknown';
      }

      if (!_teamRows.containsKey(key)) {
        _teamRows[key] = [];
        _teamOrder.add(key);
        _teamCodes[key] = code.toUpperCase();
        _teamNames[key] = name;
        _teamScores[key] = null;
      }
      _teamRows[key]!.add(i);

      // Keep the cleanest (shortest non-empty) name as the display label, so
      // "Egypt" wins over "EGYPT (EGY) Head Coach …".
      if (name.isNotEmpty) {
        final current = _teamNames[key] ?? '';
        if (current.isEmpty || name.length < current.length) {
          _teamNames[key] = name;
        }
      }
      if (_teamCodes[key]!.isEmpty && code.isNotEmpty) {
        _teamCodes[key] = code.toUpperCase();
      }
      if (_teamScores[key] == null) {
        final score = _lookup(row, const ['teamScore', 'team_score']);
        _teamScores[key] =
            score is int ? score : int.tryParse(score?.toString() ?? '');
      }
    }

    // Decide which team is "us" by matching the selected team name / code.
    final ourNorm = _normalize(widget.ourTeamName);
    String? best;
    var bestScore = 0;
    for (final key in _teamOrder) {
      if (key == 'unknown') continue;
      final score =
          _matchScore(ourNorm, _teamNames[key] ?? '', _teamCodes[key] ?? '');
      if (score > bestScore) {
        bestScore = score;
        best = key;
      }
    }
    _autoMatched = bestScore > 0;
    // Fall back to the first table if we couldn't match by name.
    _ourKey = best ?? (_teamOrder.isNotEmpty ? _teamOrder.first : null);
  }

  List<_TeamGroup> get _groups {
    final groups = _teamOrder.map((key) {
      final name = _teamNames[key] ?? '';
      return _TeamGroup(
        key: key,
        teamName:
            name.isNotEmpty ? name : (key == 'unknown' ? 'Unknown team' : key),
        isUs: key == _ourKey,
        autoMatched: _autoMatched && key == _ourKey,
        teamScore: _teamScores[key],
        rowIndices: _teamRows[key]!,
      );
    }).toList();
    // Our team first.
    groups.sort((a, b) => (a.isUs == b.isUs) ? 0 : (a.isUs ? -1 : 1));
    return groups;
  }

  TextEditingController _controllerFor(int rowIndex, String key) {
    final id = '$rowIndex::$key';
    return _controllers.putIfAbsent(id, () {
      final v = _rows[rowIndex][key];
      return TextEditingController(text: v?.toString() ?? '');
    });
  }

  void _commitEdits() {
    for (final entry in _controllers.entries) {
      final sep = entry.key.indexOf('::');
      if (sep < 0) continue;
      final rowIndex = int.tryParse(entry.key.substring(0, sep));
      if (rowIndex == null || rowIndex >= _rows.length) continue;
      final key = entry.key.substring(sep + 2);
      final text = entry.value.text.trim();
      final original = _rows[rowIndex][key];
      if (original is int) {
        _rows[rowIndex][key] = int.tryParse(text) ?? original;
      } else if (original is double) {
        _rows[rowIndex][key] = double.tryParse(text) ?? original;
      } else if (original == null) {
        if (text.isEmpty) {
          _rows[rowIndex][key] = null;
        } else {
          final asInt = int.tryParse(text);
          _rows[rowIndex][key] = asInt ?? text;
        }
      } else {
        _rows[rowIndex][key] = text;
      }
    }
  }

  // ── Cell builders ────────────────────────────────────────────────────

  Widget _valueText(String text, Color textColor, {bool strong = false}) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'SFPro',
        fontSize: 12.5,
        fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
        color: textColor.withValues(alpha: strong ? 0.95 : 0.85),
      ),
    );
  }

  Widget _editField(int rowIndex, List<String> keys, double width,
      bool numeric, Color textColor) {
    final key = _resolveKey(_rows[rowIndex], keys);
    return SizedBox(
      width: width,
      child: TextField(
        controller: _controllerFor(rowIndex, key),
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: false)
            : TextInputType.text,
        style: TextStyle(
          fontFamily: 'SFPro',
          fontSize: 12.5,
          color: textColor,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  DataCell _numberCell(int rowIndex, bool isTeamTotal, Color textColor) {
    if (isTeamTotal) return const DataCell(Text(''));
    if (_editing) {
      return DataCell(_editField(
          rowIndex, const ['playerNo', 'player_no'], 46, true, textColor));
    }
    final no = _lookup(_rows[rowIndex], const ['playerNo', 'player_no']);
    return DataCell(_valueText(no == null ? '—' : no.toString(), textColor,
        strong: true));
  }

  DataCell _nameCell(int rowIndex, bool isTeamTotal, Color textColor) {
    if (isTeamTotal) {
      return DataCell(Text(
        'Team totals',
        style: TextStyle(
          fontFamily: 'SFPro',
          fontSize: 12.5,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w700,
          color: textColor.withValues(alpha: 0.85),
        ),
      ));
    }
    if (_editing) {
      return DataCell(_editField(rowIndex,
          const ['playerName', 'player_name'], 150, false, textColor));
    }
    final row = _rows[rowIndex];
    final name =
        (_lookup(row, const ['playerName', 'player_name']) ?? '—').toString();
    final isCaptain = _truthy(_lookup(row, const ['isCaptain', 'is_captain']));
    final isStarter = _truthy(_lookup(row, const ['isStarter', 'is_starter']));
    final dnp = (_lookup(row, const ['status']) ?? '')
        .toString()
        .toUpperCase()
        .contains('DNP');
    return DataCell(
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStarter)
              Tooltip(
                message: 'Starter',
                child: Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'SFPro',
                  fontSize: 12.5,
                  color: textColor.withValues(alpha: dnp ? 0.45 : 0.9),
                ),
              ),
            ),
            if (isCaptain)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '(C)',
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  DataCell _statCell(int rowIndex, _StatCol col, Color textColor) {
    if (_editing) {
      return DataCell(
          _editField(rowIndex, col.keys, 64, col.numeric, textColor));
    }
    final v = _lookup(_rows[rowIndex], col.keys);
    final text = (v == null || v.toString().isEmpty) ? '—' : v.toString();
    return DataCell(_valueText(text, textColor));
  }

  Widget _teamSection(_TeamGroup g, Color textColor, bool isDark) {
    final accent = g.isUs ? AppColors.brand : Colors.blueGrey;
    final chipBg =
        (g.isUs ? AppColors.brand : Colors.blueGrey).withValues(alpha: 0.14);

    final columns = <DataColumn>[
      const DataColumn(label: Text('#')),
      DataColumn(label: Text(AppLocalizations.of(context).player)),
      ..._statCols.map(
        (c) => DataColumn(
          label: Tooltip(message: c.fullName, child: Text(c.label)),
        ),
      ),
    ];

    // Show players who played first, then DNPs, then the team totals row —
    // preserving the original order within each bucket.
    final played = <int>[];
    final dnp = <int>[];
    final totals = <int>[];
    for (final idx in g.rowIndices) {
      final r = _rows[idx];
      final isTotal =
          (_lookup(r, const ['rowType', 'row_type']) ?? '').toString() ==
              'team_total';
      if (isTotal) {
        totals.add(idx);
        continue;
      }
      final status =
          (_lookup(r, const ['status']) ?? '').toString().toUpperCase();
      (status.contains('DNP') ? dnp : played).add(idx);
    }
    final ordered = [...played, ...dnp, ...totals];

    final dataRows = ordered.map((rowIndex) {
      final row = _rows[rowIndex];
      final isTeamTotal =
          (_lookup(row, const ['rowType', 'row_type']) ?? '').toString() ==
              'team_total';
      return DataRow(
        color: isTeamTotal
            ? WidgetStatePropertyAll(accent.withValues(alpha: 0.10))
            : null,
        cells: [
          _numberCell(rowIndex, isTeamTotal, textColor),
          _nameCell(rowIndex, isTeamTotal, textColor),
          ..._statCols.map((c) => _statCell(rowIndex, c, textColor)),
        ],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  g.isUs ? 'OUR TEAM' : 'OPPONENT',
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  g.teamName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Facon',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              if (g.teamScore != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${g.teamScore}',
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
              const Spacer(),
              if (!g.isUs)
                TextButton.icon(
                  onPressed: () => setState(() => _ourKey = g.key),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: Text(AppLocalizations.of(context).thisIsUs),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor:
                WidgetStatePropertyAll(accent.withValues(alpha: 0.08)),
            headingTextStyle: TextStyle(
              fontFamily: 'SFPro',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: textColor,
            ),
            dataTextStyle: TextStyle(
              fontFamily: 'SFPro',
              fontSize: 12.5,
              color: textColor.withValues(alpha: 0.85),
            ),
            columnSpacing: 16,
            horizontalMargin: 12,
            headingRowHeight: 36,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 48,
            columns: columns,
            rows: dataRows,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;

    final groups = _groups;
    final matchup = (_rows.isEmpty
            ? ''
            : (_lookup(_rows.first, const ['matchup']) ?? '').toString())
        .trim();
    final summary = StringBuffer();
    if (matchup.isNotEmpty) summary.write(matchup);
    if (widget.playerCount > 0) {
      if (summary.isNotEmpty) summary.write(' · ');
      summary.write('${widget.playerCount} players');
    }
    if (summary.isEmpty) summary.write('${_rows.length} rows');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: cardBg,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 760,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review extracted stats',
                          style: TextStyle(
                            fontFamily: 'Facon',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary.toString(),
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_editing) _commitEdits();
                        _editing = !_editing;
                      });
                    },
                    icon: Icon(
                      _editing ? Icons.check_rounded : Icons.edit_rounded,
                      size: 18,
                    ),
                    label: Text(_editing ? 'Done' : 'Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),

            if (!_autoMatched)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.help_outline_rounded,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Couldn't match “${widget.ourTeamName}” to a team in "
                        "the PDF — showing the first table as your team. Use "
                        "“This is us” to switch if needed.",
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 11.5,
                          color: textColor.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_editing)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'Tap any value to fix what the extractor got wrong.',
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.55),
                  ),
                ),
              ),

            // ── Per-team box scores ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final g in groups) _teamSection(g, textColor, isDark),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),

            // ── Actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_editing) _commitEdits();
                        Navigator.pop(context, _rows);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save stats',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentDescriptionBottomSheet extends StatefulWidget {
  final String fileName;

  const _DocumentDescriptionBottomSheet({required this.fileName});

  @override
  State<_DocumentDescriptionBottomSheet> createState() =>
      _DocumentDescriptionBottomSheetState();
}

class _DocumentDescriptionBottomSheetState
    extends State<_DocumentDescriptionBottomSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    // Using viewInsets to handle keyboard in bottom sheet
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.sm),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.all(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle for bottom sheet
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Document',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Caption (Optional)',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 3,
              style: TextStyle(color: textColor, fontSize: 14),
              cursorColor: AppColors.brand,
              decoration: InputDecoration(
                hintText: 'Add context for the team...',
                hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.brand,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, _controller.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Upload File',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

