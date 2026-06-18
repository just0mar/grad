import 'package:eqq/messages/MessagesView.dart';
import 'package:eqq/profile/ProfileView.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../appbar/CustomAppBar.dart';
import '../addclub/AddClubView.dart';
import '../addevent/AddEventView.dart';
import '../addmembers/AddMembersView.dart';
import '../addteam/AddTeamModel.dart';
import '../addteam/AddTeamView.dart';
import '../announcement/AddAnnouncementView.dart';
import '../announcement/AnnouncementModel.dart';
import '../askeqiupxio/AskEqiupeIoView.dart';
import '../event/EventModel.dart';
import '../event/EventView.dart';
import '../event/event_bloc.dart';
import '../home/HomeView.dart';
import '../home/home_bloc.dart';
import '../jointeam/JoinTeamView.dart';
import '../jointeam/incoming_requests_view.dart';
import '../members/MemberModel.dart';
import '../members/PlayerProfileView.dart';
import '../members/PlayerSelectionView.dart';
import '../models/api_models.dart';
import '../settings/SettingsView.dart';
import '../session/session_bloc.dart';
import '../team/TeamView.dart';
import '../team/team_bloc.dart';
import '../core/app_transitions.dart';
import '../core/app_localizations.dart';
import '../core/design_tokens.dart';
import '../core/target_navigator.dart';

class MainNavigation extends StatefulWidget {
  final String userRole;
  final String userId;

