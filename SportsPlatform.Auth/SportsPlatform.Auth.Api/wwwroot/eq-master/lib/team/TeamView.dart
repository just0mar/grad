import 'package:flutter_bloc/flutter_bloc.dart';
import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../chat/ChatView.dart';
import '../core/design_tokens.dart';
import '../members/MemberModel.dart';
import '../members/PlayerProfileView.dart';
import '../plans/PlansView.dart';
import '../profile/ProfileView.dart';
import '../services/api_client.dart';
import '../services/messaging_service.dart';
import '../session/session_bloc.dart';
import '../teamstats/TeamStatsView.dart';
import 'team_bloc.dart';
import 'package:flutter/material.dart';
import '../core/app_transitions.dart';
import '../core/animated_button.dart';
import '../core/app_localizations.dart';

class TeamView extends StatelessWidget {
  final String sport;
  final String teamName;
  final String userRole;

  const TeamView({
    super.key,
    required this.sport,
    required this.teamName,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return _TeamViewContent(
      sport: sport,
      teamName: teamName,
      userRole: userRole,
    );
  }
}

class _TeamViewContent extends StatefulWidget {
  final String sport;
  final String teamName;
  final String userRole;

  const _TeamViewContent({
    required this.sport,
    required this.teamName,
    required this.userRole,
  });

  @override
  State<_TeamViewContent> createState() => _TeamViewContentState();
}

class _TeamViewContentState extends State<_TeamViewContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isOpeningTeamChat = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final String activeRole = context.select((TeamBloc bloc) {
      if (bloc.state.userRoleInSelectedTeam.isNotEmpty) {
        return bloc.state.userRoleInSelectedTeam;
      }
      return widget.userRole;
    });

    return BlocListener<TeamBloc, TeamState>(
      listenWhen: (previous, current) =>
          previous.permissionError != current.permissionError ||
          previous.successMessage != current.successMessage,
      listener: (context, state) {
        final message = state.permissionError ?? state.successMessage;
        if (message == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        context.read<TeamBloc>().add(ClearTeamMessage());
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: CustomAppBar(
          title: AppLocalizations.of(context).teamTitle,
          plans: const [],
          showTeamSwitcher: true,
        ),
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tabBg,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: isDark
                        ? Colors.white60
                        : Colors.black,
                    labelStyle: const TextStyle(
                      fontFamily: 'SFPro',
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(fontFamily: 'SFPro'),
                    indicator: const BoxDecoration(),
                    tabs: [
                      Tab(icon: const Icon(Icons.group), text: AppLocalizations.of(context).teamMembers),
                      Tab(icon: const Icon(Icons.bar_chart), text: AppLocalizations.of(context).teamStats),
                      Tab(icon: const Icon(Icons.assignment), text: AppLocalizations.of(context).teamPlans),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMembersGrid(context, isDark, textColor),
                      TeamStats(
                        sport: widget.sport,
                        teamName: widget.teamName,
                        userRole: activeRole,
                      ),
                      const PlansView(),
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

  Future<void> _openMemberChat(
    BuildContext context,
    Member member,
    bool isDark,
  ) async {
    if (member.userId.isEmpty) return;
    final sessionState = context.read<SessionBloc>().state;
    final currentUser = sessionState.user;
    if (currentUser == null) return;

    final messagingService = MessagingService();
    try {
      final conversation = await messagingService.createConversation(
        participantIds: [member.userId],
      );
      if (!context.mounted) return;
      Navigator.push(
        context,
        AppPageRoute(
          child: ChatView(
            conversationId: conversation.conversationId,
            personName: member.name,
            personImage: member.profileImageUrl ?? member.image,
            currentUserId: currentUser.userId,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).teamErrorStartConversation)),
      );
    }
  }

  Future<void> _openTeamGroupChat(BuildContext context, TeamState state) async {
    final currentUser = context.read<SessionBloc>().state.user;
    if (currentUser == null) return;

    final participantIds = state.members
        .map((member) => member.userId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (!participantIds.contains(currentUser.userId)) {
      participantIds.add(currentUser.userId);
    }
    if (participantIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).teamAddAnotherMember)),
      );
      return;
    }

    final t = AppLocalizations.of(context);
    final chatName = '${state.selectedTeamName} ${t.teamChat}'.trim();
    setState(() => _isOpeningTeamChat = true);
    try {
      final messagingService = MessagingService();
      final conversations = await messagingService.getConversations();
      final participantSet = participantIds.toSet();
      final existing = conversations.where((conversation) {
        if (conversation.title != chatName) return false;
        final existingIds = conversation.participants
            .map((participant) => participant.userId)
            .toSet();
        return existingIds.length == participantSet.length &&
            existingIds.containsAll(participantSet);
      }).toList();

      final conversation = existing.isNotEmpty
          ? existing.first
          : await messagingService.createConversation(
              participantIds: participantIds,
              name: chatName,
              isGroup: true,
            );

      if (!context.mounted) return;
      final selectedTeams = state.availableTeams.where(
        (team) => team.id == state.selectedTeamId,
      );
      final selectedTeam = selectedTeams.isEmpty ? null : selectedTeams.first;
      Navigator.push(
        context,
        AppPageRoute(
          child: ChatView(
            conversationId: conversation.conversationId,
            personName: chatName.isEmpty ? AppLocalizations.of(context).teamChat : chatName,
            personImage:
                selectedTeam?.imageUrl ??
                selectedTeam?.clubLogoUrl ??
                'assets/profile.png',
            currentUserId: currentUser.userId,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).teamErrorStartConversation)),
      );
    } finally {
      if (mounted) setState(() => _isOpeningTeamChat = false);
    }
  }

