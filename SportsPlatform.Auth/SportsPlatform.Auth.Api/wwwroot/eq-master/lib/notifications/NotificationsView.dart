import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/app_transitions.dart';
import '../core/design_tokens.dart';
import '../core/target_navigator.dart';
import 'notification_bloc.dart';
import '../core/app_localizations.dart';

class NotificationsView extends StatefulWidget {
  final String userRole;

  const NotificationsView({super.key, required this.userRole});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationBloc>().add(const LoadNotifications());
      }
    });
  }

  String _timeAgo(DateTime dt, BuildContext context) {
    final t = AppLocalizations.of(context);
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return t.notifJustNow;
    if (diff.inMinutes < 60) return t.notifMinsAgo(diff.inMinutes);
    if (diff.inHours < 24) return t.notifHoursAgo(diff.inHours);
    return t.notifDaysAgo(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Match the Home page: let the page gradient extend behind the
      // transparent AppBar so the bar style/colour/background line up.
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: AppLocalizations.of(context).titleNotifications,
        showTeamSwitcher: false,
        userRole: widget.userRole,
      ),
      body: AppBackground(
        child: SafeArea(
          child: BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              // All notifications are visible to all users (visibleToRoles: ['All'])
              // This guarantees injury/medical alerts reach every team member.
              final notifications =
                  state.notificationsForRole(widget.userRole);

              return Column(
                children: [
                  // ── Header bar ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                    child: Row(
                      children: [
                        // Unread pill
                        if (state.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  AppLocalizations.of(context).notifUnreadCount(state.unreadCount),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            AppLocalizations.of(context).notifAllCaughtUp,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const Spacer(),
                        if (state.unreadCount > 0)
                          TextButton.icon(
                            onPressed: () => context
                                .read<NotificationBloc>()
                                .add(MarkAllRead(widget.userRole)),
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: Text(AppLocalizations.of(context).notifMarkAllRead),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── List ────────────────────────────────────────────────────
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => context
                          .read<NotificationBloc>()
                          .add(const LoadNotifications()),
                      child: state.isLoading && notifications.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : notifications.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.55,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons
                                                  .notifications_none_rounded,
                                              size: 48,
                                              color: isDark
                                                  ? Colors.white30
                                                  : Colors.black26,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              AppLocalizations.of(context).notifEmpty,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.black45,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    6,
                                    20,
                                    24,
                                  ),
                                  itemCount: notifications.length,
                                  itemBuilder: (context, index) {
                                    final n = notifications[index];
                                    return StaggeredListItem(
                                      index: index,
                                      child: _NotificationCard(
                                        notification: n,
                                        timeAgo: _timeAgo(n.timestamp, context),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Notification card ──────────────────────────────────────────────────────────

class _NotificationCard extends StatefulWidget {
  final AppNotification notification;
  final String timeAgo;

  const _NotificationCard({
    required this.notification,
    required this.timeAgo,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _expanded = false;

  void _handleTap(BuildContext context) {
    final n = widget.notification;

    // Mark as read
    if (!n.isRead) {
      context.read<NotificationBloc>().add(MarkRead(n.id));
    }

    // Navigate to the relevant section, otherwise expand the message inline.
    // Route when there's an explicit target OR the notification kind is one we
    // know how to open (fitness / medical / event / announcement / etc.).
    final kind =
        '${n.targetType ?? ''} ${n.type} ${n.title}'.toLowerCase();
    final isActionableKind = kind.contains('fitness') ||
        kind.contains('medical') ||
        kind.contains('injury') ||
        kind.contains('announce') ||
        kind.contains('event') ||
        kind.contains('match') ||
        kind.contains('training') ||
        kind.contains('plan') ||
        kind.contains('lineup') ||
        kind.contains('stat');
    final hasTarget = (n.targetType != null && n.targetType!.isNotEmpty) ||
        (n.targetId != null && n.targetId!.isNotEmpty) ||
        isActionableKind;

    if (hasTarget) {
      openNotification(
        context: context,
        type: n.type,
        targetType: n.targetType,
        targetId: n.targetId,
        clubId: n.clubId,
        teamId: n.teamId,
        title: n.title,
        subtitle: n.subtitle,
        metadataJson: n.metadataJson,
      );
    } else if (n.message.isNotEmpty) {
      setState(() => _expanded = !_expanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n = widget.notification;
    final hasMessage = n.message.isNotEmpty;
    final hasRoute = n.targetRoute != null && n.targetRoute!.isNotEmpty;

    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final unreadBg =
        isDark ? const Color(0xFF1F4535) : Colors.green.shade50;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return AnimatedPressable(
      onTap: () => _handleTap(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: n.isRead ? cardBg : unreadBg,
          borderRadius: BorderRadius.circular(14),
          border: n.isRead
              ? null
              : Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: n.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(n.icon, color: n.color, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.timeAgo,
                              style: TextStyle(
                                fontSize: 11,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          n.subtitle,
                          style: TextStyle(fontSize: 13, color: subtitleColor),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Trailing indicator
                  if (!n.isRead)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  else if (hasRoute)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: subtitleColor,
                    )
                  else if (hasMessage)
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: subtitleColor,
                    ),
                ],
              ),

              // Expanded message (shown when no targetRoute)
              if (_expanded && hasMessage && !hasRoute) ...[
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
                const SizedBox(height: 10),
                Text(
                  n.message,
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
