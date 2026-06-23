import 'package:flutter/foundation.dart';
import '../core/cached_image_widget.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../addevent/AddEventView.dart';
import '../addclub/AddClubView.dart';
import '../addteam/AddTeamView.dart';
import '../addteam/AddTeamModel.dart';
import '../announcement/AddAnnouncementView.dart';
import '../announcement/AnnouncementModel.dart';
import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/animated_button.dart';
import '../core/app_transitions.dart';
import '../core/design_tokens.dart';
import '../core/target_navigator.dart';
import '../event/EventModel.dart';
import '../event/event_bloc.dart';
import '../services/api_client.dart';
import '../session/session_bloc.dart';
import '../team/team_bloc.dart';
import 'DayEventsDetailView.dart';
import 'home_bloc.dart';
import '../core/app_localizations.dart';

/// Per-announcement render keys, used to scroll a specific card into view when
/// the user opens it from Search or a Notification.
final Map<String, GlobalKey> homeAnnouncementKeys = {};

/// Invisible helper that listens to [HomeFocus.announcementId] and scrolls the
/// matching announcement card into view (then clears the highlight after a beat).
class _AnnouncementFocusListener extends StatefulWidget {
  const _AnnouncementFocusListener();

  @override
  State<_AnnouncementFocusListener> createState() =>
      _AnnouncementFocusListenerState();
}

