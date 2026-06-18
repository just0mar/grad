import 'package:flutter/material.dart';
import '../core/animated_dropdown.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/LoginView.dart';
import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/app_transitions.dart';
import '../core/app_bloc.dart';
import '../core/app_localizations.dart';
import '../core/design_tokens.dart';
import '../core/responsive_widgets.dart';
import '../models/api_models.dart';
import '../services/api_client.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/club_service.dart';
import '../session/session_bloc.dart';
import '../team/team_bloc.dart';
import '../team/TeamView.dart';
import '../core/animated_button.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  void _showLogoutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final t = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Icon(Icons.close, color: textColor),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t.logOutConfirm,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SFPro',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              AnimatedButton.primary(
                child: ResponsivePrimaryButton(
                context: ctx,
                label: t.cancel,
                onPressed: () => Navigator.pop(ctx),
              )),
              const SizedBox(height: 16),
              AnimatedButton.primary(
                child: ResponsivePrimaryButton(
                context: ctx,
                label: t.yesLogOut,
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushAndRemoveUntil(
                    context,
                    AppFadeRoute(child: const LoginView()),
                    (route) => false,
                  );
                },
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.red,
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveTeamDialog(BuildContext context, dynamic team) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final teamName = '${team.club} ${team.category}'.trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(
          AppLocalizations.of(context).leaveTeamTitle,
          style: TextStyle(color: textColor, fontFamily: 'SFPro'),
        ),
        content: Text(
          AppLocalizations.of(context).leaveTeamDesc(teamName),
          style: TextStyle(color: textColor, fontFamily: 'SFPro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TeamBloc>().add(
                    LeaveTeam(clubId: team.clubId!, teamId: team.id),
                  );
            },
            child: Text(AppLocalizations.of(context).leave, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLeaveClubDialog(BuildContext context, ClubDto club) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(
          AppLocalizations.of(context).leaveClubTitle,
          style: TextStyle(color: textColor, fontFamily: 'SFPro'),
        ),
        content: Text(
          AppLocalizations.of(context).leaveClubDesc(club.name),
          style: TextStyle(color: textColor, fontFamily: 'SFPro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = context.read<SessionBloc>().state.user?.userId;
              if (userId == null || userId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).errAccount)),
                );
                return;
              }
              try {
                await ClubService().leaveClub(club.clubId, userId);
                if (!context.mounted) return;
                context.read<SessionBloc>().add(SessionRefreshContext());
                context.read<TeamBloc>().add(LoadTeamMembers());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).leftClub(club.name))),
                );
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).errLeaveClub)),
                );
              }
            },
            child: Text(AppLocalizations.of(context).leave, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openTermsPrivacy(BuildContext context) {
    Navigator.push(
      context,
      AppPageRoute(child: const _TermsPrivacyView()),
    );
  }

  void _openClub(BuildContext context, ClubDto club) {
    Navigator.push(
      context,
      AppPageRoute(child: _ClubDetailView(club: club)),
    );
  }

  void _openTeam(BuildContext context, dynamic team) {
    context.read<TeamBloc>().add(SwitchTeamContext(team.id));
    Navigator.push(
      context,
      AppPageRoute(
        child: TeamView(
          sport: team.sport,
          teamName: '${team.club} ${team.category}'.trim(),
          userRole: team.memberRoles['self'] ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: AppLocalizations.of(context).titleSettings),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          final t = AppLocalizations.of(context);
          return AppBackground(
              child: SafeArea(
                  child: ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      AppSpacing.md,
                      16,
                      16,
                    ),
                    children: [
                      // Language
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B3A2D)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ListTile(
                          title: Text(
                            t.language,
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          trailing: AnimatedDropdown(
                            child: DropdownButton<String>(
                                menuMaxHeight: 280,
                                borderRadius: BorderRadius.circular(16),
                                elevation: 8,
                                underline: const SizedBox.shrink(),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.green, size: 22),
                              value: state.locale.languageCode,
                              dropdownColor: isDark
                                  ? const Color(0xFF1B3A2D)
                                  : Colors.white,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      AppLocalizations.displayName('en'),
                                      style: const TextStyle(fontFamily: 'SFPro'),
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'ar',
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      AppLocalizations.displayName('ar'),
                                      style: const TextStyle(fontFamily: 'SFPro'),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val == null) return;
                                context.read<AppBloc>().add(LocaleChanged(val));
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      // Theme
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B3A2D)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ListTile(
                          title: Text(
                            t.theme,
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.wb_sunny,
                                  color: state.themeMode == ThemeMode.light
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                                onPressed: () {
                                  context.read<AppBloc>().add(
                                    ThemeChanged(ThemeMode.light),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: Icon(
                                  Icons.nightlight_round,
                                  color: state.themeMode == ThemeMode.dark
                                      ? Colors.blueGrey
                                      : Colors.grey,
                                ),
                                onPressed: () {
                                  context.read<AppBloc>().add(
                                    ThemeChanged(ThemeMode.dark),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      Text(
                        t.myTeams,
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      BlocConsumer<TeamBloc, TeamState>(
                        listenWhen: (previous, current) =>
                            previous.permissionError != current.permissionError ||
                            previous.successMessage != current.successMessage,
                        listener: (context, teamState) {
                          final message =
                              teamState.permissionError ?? teamState.successMessage;
                          if (message == null) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                          context.read<TeamBloc>().add(ClearTeamMessage());
                        },
                        builder: (context, teamState) {
                          if (teamState.availableTeams.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1B3A2D)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Text(
                                t.noTeamsAvailable,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: teamState.availableTeams.map((team) {
                              final bool selected =
                                  team.id == teamState.selectedTeamId;
                              final role = team.memberRoles[
                                      teamState.currentUserId] ??
                                  team.memberRoles['self'] ??
                                  teamState.userRoleInSelectedTeam;
                              return AnimatedPressable(
                                onTap: () => _openTeam(context, team),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 14,
                                  ),
                                  margin: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1B3A2D)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.primary
                                          : Colors.grey,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.primary
                                                  .withValues(alpha: 0.15)
                                              : (isDark
                                                    ? Colors.black.withValues(
                                                        alpha: 0.18,
                                                      )
                                                    : const Color(0xFFE8F5E9)),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.groups_rounded,
                                          color: selected
                                              ? AppColors.primary
                                              : (isDark
                                                    ? Colors.white70
                                                    : Colors.green.shade700),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${team.club} ${team.category}'
                                                  .trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'SFPro',
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              role.isEmpty ? t.teamMember : role,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'SFPro',
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white60
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      AnimatedButton.icon(
                                        child: IconButton(
                                          tooltip: 'Leave team',
                                          icon: const Icon(
                                            Icons.logout_rounded,
                                            color: Colors.red,
                                          ),
                                          onPressed: team.clubId == null ||
                                                  team.clubId!.isEmpty
                                              ? null
                                              : () => _showLeaveTeamDialog(
                                                    context,
                                                    team,
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        t.myClubs,
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      BlocBuilder<SessionBloc, SessionState>(
                        builder: (context, sessionState) {
                          if (sessionState.clubs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1B3A2D)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Text(
                                t.noClubsAvailable,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: sessionState.clubs.map((club) {
                              final bool selected =
                                  club.clubId == sessionState.activeClubId;
                              return AnimatedPressable(
                                onTap: () => _openClub(context, club),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 14,
                                  ),
                                  margin: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1B3A2D)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.primary
                                          : Colors.grey,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.primary
                                                  .withValues(alpha: 0.15)
                                              : (isDark
                                                    ? Colors.black.withValues(
                                                        alpha: 0.18,
                                                      )
                                                    : const Color(0xFFE8F5E9)),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.apartment_rounded,
                                          color: selected
                                              ? AppColors.primary
                                              : (isDark
                                                    ? Colors.white70
                                                    : Colors.green.shade700),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              club.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'SFPro',
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              club.myRole ?? t.member,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'SFPro',
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white60
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      AnimatedButton.icon(
                                        child: IconButton(
                                          tooltip: 'Leave club',
                                          icon: const Icon(
                                            Icons.logout_rounded,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _showLeaveClubDialog(
                                            context,
                                            club,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B3A2D)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ListTile(
                          onTap: () => _openTermsPrivacy(context),
                          title: Text(
                            t.termsOfPrivacy,
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // Log out
                      AnimatedPressable(
                        onTap: () => _showLogoutDialog(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1B3A2D)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Center(
                            child: Text(
                              t.logOut,
                              style: const TextStyle(
                                fontFamily: 'SFPro',
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          );
        },
      ),
    );
  }
}

class _TermsPrivacyView extends StatelessWidget {
  const _TermsPrivacyView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.white70 : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: AppLocalizations.of(context).termsTitle.toUpperCase()),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              16,
              AppSpacing.md,
              16,
              24,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontFamily: 'SFPro',
                  color: subtextColor,
                  height: 1.45,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).termsTitle,
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TermsSection(
                      title: AppLocalizations.of(context).termsS1T,
                      body: AppLocalizations.of(context).termsS1B,
                      textColor: textColor,
                    ),
                    _TermsSection(
                      title: AppLocalizations.of(context).termsS2T,
                      body: AppLocalizations.of(context).termsS2B,
                      textColor: textColor,
                    ),
                    _TermsSection(
                      title: AppLocalizations.of(context).termsS3T,
                      body: AppLocalizations.of(context).termsS3B,
                      textColor: textColor,
                    ),
                    _TermsSection(
                      title: AppLocalizations.of(context).termsS4T,
                      body: AppLocalizations.of(context).termsS4B,
                      textColor: textColor,
                    ),
                    _TermsSection(
                      title: AppLocalizations.of(context).termsS5T,
                      body: AppLocalizations.of(context).termsS5B,
                      textColor: textColor,
                    ),
                    _TermsSection(
                      title: AppLocalizations.of(context).termsS6T,
                      body: AppLocalizations.of(context).termsS6B,
                      textColor: textColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String body;
  final Color textColor;

  const _TermsSection({
    required this.title,
    required this.body,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}

class _ClubDetailView extends StatelessWidget {
  final ClubDto club;

  const _ClubDetailView({required this.club});

  Future<void> _leaveClub(BuildContext context) async {
    final userId = context.read<SessionBloc>().state.user?.userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errAccount)),
      );
      return;
    }
    try {
      await ClubService().leaveClub(club.clubId, userId);
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      context.read<SessionBloc>().add(SessionRefreshContext());
      context.read<TeamBloc>().add(LoadTeamMembers());
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).leftClub(club.name))),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errLeaveClub)),
      );
    }
  }

  void _confirmLeaveClub(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(
          AppLocalizations.of(context).leaveClubTitle,
          style: TextStyle(color: textColor, fontFamily: 'SFPro'),
        ),
        content: Text(
          AppLocalizations.of(context).leaveClubDesc(club.name),
          style: TextStyle(color: textColor, fontFamily: 'SFPro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _leaveClub(context);
            },
            child: Text(AppLocalizations.of(context).leave, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.white60 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final logoUrl = ApiClient.resolveUrl(club.logoUrl);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: club.name),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              16,
              AppSpacing.md,
              16,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : const Color(0xFFE8F5E9),
                        backgroundImage:
                            logoUrl == null ? null : NetworkImage(logoUrl),
                        child: logoUrl == null
                            ? const Icon(
                                Icons.apartment,
                                color: AppColors.primary,
                                size: 38,
                              )
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        club.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        club.myRole ?? 'Member',
                        style: const TextStyle(
                          fontFamily: 'SFPro',
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedPressable(
                  onTap: () => _confirmLeaveClub(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, color: Colors.red),
                        const SizedBox(width: 10),
                        Text(
                          AppLocalizations.of(context).leaveClubTitle.replaceAll('?', ''),
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _ClubInfoRow(
                        title: AppLocalizations.of(context).clubIdLabel,
                        value: club.clubId,
                        textColor: textColor,
                        subtextColor: subtextColor,
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: (club.locationLatitude != null && club.locationLongitude != null)
                          ? () async {
                              final url = 'https://maps.google.com/?q=${club.locationLatitude},${club.locationLongitude}';
                              try {
                                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                              } catch (_) {}
                            }
                          : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            children: [
                              _ClubInfoRow(
                                title: AppLocalizations.of(context).clubLocationLabel,
                                value: club.location?.isNotEmpty == true
                                    ? club.location!
                                    : AppLocalizations.of(context).notSetLabel,
                                textColor: textColor,
                                subtextColor: subtextColor,
                              ),
                              const SizedBox(height: 14),
                              _ClubInfoRow(
                                title: AppLocalizations.of(context).clubCoordinatesLabel,
                                value: club.locationLatitude != null &&
                                        club.locationLongitude != null
                                    ? '${club.locationLatitude}, ${club.locationLongitude}'
                                    : AppLocalizations.of(context).notSetLabel,
                                textColor: textColor,
                                subtextColor: subtextColor,
                              ),
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
        ),
      ),
    );
  }
}

class _ClubInfoRow extends StatelessWidget {
  final String title;
  final String value;
  final Color textColor;
  final Color subtextColor;

  const _ClubInfoRow({
    required this.title,
    required this.value,
    required this.textColor,
    required this.subtextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontFamily: 'SFPro', color: subtextColor),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: 'SFPro',
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
