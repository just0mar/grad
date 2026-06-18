import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/app_transitions.dart';
import '../core/responsive_system.dart';
import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/join_request_service.dart';
import '../team/team_bloc.dart';
import '../core/animated_button.dart';
import '../core/app_localizations.dart';

/// Manager-facing view that lists pending invitations for the selected team.
/// Managers can cancel (decline) pending invitations from here.
class IncomingRequestsView extends StatefulWidget {
  const IncomingRequestsView({super.key});

  @override
  State<IncomingRequestsView> createState() => _IncomingRequestsViewState();
}

class _IncomingRequestsViewState extends State<IncomingRequestsView> {
  final JoinRequestService _service = JoinRequestService();
  List<InvitationDto> _invitations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    final teamState = context.read<TeamBloc>().state;
    final selectedTeams = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();

    if (selectedTeams.isEmpty || (selectedTeams.first.clubId ?? '').isEmpty) {
      setState(() {
        _isLoading = false;
        _error = AppLocalizations.of(context).incNoTeamSelected;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final invitations = await _service.getTeamInvitations(
        selectedTeams.first.clubId!,
        teamState.selectedTeamId,
      );
      // Show only pending invitations
      setState(() {
        _invitations = invitations
            .where((i) => i.status.toLowerCase() == 'pending')
            .toList();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = AppLocalizations.of(context).incErrLoad;
      });
    }
  }

  Future<void> _cancelInvitation(InvitationDto invitation) async {
    final teamState = context.read<TeamBloc>().state;
    final selectedTeams = teamState.availableTeams
        .where((t) => t.id == teamState.selectedTeamId)
        .toList();

    if (selectedTeams.isEmpty || (selectedTeams.first.clubId ?? '').isEmpty) {
      return;
    }

    try {
      await _service.cancelInvitation(
        selectedTeams.first.clubId!,
        teamState.selectedTeamId,
        invitation.invitationId,
      );
      setState(() {
        _invitations.removeWhere(
          (i) => i.invitationId == invitation.invitationId,
        );
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).incCancelled(invitation.email)),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).incErrCancel)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: AppLocalizations.of(context).titleJoinRequests, showTeamSwitcher: false),
      body: AppBackground(
        child: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadInvitations,
                child: _buildContent(isDark),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontFamily: 'SFPro',
                ),
              ),
              const SizedBox(height: 16),
              AnimatedButton.secondary(
                child: TextButton.icon(
                onPressed: _loadInvitations,
                icon: const Icon(Icons.refresh),
                label: Text(
                  AppLocalizations.of(context).retry,
                  style: const TextStyle(fontFamily: 'SFPro'),
                ),
              )),
            ],
          ),
        ),
      );
    }

    if (_invitations.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: ResponsiveSystem.height(context) * 0.25),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).joinNoPending,
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).incNoPendingDesc,
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: ResponsiveSystem.pagePadding(context),
      itemCount: _invitations.length,
      itemBuilder: (context, index) =>
          _buildInvitationCard(_invitations[index], isDark),
    );
  }

  Widget _buildInvitationCard(InvitationDto invitation, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final isPlayer = invitation.role.toLowerCase() == 'player';

    return AnimatedPressable(
      child: Card(
        color: cardBg,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.15),
                  child: Text(
                    invitation.email.isNotEmpty
                        ? invitation.email[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.email,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'SFPro',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatRole(invitation.role, context),
                              style: const TextStyle(
                                color: Colors.green,
                                fontFamily: 'SFPro',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              invitation.status,
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontFamily: 'SFPro',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isPlayer &&
                (invitation.playerPosition != null ||
                    invitation.jerseyNumber != null)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (invitation.playerPosition != null) ...[
                    Icon(
                      Icons.sports_soccer,
                      size: 16,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      invitation.playerPosition!,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontFamily: 'SFPro',
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (invitation.playerPosition != null &&
                      invitation.jerseyNumber != null)
                    const SizedBox(width: 16),
                  if (invitation.jerseyNumber != null) ...[
                    Icon(
                      Icons.tag,
                      size: 16,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '#${invitation.jerseyNumber}',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontFamily: 'SFPro',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedButton.secondary(
                  child: TextButton.icon(
                  onPressed: () => _cancelInvitation(invitation),
                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                  label: Text(
                    AppLocalizations.of(context).cancel,
                    style: const TextStyle(color: Colors.red, fontFamily: 'SFPro'),
                  ),
                )),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  String _formatRole(String role, BuildContext context) {
    final t = AppLocalizations.of(context);
    switch (role) {
      case 'Player': return t.rolePlayer;
      case 'Coach': return t.roleCoach;
      case 'FitnessCoach': return t.roleFitnessCoach;
      case 'TeamAnalyst': return t.roleTeamAnalyst;
      case 'TeamDoctor': return t.roleTeamDoctor;
      case 'TeamManager': return t.roleTeamManager;
      case 'ClubManager': return t.roleClubManager;
      default: return role;
    }
  }
}