class _AnnouncementFocusListenerState
    extends State<_AnnouncementFocusListener> {
  @override
  void initState() {
    super.initState();
    HomeFocus.announcementId.addListener(_onFocus);
    // Handle a value that was set before this listener mounted.
    if (HomeFocus.announcementId.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onFocus());
    }
  }

  @override
  void dispose() {
    HomeFocus.announcementId.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    final id = HomeFocus.announcementId.value;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = homeAnnouncementKeys[id];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
      // Clear highlight after a short moment.
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (HomeFocus.announcementId.value == id) {
          HomeFocus.announcementId.value = null;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  // ───── event type → single colour (matches calendar) ─────
  static Color eventTypeColor(String type) {
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

  static IconData eventTypeIcon(String type) {
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white54 : Colors.grey;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: t.home, showBackButton: false, showTeamSwitcher: true),
      body: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          final List<Team?> teams = state.teams;
          final List<Announcement> announcements = state.announcements;

          return AppBackground(
              child: SafeArea(
                child: RefreshIndicator(
                  onRefresh: () async {
                    final team = context.read<TeamBloc>().state;
                    final selectedTeams = team.availableTeams
                        .where((t) => t.id == team.selectedTeamId)
                        .toList();
                    context.read<HomeBloc>().add(
                      LoadHomeData(
                        clubId: selectedTeams.isEmpty
                            ? null
                            : selectedTeams.first.clubId,
                        teamId: team.selectedTeamId,
                      ),
                    );
                  },
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        if (state.isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (teams.isEmpty)
                          _buildEmptyHome(context, textColor, subtitleColor)
                        else ...[
                          // ─── EVENTS SECTION (horizontal swipe) ───
                          BlocBuilder<EventBloc, EventState>(
                            builder: (context, eventState) {
                              // Only show events occurring within the next 7
                              // days, sorted chronologically by date and time.
                              final now = DateTime.now();
                              final todayStart =
                                  DateTime(now.year, now.month, now.day);
                              final cutoff =
                                  todayStart.add(const Duration(days: 7));
                              final List<Event> upcoming =
                                  eventState.upcomingEvents.where((e) {
                                    final day = DateTime(
                                        e.date.year, e.date.month, e.date.day);
                                    return !day.isBefore(todayStart) &&
                                        !day.isAfter(cutoff);
                                  }).toList()
                                    ..sort((a, b) {
                                      final aDt = DateTime(
                                          a.date.year,
                                          a.date.month,
                                          a.date.day,
                                          a.time.hour,
                                          a.time.minute);
                                      final bDt = DateTime(
                                          b.date.year,
                                          b.date.month,
                                          b.date.day,
                                          b.time.hour,
                                          b.time.minute);
                                      return aDt.compareTo(bDt);
                                    });
                              if (upcoming.isEmpty) {
                                return _buildEmptyEventsPlaceholder(
                                  context,
                                  isDark,
                                );
                              }
                              return _EventCarousel(events: upcoming);
                            },
                          ),

                          // ─── ANNOUNCEMENTS SECTION (vertical scroll) ───
                          const SizedBox(height: 28),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Text(
                              t.homeAnnouncements,
                              style: TextStyle(
                                fontFamily: 'Facon',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (announcements.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: Column(
                                children: [
                                  const _AnnouncementFocusListener(),
                                  ...announcements.map(
                                    (a) => _focusableAnnouncement(
                                      context,
                                      a,
                                      isDark,
                                      textColor,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            _buildEmptyAnnouncementsPlaceholder(
                              context,
                              isDark,
                              textColor,
                            ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          );
        },
      ),
    );
  }

  // ─── empty state (unchanged logic) ───────────────────────────────────
  Widget _buildEmptyHome(
    BuildContext context,
    Color textColor,
    Color subtitleColor,
  ) {
    final t = AppLocalizations.of(context);
    final session = context.watch<SessionBloc>().state;
    final hasClubs = session.clubs.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              hasClubs ? Icons.groups_outlined : Icons.apartment_outlined,
              size: 64,
              color: subtitleColor,
            ),
            const SizedBox(height: 16),
            Text(
              t.homeWelcome,
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'SFPro',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasClubs
                  ? t.homeClubSetup
                  : t.homeStartClub,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtitleColor,
                fontFamily: 'SFPro',
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            AnimatedButton.primary(child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  AppPageRoute(
                    child: hasClubs ? const AddTeamView() : const AddClubView(),
                  ),
                );
                if (result == null || !context.mounted) return;
                context.read<SessionBloc>().add(SessionRefreshContext());
                context.read<HomeBloc>().add(LoadHomeData());
              },
              icon: Icon(hasClubs ? Icons.group_add : Icons.apartment),
              label: Text(
                hasClubs ? t.homeCreateFirstTeam : t.homeCreateFirstClub,
                style: const TextStyle(fontFamily: 'SFPro', fontSize: 16),
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ─── helper: is the user a manager? ──────────────────────────────────
  static bool _isPlayer(BuildContext context) {
    final role = context.read<TeamBloc>().state.userRoleInSelectedTeam.trim();
    return role == 'Player';
  }

  static bool _isManager(BuildContext context) {
    final role = context.read<TeamBloc>().state.userRoleInSelectedTeam.trim();
    return role == 'ClubManager' || role == 'TeamManager';
  }

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  Future<void> _openAddEvent(BuildContext context) async {
    final result = await Navigator.push(
      context,
      AppPageRoute(child: const AddEventView()),
    );
    if (!context.mounted) return;
    if (result is! Event) return;

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

  Future<void> _openAddAnnouncement(BuildContext context) async {
    final sessionState = context.read<SessionBloc>().state;
    final teamRole = context.read<TeamBloc>().state.userRoleInSelectedTeam;
    final activeRole = _firstNonEmpty([
      teamRole,
      sessionState.currentRole ?? '',
      'Member',
    ]);
    final currentUser = sessionState.user;
    final authorName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : currentUser?.email ?? 'Me';

    final result = await Navigator.push(
      context,
      AppPageRoute(
        child: AddAnnouncementView(
          authorName: authorName,
          authorRole: activeRole,
          authorImage: currentUser?.profileImageUrl ?? '',
        ),
      ),
    );
    if (!context.mounted) return;
    if (result is! Announcement) return;

    final teamState = context.read<TeamBloc>().state;
    final selectedTeams = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();
    context.read<HomeBloc>().add(
      AddAnnouncementEvent(
        result,
        clubId: selectedTeams.isEmpty ? null : selectedTeams.first.clubId,
        teamId: teamState.selectedTeamId,
      ),
    );
  }

  // ─── empty events placeholder (styled like an event card) ───────────
  Widget _buildEmptyEventsPlaceholder(BuildContext context, bool isDark) {
    final t = AppLocalizations.of(context);
    final isManager = _isManager(context);
    final title = isManager
        ? t.homeAddFirstEvent
        : t.homeNoEvents;
    final subtitle = isManager
        ? t.homeTapToSchedule
        : t.homeEventsAppearHere;
    final icon = isManager ? Icons.add_circle_outline : Icons.event_busy;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B5E20).withValues(alpha: 0.85),
            const Color(0xFF388E3C).withValues(alpha: 0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Facon',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: isManager
          ? AnimatedPressable(onTap: () => _openAddEvent(context), child: card)
          : card,
    );
  }

  // ─── empty announcements placeholder ────────────────────────────────
  Widget _buildEmptyAnnouncementsPlaceholder(
    BuildContext context,
    bool isDark,
    Color textColor,
  ) {
    final t = AppLocalizations.of(context);
    final isPlayer = _isPlayer(context);
    final title = isPlayer
        ? t.homeNoAnnouncements
        : t.homeAddFirstAnnouncement;
    final subtitle = isPlayer
        ? t.homeAnnouncementsAppearHere
        : t.homeKeepTeamInLoop;
    final icon = isPlayer ? Icons.campaign_outlined : Icons.post_add_rounded;

    if (!isPlayer) {
      final meetingColor = Colors.green.shade400;
      final card = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              meetingColor.withValues(alpha: 0.85),
              meetingColor.withValues(alpha: 0.65),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Facon',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SFPro',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      );

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: AnimatedPressable(
          onTap: () => _openAddAnnouncement(context),
          child: card,
        ),
      );
    }

    final bg = isDark ? const Color(0xFF1B3A2D) : Colors.white;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: card,
    );
  }

  // ─── focusable wrapper (scroll-to + highlight from search/notifications) ──
  Widget _focusableAnnouncement(
    BuildContext context,
    Announcement a,
    bool isDark,
    Color textColor,
  ) {
    final key = homeAnnouncementKeys.putIfAbsent(a.id, () => GlobalKey());
    return KeyedSubtree(
      key: key,
      child: ValueListenableBuilder<String?>(
        valueListenable: HomeFocus.announcementId,
        builder: (context, focusedId, child) {
          final highlighted = focusedId == a.id;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: highlighted
                    ? AppColors.primary
                    : Colors.transparent,
                width: 2,
              ),
              boxShadow: highlighted
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
        child: _buildAnnouncementCard(context, a, isDark, textColor),
      ),
    );
  }

  // ─── announcement card ───────────────────────────────────────────────
  Widget _buildAnnouncementCard(
    BuildContext context,
    Announcement a,
    bool isDark,
    Color textColor,
  ) {
    final isUrgent = a.isUrgent;
    final isImportant = a.isImportant;
    final accent = isUrgent
        ? Colors.red
        : isImportant
        ? Colors.blue
        : AppColors.primary;
    final bodyText = isDark ? Colors.white : const Color(0xFF001F14);
    final mutedText = isDark ? Colors.white70 : const Color(0xFF4D5B53);
    final resolvedImageUrl = ApiClient.resolveUrl(a.imageUrl);
    final hasLocalImage = a.image != null;
    final hasRemoteImage =
        resolvedImageUrl != null && resolvedImageUrl.isNotEmpty;
    final hasAnnouncementImage = hasLocalImage || hasRemoteImage;

    final teamState = context.read<TeamBloc>().state;
    final currentUserId = context.read<SessionBloc>().state.user?.userId;
    final selectedTeams = teamState.availableTeams
        .where((team) => team.id == teamState.selectedTeamId)
        .toList();
    final canManage =
        a.id.isNotEmpty &&
        selectedTeams.isNotEmpty &&
        currentUserId != null &&
        a.authorUserId == currentUserId;

    return _EditableAnnouncementCard(
      announcement: a,
      accent: accent,
      bodyText: bodyText,
      mutedText: mutedText,
      isDark: isDark,
      hasAnnouncementImage: hasAnnouncementImage,
      resolvedImageUrl: resolvedImageUrl,
      isPrioritized: isImportant || isUrgent,
      canManage: canManage,
      onSave: (updated) => context.read<HomeBloc>().add(
        UpdateAnnouncementEvent(
          announcement: updated,
          clubId: selectedTeams.first.clubId!,
          teamId: teamState.selectedTeamId,
        ),
      ),
      onDelete: () => context.read<HomeBloc>().add(
        DeleteAnnouncementEvent(
          announcementId: a.id,
          clubId: selectedTeams.first.clubId!,
          teamId: teamState.selectedTeamId,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  EVENT CAROUSEL  –  horizontal PageView with dot indicators
//  Card colour is derived from the event type (same as the calendar).
//  Tapping a card opens DayEventsDetailView.
// ═══════════════════════════════════════════════════════════════════════
class _EditableAnnouncementCard extends StatefulWidget {
  final Announcement announcement;
  final Color accent;
  final Color bodyText;
  final Color mutedText;
  final bool isDark;
  final bool hasAnnouncementImage;
  final String? resolvedImageUrl;
  final bool isPrioritized;
  final bool canManage;
  final ValueChanged<Announcement> onSave;
  final VoidCallback onDelete;

  const _EditableAnnouncementCard({
    required this.announcement,
    required this.accent,
    required this.bodyText,
    required this.mutedText,
    required this.isDark,
    required this.hasAnnouncementImage,
    required this.resolvedImageUrl,
    required this.isPrioritized,
    required this.canManage,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditableAnnouncementCard> createState() =>
      _EditableAnnouncementCardState();
}

class _EditableAnnouncementCardState extends State<_EditableAnnouncementCard>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _captionController;
  late String _priority;
  PlatformFile? _pickedImageFile;
    bool _isEditing = false;

  AnimationController? _editCtrl;
  Animation<double>? _editFade;
  Animation<double>? _editSize;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(
      text: widget.announcement.caption,
    );
    _priority = widget.announcement.priority;

    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _editCtrl = ctrl;
    _editFade = CurvedAnimation(parent: ctrl, curve: Curves.easeOut,
        reverseCurve: Curves.easeIn);
    _editSize = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
  }

  @override
  void didUpdateWidget(covariant _EditableAnnouncementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.announcement != widget.announcement) {
      _captionController.text = widget.announcement.caption;
      _priority = widget.announcement.priority;
      _pickedImageFile = null;
            _isEditing = false;
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _editCtrl?.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_rounded, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Delete announcement?',
                      style: TextStyle(
                        color: Color(0xFF001F14),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'SFPro',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'This announcement will be removed for the whole team.',
                style: TextStyle(
                  color: Color(0xFF4D5B53),
                  fontSize: 14,
                  height: 1.35,
                  fontFamily: 'SFPro',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF001F14),
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.12),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(AppLocalizations.of(context).cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(AppLocalizations.of(context).delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldDelete == true) widget.onDelete();
  }

  void _startEdit() {
    setState(() => _isEditing = true);
    _editCtrl?.forward();
  }

  void _cancelEdit() {
    final ctrl = _editCtrl;
    if (ctrl == null) {
      setState(() {
        _captionController.text = widget.announcement.caption;
        _priority = widget.announcement.priority;
        _pickedImageFile = null;
                _isEditing = false;
      });
      return;
    }
    ctrl.reverse().then((_) {
      if (mounted) {
        setState(() {
          _captionController.text = widget.announcement.caption;
          _priority = widget.announcement.priority;
          _pickedImageFile = null;
                    _isEditing = false;
        });
      }
    });
  }

  Future<void> _pickReplacementImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() {
      _pickedImageFile = file;
    });
  }

  void _saveEdit() {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) return;
    (_editCtrl?.reverse() ?? Future.value()).then((_) {
      if (mounted) setState(() => _isEditing = false);
    });
    widget.onSave(
      widget.announcement.copyWith(
        caption: caption,
        image: _pickedImageFile,
        
        priority: _priority,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _buildCard();
    if (!widget.canManage) return card;

    return _AnnouncementActionSlider(
      onEdit: _startEdit,
      onDelete: _confirmDelete,
      enabled: !_isEditing,
      child: card,
    );
  }

  Widget _buildCard() {
    final avatarImage = _announcementImageProvider(
      widget.announcement.authorImage,
    );
    final hasEditImage =
        _pickedImageFile != null ||
        widget.announcement.image != null ||
        (widget.resolvedImageUrl ?? '').isNotEmpty;
    final priorityAccent = _priority.toLowerCase() == 'urgent'
        ? Colors.red
        : _priority.toLowerCase() == 'important'
        ? Colors.blue
        : AppColors.primary;
    final showPriority = _isEditing
        ? _priority.toLowerCase() != 'normal'
        : widget.isPrioritized;
    final cardColor = widget.isDark ? const Color(0xFF10251C) : Colors.white;
    final borderColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.07);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.24 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (showPriority)
              PositionedDirectional(
                start: 0,
                top: 18,
                child: Container(
                  width: 5,
                  height: 76,
                  decoration: BoxDecoration(
                    color: priorityAccent,
                    borderRadius: const BorderRadiusDirectional.horizontal(
                      end: Radius.circular(8),
                    ),
                  ),
                ),
              ),
            if (showPriority)
              PositionedDirectional(
                top: 14,
                end: 16,
                child: _priorityBadge(_priority, priorityAccent),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, showPriority ? 42 : 22, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: priorityAccent.withValues(alpha: 0.14),
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? Icon(
                                Icons.person,
                                color: priorityAccent,
                                size: 28,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.announcement.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                color: widget.bodyText,
                                fontFamily: 'SFPro',
                                height: 1.28,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              widget.announcement.authorRole,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: widget.mutedText,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'SFPro',
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // ── View content (fades out while editing) ────────────────
                  if (_editCtrl != null)
                    FadeTransition(
                      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                        CurvedAnimation(
                          parent: _editCtrl!,
                          curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
                        ),
                      ),
                      child: SizeTransition(
                        sizeFactor: Tween<double>(begin: 1.0, end: 0.0).animate(
                          CurvedAnimation(
                            parent: _editCtrl!,
                            curve: const Interval(0.0, 0.5, curve: Curves.easeInCubic),
                          ),
                        ),
                        child: _buildViewContent(priorityAccent),
                      ),
                    )
                  else
                    _buildViewContent(priorityAccent),
                  // ── Edit fields (expands in while editing) ────────────────
                  if (_editSize != null && _editFade != null)
                    SizeTransition(
                      sizeFactor: _editSize!,
                      axisAlignment: -1.0,
                      child: FadeTransition(
                        opacity: _editFade!,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _editField(
                            controller: _captionController,
                            label: AppLocalizations.of(context).homeCaption,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 12),
                          _imagePickerButton(priorityAccent, context),
                          const SizedBox(height: 12),
                          _priorityPicker(context),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _cancelEdit,
                                child: Text(AppLocalizations.of(context).cancel),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _saveEdit,
                                child: Text(AppLocalizations.of(context).save),
                              ),
                            ],
                          ),
                          if (hasEditImage) ...[
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AspectRatio(
                                aspectRatio: 16 / 8,
                                child: _buildAnnouncementMedia(
                                  image: _pickedImageFile ?? widget.announcement.image,
                                  imageUrl: widget.resolvedImageUrl,
                                  accent: priorityAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildViewContent(Color priorityAccent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.hasAnnouncementImage) ...[
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 8,
              child: _buildAnnouncementMedia(
                image: widget.announcement.image,
                imageUrl: widget.resolvedImageUrl,
                accent: priorityAccent,
              ),
            ),
          ),
        ],
        SizedBox(height: widget.hasAnnouncementImage ? 20 : 26),
        Text(
          widget.announcement.caption,
          style: TextStyle(
            fontSize: 16,
            color: widget.bodyText,
            fontFamily: 'SFPro',
            height: 1.28,
          ),
        ),
      ],
    );
  }

  InputDecoration _editDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: widget.isDark
          ? const Color(0xFF183629)
          : const Color(0xFFF8FAF9),
      labelStyle: TextStyle(
        color: widget.isDark ? Colors.white70 : const Color(0xFF4D5B53),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  Widget _editField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: widget.bodyText, fontFamily: 'SFPro'),
      decoration: _editDecoration(label),
    );
  }

  Widget _imagePickerButton(Color accent, BuildContext context) {
    final label = _pickedImageFile?.name ?? AppLocalizations.of(context).homePickImage;
    final hasPickedImage = _pickedImageFile != null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _pickReplacementImage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF183629)
              : const Color(0xFFF8FAF9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasPickedImage
                ? accent.withValues(alpha: 0.45)
                : widget.isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.image_rounded, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.bodyText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'SFPro',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _priorityPicker(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF183629)
            : const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _priorityOption('Urgent', AppLocalizations.of(context).homeUrgent, Colors.red),
          _priorityOption('Important', AppLocalizations.of(context).homeImportant, Colors.blue),
          _priorityOption('Normal', AppLocalizations.of(context).homeNormal, AppColors.primary),
        ],
      ),
    );
  }

  Widget _priorityOption(String internalLabel, String uiLabel, Color color) {
    final selected = _priority == internalLabel;

    return ChoiceChip(
      selected: selected,
      label: Text(uiLabel),
      avatar: internalLabel == 'Normal'
          ? null
          : Icon(
              internalLabel == 'Urgent'
                  ? Icons.priority_high_rounded
                  : Icons.flag_rounded,
              size: 16,
              color: selected ? Colors.white : color,
            ),
      selectedColor: color,
      backgroundColor: widget.isDark ? const Color(0xFF10251C) : Colors.white,
      side: BorderSide(
        color: selected
            ? color
            : widget.isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: TextStyle(
        color: selected ? Colors.white : widget.bodyText,
        fontWeight: FontWeight.w700,
        fontFamily: 'SFPro',
      ),
      onSelected: (_) => setState(() => _priority = internalLabel),
    );
  }

  Widget _priorityBadge(String priority, Color accent) {
    final normalized = priority.trim().isEmpty ? 'Normal' : priority.trim();
    final isUrgent = normalized.toLowerCase() == 'urgent';
    final isImportant = normalized.toLowerCase() == 'important';
    
    final icon = isUrgent
        ? Icons.priority_high_rounded
        : Icons.flag_rounded;
        
    final t = AppLocalizations.of(context);
    final uiLabel = isUrgent ? t.homeUrgent : (isImportant ? t.homeImportant : t.homeNormal);

    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              uiLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'SFPro',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementMedia({
    required PlatformFile? image,
    required String? imageUrl,
    required Color accent,
  }) {
    if (image != null) {
      return Image(
        image: kIsWeb 
            ? MemoryImage(image.bytes!) as ImageProvider
            : FileImage(File(image.path!)),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _announcementImageFallback(accent),
      );
    }

    return CachedImageWidget(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      errorWidget: _announcementImageFallback(accent),
    );
  }

  Widget _announcementImageFallback(Color accent) {
    return Container(
      color: accent.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(Icons.image_not_supported_outlined, color: accent),
    );
  }

  ImageProvider? _announcementImageProvider(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'assets/profile.png') return null;
    if (trimmed.startsWith('assets/')) return AssetImage(trimmed);
    final resolved = ApiClient.resolveUrl(trimmed);
    if (resolved == null || resolved.isEmpty) return null;
    return NetworkImage(resolved);
  }
}

class _AnnouncementActionSlider extends StatefulWidget {
  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool enabled;

  const _AnnouncementActionSlider({
    required this.child,
    required this.onEdit,
    required this.onDelete,
    this.enabled = true,
  });

  @override
  State<_AnnouncementActionSlider> createState() =>
      _AnnouncementActionSliderState();
}

class _AnnouncementActionSliderState extends State<_AnnouncementActionSlider> {
  static const double _actionWidth = 152;
  double _offset = 0;

  bool get _isOpen => _offset <= -_actionWidth / 2;

  void _snap({required bool open}) {
    setState(() => _offset = open ? -_actionWidth : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: widget.enabled ? (details) {
            setState(() {
              _offset = (_offset + details.delta.dx).clamp(-_actionWidth, 0);
            });
          } : null,
          onHorizontalDragEnd: widget.enabled ? (_) => _snap(open: _isOpen) : null,
          onTap: _offset == 0 ? null : () => _snap(open: false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ),
        if (_offset < 0)
          Positioned.fill(
            bottom: 16,
            child: Align(
              alignment: Alignment.centerRight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: -_offset,
                  child: Row(
                    children: [
                      Expanded(
                        child: _AnnouncementActionButton(
                          color: Colors.blue,
                          icon: Icons.edit_rounded,
                          label: AppLocalizations.of(context).edit,
                          onTap: () {
                            _snap(open: false);
                            widget.onEdit();
                          },
                        ),
                      ),
                      Expanded(
                        child: _AnnouncementActionButton(
                          color: Colors.red,
                          icon: Icons.delete_rounded,
                          label: AppLocalizations.of(context).delete,
                          onTap: () {
                            _snap(open: false);
                            widget.onDelete();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnnouncementActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AnnouncementActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'SFPro',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCarousel extends StatefulWidget {
  final List<Event> events;

  const _EventCarousel({required this.events});

  @override
  State<_EventCarousel> createState() => _EventCarouselState();
}

class _EventCarouselState extends State<_EventCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  static const List<String> _weekDays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Group events by calendar day so each card shows one day's schedule.
  List<_DayEvents> _groupByDay(List<Event> events) {
    final Map<String, List<Event>> grouped = {};
    for (final e in events) {
      final key = '${e.date.year}-${e.date.month}-${e.date.day}';
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final days = <_DayEvents>[];
    for (final entry in grouped.entries) {
      final first = entry.value.first;
      days.add(_DayEvents(date: first.date, events: entry.value));
    }
    days.sort((a, b) => a.date.compareTo(b.date));
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final dayGroups = _groupByDay(widget.events);
    if (dayGroups.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── card carousel ──
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: dayGroups.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final day = dayGroups[index];
              return _buildDayCard(context, day);
            },
          ),
        ),

        // ── page dots ──
        if (dayGroups.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(dayGroups.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildDayCard(BuildContext context, _DayEvents day) {
    final t = AppLocalizations.of(context);
    final weekDay = _weekDays[day.date.weekday - 1];
    final typeColor = HomeView.eventTypeColor(day.events.first.type);
    final typeIcon = HomeView.eventTypeIcon(day.events.first.type);
    
    // Convert MONDAY -> monday, etc. then get translated text
    String translatedWeekday = weekDay;
    switch(weekDay) {
      case 'MONDAY': translatedWeekday = t.monday; break;
      case 'TUESDAY': translatedWeekday = t.tuesday; break;
      case 'WEDNESDAY': translatedWeekday = t.wednesday; break;
      case 'THURSDAY': translatedWeekday = t.thursday; break;
      case 'FRIDAY': translatedWeekday = t.friday; break;
      case 'SATURDAY': translatedWeekday = t.saturday; break;
      case 'SUNDAY': translatedWeekday = t.sunday; break;
    }

    final dateStr = '${day.date.day}/${day.date.month}/${day.date.year}.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AnimatedPressable(
        onTap: () => Navigator.push(
          context,
          AppPageRoute(
            child: DayEventsDetailView(date: day.date, events: day.events),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [typeColor, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: typeColor.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // ── faded icon behind the date ──
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Icon(
                      typeIcon,
                      size: 110,
                      color: typeColor.withValues(alpha: 0.12),
                    ),
                  ),
                ),

                // ── content ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      // ── left: day & date ──
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              translatedWeekday.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'Facon',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 1.2,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontFamily: 'Facon',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── vertical black rail ──
                      Container(
                        width: 2.5,
                        height: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // ── right: event list (type above time, no boxes) ──
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: day.events.map((event) {
                            final timeStr = _formatTime(context, event.time);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.type.toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'SFPro',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontFamily: 'SFPro',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black.withValues(alpha: 0.55),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

// helper to group events by day
class _DayEvents {
  final DateTime date;
  final List<Event> events;
  _DayEvents({required this.date, required this.events});
}
