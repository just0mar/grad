import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../addteam/AddTeamModel.dart';
import '../addteam/AddTeamView.dart';
import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/animated_dropdown.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../core/app_background.dart';
import '../core/app_transitions.dart';
import '../core/design_tokens.dart';
import '../core/responsive_system.dart';
import '../core/responsive_widgets.dart';
import '../services/api_client.dart';
import '../services/invitation_service.dart';
import '../session/session_bloc.dart';
import '../team/team_bloc.dart';
import '../core/app_localizations.dart';

class AddMembersView extends StatelessWidget {
  const AddMembersView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AddMembersContent();
  }
}

class _AddMembersContent extends StatefulWidget {
  const _AddMembersContent();

  @override
  State<_AddMembersContent> createState() => _AddMembersContentState();
}

class _AddMembersContentState extends State<_AddMembersContent>
    with TickerProviderStateMixin, SmoothKeyboardMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _jerseyController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final InvitationService _invitationService = InvitationService();

  String _scope = 'Team';
  String _selectedRole = 'Player';
  String? _selectedTeamId;
  String? _selectedPosition;
  bool _isSending = false;

  static const List<String> _allTeamRoles = [
    'Player',
    'Coach',
    'TeamAnalyst',
    'TeamDoctor',
    'FitnessCoach',
    'TeamManager',
  ];

  static const List<String> _playerPositions = [
    'Point Guard',
    'Shooting Guard',
    'Small Forward',
    'Power Forward',
    'Center',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-select the active team
    final teamState = context.read<TeamBloc>().state;
    _selectedTeamId = teamState.selectedTeamId;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _jerseyController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    updateKeyboardHeight(MediaQuery.viewInsetsOf(context).bottom);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final bool isPlayer = _selectedRole == 'Player';
    final bool isClubScope = _scope == 'Club';
    final teamRole = context.select(
      (TeamBloc bloc) => bloc.state.userRoleInSelectedTeam,
    );
    final sessionRole = context.select(
      (SessionBloc bloc) => bloc.state.currentRole ?? '',
    );
    final managesAnyClub = context.select(
      (SessionBloc bloc) => bloc.state.clubs.any(
        (club) => _roleKey(club.myRole ?? '') == 'clubmanager',
      ),
    );
    final bool isClubManager =
        _roleKey(teamRole) == 'clubmanager' ||
        _roleKey(sessionRole) == 'clubmanager' ||
        managesAnyClub;
    final bool isTeamManager = _roleKey(teamRole) == 'teammanager';
    // TeamManagers cannot invite another TeamManager
    final teamRoles = isTeamManager
        ? _allTeamRoles.where((r) => r != 'TeamManager').toList()
        : _allTeamRoles;
    final pagePadding = ResponsiveSystem.pagePadding(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: AppLocalizations.of(context).addMembersInviteMember),
      body: buildKeyboardDismissible(child: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: pagePadding.copyWith(
              top: ResponsiveSystem.verticalGap(context),
              bottom: pagePadding.bottom + smoothKeyboardHeight,
            ),
            child: BlocBuilder<TeamBloc, TeamState>(
              buildWhen: (previous, current) =>
                  previous.availableTeams != current.availableTeams,
              builder: (context, teamState) {
                final teams = teamState.availableTeams;
                final effectiveClubScope = isClubManager && isClubScope;

                if (teams.isEmpty && !effectiveClubScope) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isClubManager) ...[
                            _buildScopeToggle(isDark, fieldColor, textColor),
                            const SizedBox(height: 24),
                          ],
                          _buildNoTeamsEmptyState(isDark),
                        ],
                      ),
                    ),
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // ── Scope toggle (only for ClubManagers) ──
                        if (isClubManager) ...[
                          _buildScopeToggle(isDark, fieldColor, textColor),
                          const SizedBox(height: 24),
                        ],

                        // ── Club scope: auto TeamManager, just email ──
                        if (effectiveClubScope) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: fieldColor,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  color: labelColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(context).addMembersRoleTeamMgr,
                                    style: TextStyle(
                                      color: textColor,
                                      fontFamily: 'SFPro',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Team scope: team selector + role dropdown + player fields ──
                        if (!effectiveClubScope) ...[
                          // Team selector
                          _buildTeamDropdown(
                            teams,
                            isDark,
                            fieldColor,
                            textColor,
                            labelColor,
                          ),
                          const SizedBox(height: 16),

                          // Role dropdown
                          AnimatedDropdown(
                            child: DropdownButtonFormField<String>(
                              menuMaxHeight: 280,
                              borderRadius: BorderRadius.circular(16),
                              elevation: 8,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.green,
                                size: 22,
                              ),
                              initialValue: teamRoles.contains(_selectedRole)
                                  ? _selectedRole
                                  : teamRoles.first,
                              dropdownColor: fieldColor,
                              style: TextStyle(
                                color: textColor,
                                fontFamily: 'SFPro',
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: fieldColor,
                                labelText: AppLocalizations.of(context).addMembersRole,
                                labelStyle: TextStyle(
                                  color: labelColor,
                                  fontFamily: 'SFPro',
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              items: teamRoles
                                  .map(
                                    (role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(_formatRole(role, context)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedRole = value);
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (isPlayer) ...[
                            TextField(
                              controller: _jerseyController,
                              style: TextStyle(
                                color: textColor,
                                fontFamily: 'SFPro',
                              ),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: fieldColor,
                                labelText: AppLocalizations.of(context).addMembersJersey,
                                hintText: '1 - 999',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black26,
                                  fontFamily: 'SFPro',
                                ),
                                labelStyle: TextStyle(
                                  color: labelColor,
                                  fontFamily: 'SFPro',
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            AnimatedDropdown(
                              delay: const Duration(milliseconds: 60),
                              child: DropdownButtonFormField<String>(
                                menuMaxHeight: 280,
                                borderRadius: BorderRadius.circular(16),
                                elevation: 8,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.green,
                                  size: 22,
                                ),
                                initialValue: _selectedPosition,
                                dropdownColor: fieldColor,
                                style: TextStyle(
                                  color: textColor,
                                  fontFamily: 'SFPro',
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: fieldColor,
                                  labelText: AppLocalizations.of(context).addMembersPosition,
                                  labelStyle: TextStyle(
                                    color: labelColor,
                                    fontFamily: 'SFPro',
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                items: _playerPositions
                                    .map(
                                      (position) => DropdownMenuItem(
                                        value: position,
                                        child: Text(_formatPosition(position, context)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedPosition = value;
                                    _positionController.text = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],

                        // ── Email field ──
                        TextField(
                          controller: _emailController,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'SFPro',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: fieldColor,
                            labelText: AppLocalizations.of(context).addMembersEmail,
                            hintText: 'member@example.com',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white24 : Colors.black26,
                              fontFamily: 'SFPro',
                            ),
                            labelStyle: TextStyle(
                              color: labelColor,
                              fontFamily: 'SFPro',
                            ),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: labelColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Send button ──
                        AnimatedButton.primary(
                          child: ResponsivePrimaryButton(
                            context: context,
                            label: _isSending ? AppLocalizations.of(context).addMembersSending : AppLocalizations.of(context).addMembersSendBtn,
                            onPressed: _isSending ? () {} : () => _sendInvitation(context),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildScopeToggle(bool isDark, Color fieldColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _scope = 'Club';
                _selectedRole = 'TeamManager';
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _scope == 'Club' ? Colors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).addMembersClub,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontWeight: FontWeight.w600,
                      color: _scope == 'Club' ? Colors.white : textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _scope = 'Team';
                _selectedRole = 'Player';
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _scope == 'Team' ? Colors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).addMembersTeam,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontWeight: FontWeight.w600,
                      color: _scope == 'Team' ? Colors.white : textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamDropdown(
    List<dynamic> teams,
    bool isDark,
    Color fieldColor,
    Color textColor,
    Color labelColor,
  ) {
    return AnimatedDropdown(
      delay: const Duration(milliseconds: 120),
      child: DropdownButtonFormField<String>(
        menuMaxHeight: 280,
        borderRadius: BorderRadius.circular(16),
        elevation: 8,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.green,
          size: 22,
        ),
        initialValue: teams.any((t) => t.id == _selectedTeamId)
            ? _selectedTeamId
            : null,
        dropdownColor: fieldColor,
        style: TextStyle(color: textColor, fontFamily: 'SFPro'),
        decoration: InputDecoration(
          filled: true,
          fillColor: fieldColor,
          labelText: AppLocalizations.of(context).addMembersTeam,
          labelStyle: TextStyle(color: labelColor, fontFamily: 'SFPro'),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
        items: teams
            .map(
              (team) => DropdownMenuItem(
                value: team.id as String,
                child: Text('${team.club} — ${team.category}'),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _selectedTeamId = value);
        },
      ),
    );
  }

  Widget _buildNoTeamsEmptyState(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white54 : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.groups_outlined, size: 64, color: subtitleColor),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).addMembersNoTeams,
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'SFPro',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).addMembersNoTeamsDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtitleColor,
                fontFamily: 'SFPro',
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            AnimatedButton.primary(
              child: ElevatedButton.icon(
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
                onPressed: _openCreateFirstTeam,
                icon: const Icon(Icons.group_add),
                label: Text(
                  AppLocalizations.of(context).addMembersCreateFirstTeam,
                  style: const TextStyle(fontFamily: 'SFPro', fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateFirstTeam() async {
    final result = await Navigator.push(
      context,
      AppPageRoute(child: const AddTeamView()),
    );
    if (!mounted) return;
    if (result is Team) {
      context.read<TeamBloc>().add(
        RegisterTeam(team: result, fallbackRole: 'TeamManager'),
      );
      context.read<TeamBloc>().add(SwitchTeamContext(result.id));
      setState(() => _selectedTeamId = result.id);
    }
  }

  Future<void> _sendInvitation(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar(t.addMembersEmailReq);
      return;
    }

    final teamState = context.read<TeamBloc>().state;
    final sessionState = context.read<SessionBloc>().state;
    final bool isClubScope = _scope == 'Club';
    final effectiveRole = isClubScope ? 'TeamManager' : _selectedRole;

    int? jerseyNumber;
    if (effectiveRole == 'Player') {
      jerseyNumber = int.tryParse(_jerseyController.text.trim());
      if (jerseyNumber == null || jerseyNumber < 1 || jerseyNumber > 999) {
        _showSnackBar(t.addMembersValidJersey);
        return;
      }
      if (_positionController.text.trim().isEmpty) {
        _showSnackBar(t.addMembersPosReq);
        return;
      }
    }

    final invitationPayload = {
      'email': email,
      'roleName': effectiveRole,
      if (effectiveRole == 'Player') 'jerseyNumber': jerseyNumber,
      if (effectiveRole == 'Player')
        'playerPosition': _positionController.text.trim(),
    };

    if (isClubScope) {
      // Club-level invitation
      String? clubId = sessionState.activeClubId;
      if (clubId == null && sessionState.clubs.isNotEmpty) {
        clubId = sessionState.clubs.first.clubId;
      }
      if (clubId == null && _selectedTeamId != null) {
        final selectedTeams = teamState.availableTeams
            .where((t) => t.id == _selectedTeamId)
            .toList();
        clubId = selectedTeams.isEmpty ? null : selectedTeams.first.clubId;
      }
      if (clubId == null || clubId.isEmpty) {
        _showSnackBar(t.addMembersErrClub);
        return;
      }

      setState(() => _isSending = true);
      try {
        await _invitationService.createClubInvitation(
          clubId,
          invitationPayload,
        );
        if (!mounted) return;
        _showSuccessDialog(t.addMembersSentClub(email), context);
        _emailController.clear();
      } on ApiException catch (e) {
        if (!mounted) return;
        _showSnackBar(e.message);
      } catch (_) {
        if (!mounted) return;
        _showSnackBar(t.addMembersErrSend);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    } else {
      // Team-level invitation
      String? effectiveTeamId = _selectedTeamId;
      if (effectiveTeamId == null || effectiveTeamId.isEmpty) {
        _showSnackBar(t.addMembersTeamReq);
        return;
      }
      final selectedTeams = teamState.availableTeams
          .where((t) => t.id == effectiveTeamId)
          .toList();
      if (selectedTeams.isEmpty || (selectedTeams.first.clubId ?? '').isEmpty) {
        _showSnackBar(t.addMembersErrClubTeam);
        return;
      }

      setState(() => _isSending = true);
      try {
        await _invitationService.createTeamInvitation(
          selectedTeams.first.clubId!,
          effectiveTeamId,
          invitationPayload,
        );
        if (!mounted) return;
        _showSuccessDialog(
          t.addMembersSentTeam(email, _formatRole(effectiveRole, context)),
          context
        );
        _emailController.clear();
      } on ApiException catch (e) {
        if (!mounted) return;
        _showSnackBar(e.message);
      } catch (_) {
        if (!mounted) return;
        _showSnackBar(t.addMembersErrSend);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog(String message, BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1B3A2D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                  fontFamily: 'SFPro',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AnimatedButton.primary(
                child: ResponsivePrimaryButton(
                  context: ctx,
                  label: t.ok,
                  onPressed: () => Navigator.pop(ctx),
                ),
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

  String _formatPosition(String pos, BuildContext context) {
    final t = AppLocalizations.of(context);
    switch (pos) {
      case 'Point Guard': return t.posPG;
      case 'Shooting Guard': return t.posSG;
      case 'Small Forward': return t.posSF;
      case 'Power Forward': return t.posPF;
      case 'Center': return t.posC;
      default: return pos;
    }
  }

  String _roleKey(String role) =>
      role.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
}