  const MainNavigation({
    super.key,
    required this.userRole,
    required this.userId,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _fabExpanded = false;

  late final AnimationController _fabRotationCtrl;
  late final Animation<double> _fabRotation;
  // Drives the expand/collapse of the action menu so it animates smoothly in
  // BOTH directions (open and close) instead of the items vanishing instantly.
  late final Animation<double> _fabMenuAnim;

  final List<int> _tabHistory = [0];

  final List<Map<String, dynamic>> _plans = [];

  String _currentSport = 'Basketball';
  String _currentTeamName = 'My Team';

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fabRotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabRotation = Tween<double>(begin: 0, end: 0.375) // 135° rotation
        .animate(CurvedAnimation(
      parent: _fabRotationCtrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));
    _fabMenuAnim = CurvedAnimation(
      parent: _fabRotationCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _buildPages();
    context.read<TeamBloc>().add(
      ConfigureTeamAccess(userId: widget.userId, fallbackRole: widget.userRole),
    );

    // Allow pushed pages (search / notifications) to jump back to Home.
    HomeFocus.requestHome = () {
      if (!mounted) return;
      if (_selectedIndex == 0) return;
      _dismissKeyboard();
      setState(() {
        _tabHistory.add(0);
        _selectedIndex = 0;
      });
    };

    // Allow child pages (e.g. Profile) to switch to the Team tab.
    HomeFocus.requestTeam = () {
      if (!mounted) return;
      _dismissKeyboard();
      setState(() {
        _tabHistory.add(2);
        _selectedIndex = 2;
      });
    };
  }

  @override
  void dispose() {
    HomeFocus.requestHome = null;
    HomeFocus.requestTeam = null;
    _fabRotationCtrl.dispose();
    super.dispose();
  }

  void _buildPages() {
    _pages = [
      const HomeView(),
      const EventView(),
      TeamView(
        sport: _currentSport,
        teamName: _currentTeamName,
        userRole: widget.userRole,
      ),
      _ProfileRouter(plans: _plans),
      MessagesView(plans: _plans),
    ];
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onTabTapped(int index) {
    if (index == _selectedIndex) return;
    _dismissKeyboard();
    _closeFab();
    setState(() {
      _tabHistory.add(index);
      _selectedIndex = index;
    });
  }

  bool _onBackPressed() {
    if (_tabHistory.length > 1) {
      _dismissKeyboard();
      setState(() {
        _tabHistory.removeLast();
        _selectedIndex = _tabHistory.last;
      });
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TeamBloc, TeamState>(
      listenWhen: (previous, current) =>
          previous.selectedTeamId != current.selectedTeamId,
      listener: (context, state) {
        final selectedTeam = state.availableTeams.firstWhere(
          (team) => team.id == state.selectedTeamId,
          orElse: () => Team(
            country: '',
            club: state.selectedTeamName,
            sport: _currentSport,
            category: '',
          ),
        );
        if (state.selectedTeamId.isNotEmpty) {
          context.read<SessionBloc>().add(
            SessionTeamSelected(state.selectedTeamId),
          );
        }
        context.read<HomeBloc>().add(
          LoadHomeData(
            clubId: selectedTeam.clubId,
            teamId: state.selectedTeamId,
          ),
        );
        context.read<EventBloc>().add(
          LoadEvents(clubId: selectedTeam.clubId, teamId: state.selectedTeamId),
        );
        setState(() {
          _currentTeamName = state.selectedTeamName;
          _currentSport = selectedTeam.sport;
          _buildPages();
        });
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _onBackPressed();
          }
        },
        // Mark the whole tab shell as a root scope so the tab pages' app bars
        // never render a stray back button (which previously appeared after a
        // theme/language change and led to a dead black screen).
        child: RootTabScope(
          child: Scaffold(
          // The FAB is rendered as an overlay inside the body Stack (instead of
          // Scaffold.floatingActionButton) so that error / downloading
          // SnackBars no longer push it upwards.
          body: Stack(
            children: [
              _AnimatedPageStack(index: _selectedIndex, children: _pages),
              // Tap-outside barrier: only present while the FAB is expanded.
              // Tapping anywhere outside the action buttons collapses the menu.
              if (_fabExpanded)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeFab,
                    child: const SizedBox.expand(),
                  ),
                ),
              // FAB menu anchored to the bottom-right, just above the nav bar.
              PositionedDirectional(
                end: 16,
                bottom: 16,
                child: _buildFabMenu(),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final t = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B3A2D) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _navItem(icon: Icons.home_rounded, label: t.home, index: 0),
              _navItem(icon: Icons.event_rounded, label: t.events, index: 1),
              _navItem(icon: Icons.group_rounded, label: t.team, index: 2),
              _navItem(icon: Icons.person_rounded, label: t.profile, index: 3),
              _navItem(
                icon: Icons.chat_bubble_rounded,
                label: t.messages,
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool selected = _selectedIndex == index;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabTapped(index),
        child: SizedBox(
          height: 64,
          // FittedBox guarantees the icon + label never overflow the fixed
          // 64px bar on small / large devices (note: "icons overflow on
          // different devices").
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon inside animated circle — lifts up when selected
              AnimatedSlide(
                offset: selected ? const Offset(0, -0.18) : Offset.zero,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  width: selected ? 46 : 36,
                  height: selected ? 46 : 36,
                  decoration: BoxDecoration(
                    color: selected ? Colors.green : Colors.transparent,
                    shape: BoxShape.circle,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: const TextStyle(),
                      child: Icon(
                        icon,
                        size: 22,
                        color: selected
                            ? Colors.white
                            : (isDark ? Colors.white54 : Colors.grey.shade500),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // Label fades out when selected so height stays locked
              AnimatedOpacity(
                opacity: selected ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    letterSpacing: 0.2,
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

  void _toggleFab() {
    _dismissKeyboard();
    setState(() => _fabExpanded = !_fabExpanded);
    if (_fabExpanded) {
      _fabRotationCtrl.forward();
    } else {
      _fabRotationCtrl.reverse();
    }
  }

  void _closeFab() {
    if (!_fabExpanded) return;
    _dismissKeyboard();
    setState(() => _fabExpanded = false);
    _fabRotationCtrl.reverse();
  }

  Widget _buildFabMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
          // Action items stay mounted and animate open/closed in both
          // directions (size + fade), driven by the same controller as the
          // FAB icon rotation, so closing no longer makes them blink out.
          SizeTransition(
            sizeFactor: _fabMenuAnim,
            axisAlignment: 1.0,
            child: FadeTransition(
              opacity: _fabMenuAnim,
              child: IgnorePointer(
                ignoring: !_fabExpanded,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ..._buildRoleActions(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 56,
            height: 56,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF0B591E),
              shape: const CircleBorder(),
              onPressed: _toggleFab,
              child: RotationTransition(
                turns: _fabRotation,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _fabExpanded ? Icons.close : Icons.sports_basketball,
                    key: ValueKey(_fabExpanded),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
  }

  List<Widget> _buildRoleActions() {
    final t = AppLocalizations.of(context);
    final String teamRole = context.select(
      (TeamBloc bloc) => bloc.state.userRoleInSelectedTeam,
    );
    final String sessionRole = context.select(
      (SessionBloc bloc) => bloc.state.currentRole ?? '',
    );
    final String activeRole = _firstNonEmpty([
      teamRole,
      sessionRole,
      widget.userRole,
    ]);
    final List<Map<String, dynamic>> actions;

    switch (_roleKey(activeRole)) {
      case 'ClubManager':
        actions = [
          {
            'icon': Icons.announcement,
            'label': t.fabAddAnnouncements,
            'type': 'addAnnouncement',
          },
          {
            'icon': Icons.group_add,
            'label': t.fabMyInvitations,
            'type': 'navigate',
            'route': const JoinTeamView(),
          },
          {
            'icon': Icons.person_add,
            'label': t.fabAddMember,
            'type': 'addMembers',
          },
          {'icon': Icons.group, 'label': t.fabCreateTeam, 'type': 'addTeam'},
          {
            'icon': Icons.settings,
            'label': t.fabSettings,
            'type': 'navigate',
            'route': const SettingsView(),
          },
        ];
        break;
      case 'TeamManager':
        actions = [
          {
            'icon': Icons.announcement,
            'label': t.fabAddAnnouncements,
            'type': 'addAnnouncement',
          },
          {
            'icon': Icons.group_add,
            'label': t.fabMyInvitations,
            'type': 'navigate',
            'route': const JoinTeamView(),
          },
          {
            'icon': Icons.person_add,
            'label': t.fabAddMember,
            'type': 'addMembers',
          },
          {'icon': Icons.group, 'label': t.fabCreateTeam, 'type': 'addTeam'},
          {
            'icon': Icons.settings,
            'label': t.fabSettings,
            'type': 'navigate',
            'route': const SettingsView(),
          },
        ];
        break;
      case 'Coach':
        actions = [
          {
            'icon': Icons.announcement,
            'label': t.fabAddAnnouncements,
            'type': 'addAnnouncement',
          },
          {
            'icon': Icons.group_add,
            'label': t.fabJoinTeam,
            'type': 'navigate',
            'route': const JoinTeamView(),
          },
          {
            'icon': Icons.link,
            'label': t.fabAskEquipo,
            'type': 'navigate',
            'route': const AskEquipoView(),
          },
          {
            'icon': Icons.settings,
            'label': t.fabSettings,
            'type': 'navigate',
            'route': const SettingsView(),
          },
        ];
        break;
      case 'FitnessCoach':
      case 'Fitness Coach':
        actions = [
          {
            'icon': Icons.announcement,
            'label': t.fabAddAnnouncements,
            'type': 'addAnnouncement',
          },
          {
            'icon': Icons.group_add,
            'label': t.fabJoinTeam,
            'type': 'navigate',
            'route': const JoinTeamView(),
          },
          {
            'icon': Icons.settings,
            'label': t.fabSettings,
            'type': 'navigate',
            'route': const SettingsView(),
          },
        ];
        break;
      case 'TeamDoctor':
      case 'Doctor':
        actions = [
          {
            'icon': Icons.announcement,
            'label': t.fabAddAnnouncements,
            'type': 'addAnnouncement',
          },
          {
            'icon': Icons.local_hospital_rounded,
            'label': t.fabInjuredPlayers,
            'type': 'selectPlayer',
            'actionType': 'medical',
          },
          {
            'icon': Icons.group_add,
            'label': t.fabJoinTeam,
            'type': 'navigate',
            'route': const JoinTeamView(),
          },
          {
            'icon': Icons.settings,
            'label': t.fabSettings,
            'type': 'navigate',
            'route': const SettingsView(),
          },
        ];
        break;
      case 'Player':
        actions = [
          {
            'icon': Icons.group_add,
            'label': t.fabMyInvitations,
            'type': 'navigate',
            'route': const JoinTeamView(),
          },
          {
            'icon': Icons.settings,
            'label': t.fabSettings,
            'type': 'navigate',
            'route': const SettingsView(),
          },
        ];
        break;
      case 'TeamAnalyst':
      case 'Analyst':
        actions = [
          {
            'icon': Icons.announcement,
            'label': t.fabAddAnnouncements,
            'type': 'addAnnouncement',
          },
          {
            'icon': Icons.group_add,
            'label': t.fabJoinTeam,
            'type': 'navigate',
            'route': const JoinTeamView(),
          },
          {
            'icon': Icons.settings,
            'label': t.fabSettings,
            'type': 'navigate',
            'route': const SettingsView(),
          },
        ];
        break;
      default:
        actions = [
          {
            'icon': Icons.group_add,
            'label': t.fabMyInvitations,
            'type': 'navigate',
            'route': const JoinTeamView(),
          },
          {
            'icon': Icons.settings,
            'label': t.fabSettings,
            'type': 'navigate',
            'route': const SettingsView(),
          },
        ];
    }

    return _sortActionsByLabelSize(actions)
        .asMap().entries.map((entry) {
          final action = entry.value;
          return StaggeredListItem(
            index: entry.key,
            staggerDelay: const Duration(milliseconds: 40),
            child: _FabActionButton(
              action: action,
              onPressed: () async {
              _dismissKeyboard();
              setState(() => _fabExpanded = false);
              _fabRotationCtrl.reverse();
              switch (action['type']) {
                case 'addClub':
                  final result = await Navigator.push(
                    context,
                    AppPageRoute(child: const AddClubView()),
                  );
                  if (!mounted) return;
                  if (result != null && result is ClubDto) {
                    context.read<SessionBloc>().add(SessionRefreshContext());
                    context.read<HomeBloc>().add(
                      LoadHomeData(
                        clubId: result.clubId,
                        teamId: context.read<TeamBloc>().state.selectedTeamId,
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${result.name} created.')),
                    );
                  }
                  break;

                case 'addTeam':
                  final result = await Navigator.push(
                    context,
                    AppPageRoute(child: const AddTeamView()),
                  );
                  if (!mounted) return;
                  if (result != null && result is Team) {
                    final Team teamWithId = result.copyWith(
                      id: result.id.isNotEmpty
                          ? result.id
                          : 'team-${DateTime.now().millisecondsSinceEpoch}',
                      memberRoles: {
                        ...result.memberRoles,
                        'self': activeRole,
                        widget.userId: activeRole,
                      },
                    );
                    context.read<HomeBloc>().add(AddTeamEvent(result));
                    context.read<TeamBloc>().add(
                      RegisterTeam(team: teamWithId, fallbackRole: activeRole),
                    );
                    context.read<TeamBloc>().add(
                      SwitchTeamContext(teamWithId.id),
                    );
                    setState(() {
                      _currentSport = teamWithId.sport;
                      _currentTeamName =
                          '${teamWithId.club} ${teamWithId.category}';
                      _buildPages();
                    });
                  }
                  break;

                case 'addEvent':
                  final result = await Navigator.push(
                    context,
                    AppPageRoute(child: const AddEventView()),
                  );
                  if (!mounted) return;
                  if (result != null && result is Event) {
                    final teamState = context.read<TeamBloc>().state;
                    final selectedTeams = teamState.availableTeams
                        .where((t) => t.id == teamState.selectedTeamId)
                        .toList();
                    context.read<EventBloc>().add(
                      AddEvent(
                        result,
                        clubId: selectedTeams.isEmpty
                            ? null
                            : selectedTeams.first.clubId,
                        teamId: teamState.selectedTeamId,
                      ),
                    );
                    _onTabTapped(1);
                  }
                  break;

                case 'addAnnouncement':
                  final currentUser = context.read<SessionBloc>().state.user;
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
                  if (!mounted) return;
                  if (result != null && result is Announcement) {
                    final teamState = context.read<TeamBloc>().state;
                    final selectedTeams = teamState.availableTeams
                        .where((t) => t.id == teamState.selectedTeamId)
                        .toList();
                    context.read<HomeBloc>().add(
                      AddAnnouncementEvent(
                        result,
                        clubId: selectedTeams.isEmpty
                            ? null
                            : selectedTeams.first.clubId,
                        teamId: teamState.selectedTeamId,
                      ),
                    );
                    _onTabTapped(0);
                  }
                  break;

                case 'addMembers':
                  await Navigator.push(
                    context,
                    AppPageRoute(child: const AddMembersView()),
                  );
                  if (!mounted) return;
                  // Since TeamBloc is now global, notifications can be handled
                  // via BlocListener in UI or simply here if we still want
                  // to peek into the state. For now, let's keep it simple.
                  break;

                case 'selectPlayer':
                  final actionType = action['actionType'] as String;
                  await Navigator.push(
                    context,
                    AppPageRoute(
                      child: PlayerSelectionView(
                        userRole: widget.userRole,
                        actionType: actionType,
                      ),
                    ),
                  );
                  if (!mounted) return;

                  break;
                case 'navigate':
                default:
                  await Navigator.push(
                    context,
                    AppPageRoute(child: action['route']),
                  );
                  if (!context.mounted) return;
              }
            },
          ),
        );
        })
        .toList();
  }

  String _roleKey(String role) => role.trim().replaceAll(' ', '');

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  List<Map<String, dynamic>> _sortActionsByLabelSize(
    List<Map<String, dynamic>> actions,
  ) {
    final sorted = List<Map<String, dynamic>>.from(actions);
    sorted.sort((a, b) {
      final aType = (a['type'] ?? '').toString();
      final bType = (b['type'] ?? '').toString();
      final override = _compareActionOverride(aType, bType);
      if (override != null) return override;
      
      final aLabel = (a['label'] ?? '').toString();
      final bLabel = (b['label'] ?? '').toString();
      final sizeCompare = aLabel.length.compareTo(bLabel.length);
      if (sizeCompare != 0) return sizeCompare;
      return aLabel.compareTo(bLabel);
    });
    return sorted;
  }

  int? _compareActionOverride(String aType, String bType) {
    const overrides = {'navigate': 0, 'addTeam': 1}; // Note: navigate usually maps to settings which we want at the bottom
    // Better, we use the route or label indirectly. Actually we can just use the type.
    // If it's settings, let's keep it at the end.
    
    // Simplification for the override:
    // If aType is navigate and bType is addTeam...
    // Actually wait, let's just use the hardcoded logic based on type.
    return null; // Let label size determine order for now.
  }
}

class _FabActionButton extends StatefulWidget {
  final Map<String, dynamic> action;
  final VoidCallback onPressed;

  const _FabActionButton({required this.action, required this.onPressed});

  @override
  State<_FabActionButton> createState() => _FabActionButtonState();
}

class _FabActionButtonState extends State<_FabActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: AnimatedPressable(
        onTap: widget.onPressed,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _hovered ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.action['icon'], color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  widget.action['label'],
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Page switcher — PageView-backed so tab transitions use the exact same
//    smooth physics as the announcement / event card carousels.
//    Pages are wrapped in _KeepAlive so scroll position and state survive
//    every tab switch.

class _AnimatedPageStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _AnimatedPageStack({required this.index, required this.children});

  @override
  State<_AnimatedPageStack> createState() => _AnimatedPageStackState();
}

class _AnimatedPageStackState extends State<_AnimatedPageStack> {
  // Nullable so any build/didUpdateWidget call that races before initState
  // completes (e.g. from a BlocListener parent rebuild) never throws a
  // LateInitializationError.
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.index);
  }

  @override
  void didUpdateWidget(_AnimatedPageStack old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index) {
      _pageController?.animateToPage(
        widget.index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      // Disable finger-swipe so gestures inside pages (lists, maps …) are
      // never accidentally hijacked.
      physics: const NeverScrollableScrollPhysics(),
      children: widget.children
          .map((child) => _KeepAlive(child: child))
          .toList(),
    );
  }
}

/// Keeps a page widget alive in the PageView so its scroll position and
/// BLoC-driven state are preserved when the user switches tabs.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by the mixin
    return widget.child;
  }
}

/// Routes to [PlayerProfileView] when the user is a Player on the active team,
/// otherwise falls back to the standard [ProfileView].
class _ProfileRouter extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  const _ProfileRouter({required this.plans});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamBloc, TeamState>(
      buildWhen: (prev, curr) =>
          prev.userRoleInSelectedTeam != curr.userRoleInSelectedTeam ||
          prev.members != curr.members ||
          prev.selectedTeamId != curr.selectedTeamId,
      builder: (context, teamState) {
        final role = teamState.userRoleInSelectedTeam.trim().replaceAll(
          ' ',
          '',
        );
        if (role != 'Player') return ProfileView(plans: plans);

        final session = context.watch<SessionBloc>().state;
        final userId = session.user?.userId ?? '';
        if (userId.isEmpty) return ProfileView(plans: plans);

        // Find the player's Member entry in the team member list
        final memberIndex = teamState.members.indexWhere(
          (m) => m.userId == userId,
        );

        final Member member;
        if (memberIndex >= 0) {
          member = teamState.members[memberIndex];
        } else {
          // Construct a fallback Member from session data
          member = Member(
            userId: userId,
            email: session.user?.email ?? '',
            name: session.user?.name ?? '',
            role: 'Player',
            profileImageUrl: session.user?.profileImageUrl,
          );
        }

        return PlayerProfileView(
          member: member,
          memberIndex: memberIndex >= 0 ? memberIndex : 0,
        );
      },
    );
  }
}
