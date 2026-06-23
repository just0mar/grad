import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/animated_button.dart';
import '../core/app_transitions.dart';
import '../core/responsive_system.dart';
import '../notifications/NotificationsView.dart';
import '../notifications/notification_bloc.dart';
import '../search/SearchView.dart';
import '../team/team_bloc.dart';

/// Marks a subtree as belonging to a root-level tab inside [MainNavigation].
///
/// Root tabs (Home / Events / Team / Profile / Messages) must NEVER render an
/// automatic back button, even when the root [Navigator] transiently reports
/// `canPop() == true`. That can happen because the app reaches the main screen
/// imperatively (splash/login `pushReplacement` / `pushAndRemoveUntil`) and a
/// theme- or language-change rebuilds the whole `MaterialApp`, forcing the
/// kept-alive tab app bars to re-evaluate `canPop()`. The stray arrow used to
/// pop `MainNavigation` itself into a dead/black route and then exit the app.
///
/// Pushed detail pages live ABOVE `MainNavigation` in the Navigator overlay, so
/// they are not descendants of this scope and keep their normal
/// `canPop()`-based back button.
class RootTabScope extends InheritedWidget {
  const RootTabScope({super.key, required super.child});

  static bool isRootTab(BuildContext context) =>
      context.getElementForInheritedWidgetOfExactType<RootTabScope>() != null;

  @override
  bool updateShouldNotify(RootTabScope oldWidget) => false;
}

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final bool? showBackButton;
  final List<Map<String, dynamic>>? plans;
  final String userRole;
  final bool showTeamSwitcher;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.showBackButton,
    this.plans,
    this.userRole = '',
    this.showTeamSwitcher = false,
    this.actions,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        showTeamSwitcher ? kToolbarHeight + 32 : kToolbarHeight,
      );

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<NotificationBloc>();
      bloc.add(const RefreshUnreadCount());
      bloc.startRealtime();
    });
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final bool canGoBack = widget.showBackButton ??
        (widget.onBack != null ||
            (!RootTabScope.isRootTab(context) &&
                Navigator.of(context).canPop()));
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor = isDark ? Colors.white : Colors.black;
    final Color textColor = isDark ? Colors.white : Colors.black;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: canGoBack
          ? Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: AnimatedButton.icon(
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: iconColor),
                  onPressed: () {
                    _dismissKeyboard();
                    final onBack = widget.onBack;
                    if (onBack != null) {
                      onBack();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            )
          : null,
      titleSpacing: 0,
      centerTitle: false,
      title: Padding(
        padding: EdgeInsetsDirectional.only(start: canGoBack ? 16 : 24),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            widget.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Facon',
              fontSize: ResponsiveSystem.titleFontSize(context),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: textColor,
            ),
          ),
        ),
      ),
      bottom: widget.showTeamSwitcher
          ? PreferredSize(
              preferredSize: const Size.fromHeight(32),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: canGoBack ? 20 : 24,
                    bottom: 8,
                  ),
                  child: _TeamSwitcher(isDark: isDark),
                ),
              ),
            )
          : null,
      actions: [
        if (widget.actions != null) ...widget.actions!,
        AnimatedButton.icon(
          child: IconButton(
            icon: Icon(Icons.search, color: iconColor),
            onPressed: () {
              _dismissKeyboard();
              Navigator.push(
                context,
                AppPageRoute(child: const SearchView()),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: AnimatedButton.icon(
            child: BlocBuilder<NotificationBloc, NotificationState>(
              builder: (context, state) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_none, color: iconColor),
                      onPressed: () {
                        _dismissKeyboard();
                        Navigator.push(
                          context,
                          AppPageRoute(
                            child: NotificationsView(userRole: widget.userRole),
                          ),
                        );
                      },
                    ),
                    if (state.unreadCount > 0)
                      PositionedDirectional(
                        end: 6,
                        top: 6,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              state.unreadCount > 9
                                  ? '9+'
                                  : state.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Team switcher chip ────────────────────────────────────────────────────────

class _TeamSwitcher extends StatefulWidget {
  final bool isDark;
  const _TeamSwitcher({required this.isDark});

  @override
  State<_TeamSwitcher> createState() => _TeamSwitcherState();
}

class _TeamSwitcherState extends State<_TeamSwitcher> {
  final GlobalKey _chipKey = GlobalKey();

  void _showTeamMenu(BuildContext context, TeamState state) {
    final renderBox =
        _chipKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final chipSize = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy + chipSize.height + 6,
        screenWidth - pos.dx - 220,
        0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? const Color(0xFF1C2B22) : Colors.white,
      elevation: 8,
      items: state.availableTeams.map((team) {
        final name = '${team.club} ${team.category}'.trim();
        final isSelected = team.id == state.selectedTeamId;
        return PopupMenuItem<String>(
          value: team.id,
          height: 44,
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: isSelected
                    ? Colors.green
                    : (isDark ? Colors.white30 : Colors.black26),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((teamId) {
      if (teamId != null &&
          teamId != state.selectedTeamId &&
          context.mounted) {
        context.read<TeamBloc>().add(SwitchTeamContext(teamId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamBloc, TeamState>(
      builder: (context, state) {
        final teamName = state.selectedTeamName;
        final hasTeam =
            teamName.isNotEmpty && !(teamName == 'My Team' && state.availableTeams.isEmpty);
        if (!hasTeam) return const SizedBox.shrink();

        final hasMultiple = state.availableTeams.length > 1;
        final isDark = widget.isDark;

        // Colours
        final chipBg = isDark
            ? const Color(0xFF0B591E).withValues(alpha: 0.30)
            : const Color(0xFF1E7D34);          // solid green in light mode
        final chipBorder = isDark
            ? const Color(0xFF2E7D32).withValues(alpha: 0.55)
            : Colors.transparent;
        final labelColor =
            isDark ? const Color(0xFF72D492) : Colors.white;  // white on green

        return GestureDetector(
          key: _chipKey,
          onTap: hasMultiple ? () => _showTeamMenu(context, state) : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: chipBorder, width: 0.9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 11,
                  color: labelColor.withValues(alpha: isDark ? 0.8 : 0.9),
                ),
                const SizedBox(width: 5),
                Text(
                  teamName,
                  style: TextStyle(
                    fontSize: 12,
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    height: 1.0,
                  ),
                ),
                if (hasMultiple) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: labelColor,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