  bool _isPlayerRole(String role) =>
      role.trim().replaceAll(' ', '').toLowerCase() == 'player';

  Future<void> _openMemberProfile(
    BuildContext context,
    TeamState state,
    Member member,
    int index,
  ) async {
    final currentUserId =
        context.read<SessionBloc>().state.user?.userId ?? state.currentUserId;
    if (member.userId == currentUserId) {
      if (_isPlayerRole(state.userRoleInSelectedTeam)) {
        await Navigator.push(
          context,
          AppPageRoute(
            child: PlayerProfileView(member: member, memberIndex: index),
          ),
        );
      } else {
        await Navigator.push(
          context,
          AppPageRoute(child: const ProfileView(plans: [])),
        );
      }
      if (context.mounted) {
        context.read<TeamBloc>().add(
          LoadTeamMembers(activeTeamId: state.selectedTeamId),
        );
      }
      return;
    }

    final memberIsPlayer = _isPlayerRole(member.role);
    if (memberIsPlayer) {
      final viewerIsPlayer = _isPlayerRole(state.userRoleInSelectedTeam);
      await Navigator.push(
        context,
        AppPageRoute(
          child: PlayerProfileView(
            member: member,
            memberIndex: index,
            showOnlyThroughFitToPlay: viewerIsPlayer,
          ),
        ),
      );
      if (context.mounted) {
        context.read<TeamBloc>().add(
          LoadTeamMembers(activeTeamId: state.selectedTeamId),
        );
      }
      return;
    }

    await Navigator.push(
      context,
      AppPageRoute(
        child: ProfileView(plans: const [], viewedMember: member),
      ),
    );
    if (context.mounted) {
      context.read<TeamBloc>().add(
        LoadTeamMembers(activeTeamId: state.selectedTeamId),
      );
    }
  }

