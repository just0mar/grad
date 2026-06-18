import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/responsive_system.dart';
import '../home/home_bloc.dart';
import '../session/session_bloc.dart';
import '../core/app_transitions.dart';
import '../team/team_bloc.dart';
import 'join_team_bloc.dart';
import '../core/animated_button.dart';
import '../core/app_localizations.dart';

class JoinTeamView extends StatelessWidget {
  const JoinTeamView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => JoinTeamBloc()..add(LoadJoinRequests()),
      child: const _MyInvitationsContent(),
    );
  }
}

class _MyInvitationsContent extends StatelessWidget {
  const _MyInvitationsContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: AppLocalizations.of(context).titleMyInvitations, showTeamSwitcher: false),
      body: AppBackground(
        child: SafeArea(
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return BlocConsumer<JoinTeamBloc, JoinTeamState>(
                listenWhen: (previous, current) =>
                    current.message != null || current.error != null,
                listener: (context, state) {
                  if (state.error != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.error!)));
                    return;
                  }
                  if (state.message != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.message!)));
                  }
                  context.read<SessionBloc>().add(SessionRefreshContext());
                  context.read<TeamBloc>().add(LoadTeamMembers());
                  context.read<HomeBloc>().add(LoadHomeData());
                },
                builder: (context, state) {
                  if (state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final requests = state.requests;

                  if (requests.isEmpty) {
                    return _buildEmptyState(isDark, context);
                  }

                  return _buildInvitationList(context, requests, isDark);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mail_outline,
              size: 64,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).joinNoPending,
              style: TextStyle(
                fontFamily: 'SFPro',
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).joinNoPendingDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SFPro',
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationList(
    BuildContext context,
    List<Map<String, dynamic>> requests,
    bool isDark,
  ) {
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return ListView.builder(
      padding: ResponsiveSystem.pagePadding(context),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return AnimatedPressable(
          onTap: () => _showInvitationDetails(context, req, index, isDark),
          child: Card(
          color: cardBg,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      child: const Icon(Icons.mail, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${req["team"]}",
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'SFPro',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context).joinRole(req["members"]?.toString() ?? ''),
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontFamily: 'SFPro',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedButton.secondary(
                      child: TextButton.icon(
                      onPressed: () {
                        context.read<JoinTeamBloc>().add(RejectRequest(index));
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 18,
                      ),
                      label: Text(
                        AppLocalizations.of(context).decline,
                        style: const TextStyle(
                          color: Colors.red,
                          fontFamily: 'SFPro',
                        ),
                      ),
                    )),
                    const SizedBox(width: 8),
                    AnimatedButton.primary(
                      child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        context.read<JoinTeamBloc>().add(AcceptRequest(index));
                      },
                      icon: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        AppLocalizations.of(context).accept,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'SFPro',
                        ),
                      ),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  void _showInvitationDetails(BuildContext context, Map<String, dynamic> req, int index, bool isDark) {
    final dlgBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: dlgBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context).joinDetails,
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow(Icons.groups, AppLocalizations.of(context).joinTeamClub, req["team"]?.toString() ?? req["clubName"]?.toString() ?? AppLocalizations.of(context).joinNA, isDark),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.person_outline, AppLocalizations.of(context).addMembersRole, req["role"]?.toString() ?? req["members"]?.toString() ?? AppLocalizations.of(context).joinNA, isDark),
                if (req["playerPosition"] != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.sports_soccer, AppLocalizations.of(context).joinPosition, req["playerPosition"].toString(), isDark),
                ],
                if (req["jerseyNumber"] != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.numbers, AppLocalizations.of(context).joinJersey, req["jerseyNumber"].toString(), isDark),
                ],
                const SizedBox(height: 12),
                _buildDetailRow(Icons.person, AppLocalizations.of(context).joinInvitedBy, req["inviterName"]?.toString() ?? AppLocalizations.of(context).joinManager, isDark),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.email_outlined, AppLocalizations.of(context).joinSentTo, req["email"]?.toString() ?? AppLocalizations.of(context).joinNA, isDark),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.info_outline, AppLocalizations.of(context).joinStatus, req["status"]?.toString() ?? AppLocalizations.of(context).joinPending, isDark),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: AnimatedButton.secondary(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            side: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.read<JoinTeamBloc>().add(RejectRequest(index));
                          },
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 18,
                          ),
                          label: Text(
                            AppLocalizations.of(context).decline,
                            style: const TextStyle(
                              color: Colors.red,
                              fontFamily: 'SFPro',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedButton.primary(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.read<JoinTeamBloc>().add(AcceptRequest(index));
                          },
                          icon: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            AppLocalizations.of(context).accept,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'SFPro',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.white54 : Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'SFPro',
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'SFPro',
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