  Widget _buildTeamMenu(
    BuildContext context,
    TeamState state,
    Color textColor,
  ) {
    final selectedTeams = state.availableTeams.where(
      (team) => team.id == state.selectedTeamId,
    );
    final selectedTeam = selectedTeams.isEmpty ? null : selectedTeams.first;
    if (selectedTeam?.clubId == null) return const SizedBox.shrink();

    final managerCount = state.members
        .where(
          (member) =>
              member.role.trim() == 'TeamManager' ||
              member.role.trim() == 'ClubManager',
        )
        .length;
    final currentRole = state.userRoleInSelectedTeam.trim();
    final isSoleManager =
        (currentRole == 'TeamManager' || currentRole == 'ClubManager') &&
        managerCount <= 1;
    if (isSoleManager) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: textColor),
      onSelected: (value) {
        if (value == 'leave') {
          _showLeaveTeamDialog(context, selectedTeam!);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'leave', child: Text(AppLocalizations.of(context).teamLeaveTeam)),
      ],
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
          AppLocalizations.of(context).teamLeaveTeamPrompt,
          style: TextStyle(color: textColor, fontFamily: 'SFPro'),
        ),
        content: Text(
          AppLocalizations.of(context).teamLeaveTeamDesc(teamName),
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
            child: Text(AppLocalizations.of(context).teamLeaveTeam, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersGrid(BuildContext context, bool isDark, Color textColor) {
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    const int memberColumns = 2;

    return BlocBuilder<TeamBloc, TeamState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.members.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                AppLocalizations.of(context).teamNoMembers,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'SFPro',
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            if (state.members.where((m) => m.isInjured).isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).teamInjuredPlayers(state.members.where((m) => m.isInjured).length),
                        style: const TextStyle(
                          color: Colors.red,
                          fontFamily: 'SFPro',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: memberColumns,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final member = state.members[index];
                  final currentUserId =
                      context.read<SessionBloc>().state.user?.userId ??
                      state.currentUserId;
                  final isOwnMember = member.userId == currentUserId;
                  return StaggeredListItem(
                    index: index,
                    child: AnimatedPressable(
                    onTap: () =>
                        _openMemberProfile(context, state, member, index),
                    child: Card(
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                14,
                                10,
                                12,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final resolvedImage =
                                            ApiClient.resolveUrl(
                                              member.profileImageUrl,
                                            );
                                        return Hero(
                                          tag: 'member-avatar-${member.userId}',
                                          child: CircleAvatar(
                                            backgroundImage: resolvedImage != null
                                                ? NetworkImage(resolvedImage)
                                                      as ImageProvider
                                                : null,
                                            radius: 30,
                                            backgroundColor: isDark
                                                ? Colors.white12
                                                : Colors.grey.shade200,
                                            child: resolvedImage == null
                                                ? Icon(
                                                    Icons.person,
                                                    size: 30,
                                                    color: isDark
                                                        ? Colors.white54
                                                        : Colors.grey,
                                                  )
                                                : null,
                                          ),
                                        );
                                      },
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
                                          color: textColor,
                                          fontFamily: 'SFPro',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: double.infinity,
                                      child: Text(
                                        member.role,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey,
                                          fontFamily: 'SFPro',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (!isOwnMember) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      SizedBox(
                                        height: 34,
                                        child: AnimatedButton.primary(
                                          child: ElevatedButton.icon(
                                          onPressed: () => _openMemberChat(
                                            context,
                                            member,
                                            isDark,
                                          ),
                                          icon: const Icon(
                                            Icons.message_rounded,
                                            size: 14,
                                          ),
                                          label: Text(
                                            AppLocalizations.of(context).teamMessageBtn,
                                            style: const TextStyle(
                                              fontFamily: 'SFPro',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(106, 34),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                          ),
                                        )),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (member.isInjured)
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
                                      color: Colors.black.withValues(
                                        alpha: 0.18,
                                      ),
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
                        ],
                      ),
                    ),
                  ));
                }, childCount: state.members.length),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  12,
                  AppSpacing.sm,
                  24,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: AnimatedButton.primary(
                    child: ElevatedButton.icon(
                    onPressed: _isOpeningTeamChat
                        ? null
                        : () => _openTeamGroupChat(context, state),
                    icon: Icon(
                      _isOpeningTeamChat
                          ? Icons.hourglass_top
                          : Icons.message_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _isOpeningTeamChat ? AppLocalizations.of(context).teamOpening : AppLocalizations.of(context).teamMessageTeamBtn,
                      style: const TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  )),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
