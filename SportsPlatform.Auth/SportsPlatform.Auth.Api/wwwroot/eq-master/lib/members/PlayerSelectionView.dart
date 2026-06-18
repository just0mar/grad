import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/responsive_system.dart';
import '../core/app_transitions.dart';
import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/medical_service.dart';
import '../services/player_service.dart';
import '../team/team_bloc.dart';
import 'PlayerProfileView.dart';
import 'MemberModel.dart';

class PlayerSelectionView extends StatefulWidget {
  final String userRole;
  final String actionType;

  const PlayerSelectionView({
    super.key,
    required this.userRole,
    required this.actionType,
  });

  @override
  State<PlayerSelectionView> createState() => _PlayerSelectionViewState();
}

class _PlayerSelectionViewState extends State<PlayerSelectionView> {
  final MedicalService _medicalService = MedicalService();
  final PlayerService _playerService = PlayerService();
  final Map<String, Future<_MedicalPlayerCardInfo>> _medicalInfoFutures = {};

  String get _title {
    switch (widget.actionType) {
      case 'medical':
        return 'Injured Players';
      default:
        return 'Select Player';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<TeamBloc, TeamState>(
      builder: (context, state) {
        final members = state.members.where((member) {
          final isPlayer = member.role.trim() == 'Player';
          if (widget.actionType == 'medical') {
            return isPlayer && member.isInjured;
          }
          return isPlayer;
        }).toList();

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: CustomAppBar(title: _title, showTeamSwitcher: true),
          body: AppBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
              child: members.isEmpty
                  ? Center(
                      child: Text(
                        widget.actionType == 'medical'
                            ? 'No injured players.'
                            : 'No players added yet.',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: ResponsiveSystem.pagePadding(context),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final originalIndex = state.members.indexOf(member);
                        final selectedTeams = state.availableTeams
                            .where((team) => team.id == state.selectedTeamId)
                            .toList();
                        final clubId = selectedTeams.isEmpty
                            ? null
                            : selectedTeams.first.clubId;
                        return _buildMemberTile(
                          context,
                          member,
                          originalIndex,
                          isDark,
                          clubId,
                          state.selectedTeamId,
                        );
                      },
                    ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    Member member,
    int index,
    bool isDark,
    String? clubId,
    String teamId,
  ) {
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    final medicalInfo =
        widget.actionType == 'medical' &&
            clubId != null &&
            clubId.isNotEmpty &&
            teamId.isNotEmpty &&
            member.userId.isNotEmpty
        ? _medicalInfoFuture(clubId, teamId, member)
        : null;

    return AnimatedPressable(
      onTap: () => _navigate(context, member, index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: FutureBuilder<_MedicalPlayerCardInfo>(
        future: medicalInfo,
        builder: (context, snapshot) {
          final info = snapshot.data;
          final profileImage =
              _buildImageProvider(info?.profileImageUrl) ??
              _buildImageProvider(member.profileImageUrl) ??
              _buildImageProvider(member.image);
          final isChecking =
              medicalInfo != null &&
              snapshot.connectionState == ConnectionState.waiting;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: _buildAvatar(profileImage, isDark),
            title: Text(
              member.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveSystem.bodyFontSize(context) + 1,
                color: textColor,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    member.role,
                    style: TextStyle(
                      fontSize: ResponsiveSystem.bodyFontSize(context) - 1,
                      color: subTextColor,
                    ),
                  ),
                  if (isChecking)
                    _buildStatusFlag(
                      label: 'Checking',
                      icon: Icons.hourglass_top,
                      color: isDark ? Colors.white54 : Colors.black45,
                    )
                  else if (info?.injuryTitle != null)
                    _buildStatusFlag(
                      label: info!.injuryTitle!,
                      icon: Icons.local_hospital_rounded,
                      color: Colors.red,
                    ),
                ],
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          );
        },
      ),
    ),
    );
  }

  ImageProvider? _buildImageProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path == 'assets/profile.png') return null;
    if (path.startsWith('assets/')) return AssetImage(path);
    final resolved = ApiClient.resolveUrl(path);
    return resolved != null ? NetworkImage(resolved) : null;
  }

  Widget _buildAvatar(ImageProvider? image, bool isDark) {
    final bgColor = isDark ? const Color(0xFF0D2A1C) : const Color(0xFFE8E8E8);
    final iconColor = isDark ? Colors.white54 : Colors.black45;

    if (image == null) {
      return CircleAvatar(
        backgroundColor: bgColor,
        radius: 24,
        child: Icon(Icons.person, color: iconColor, size: 24),
      );
    }

    return CircleAvatar(
      backgroundColor: bgColor,
      radius: 24,
      child: ClipOval(
        child: Image(
          image: image,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.person, color: iconColor, size: 24),
        ),
      ),
    );
  }

  Future<_MedicalPlayerCardInfo> _medicalInfoFuture(
    String clubId,
    String teamId,
    Member member,
  ) {
    final key = '$clubId|$teamId|${member.userId}';
    return _medicalInfoFutures.putIfAbsent(key, () async {
      List<MedicalRecordDto> records = const [];
      PlayerProfileDto? profile;

      try {
        records = await _medicalService.getPlayerMedical(
          clubId,
          teamId,
          member.userId,
        );
      } catch (_) {}

      try {
        profile = await _playerService.getPlayerProfile(
          clubId,
          teamId,
          member.userId,
        );
      } catch (_) {}

      String? injuryTitle;
      for (final record in records) {
        if (!record.isClearedToPlay) {
          final title = record.injuryType?.toString().trim();
          injuryTitle = title == null || title.isEmpty ? 'Injured' : title;
          break;
        }
      }
      return _MedicalPlayerCardInfo(
        profileImageUrl: profile?.profileImageUrl,
        injuryTitle: injuryTitle,
      );
    });
  }

  Widget _buildStatusFlag({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontFamily: 'SFPro',
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, Member member, int index) {
    if (widget.actionType == 'medical') {
      Navigator.push(
        context,
        AppPageRoute(
          child: PlayerProfileView(member: member, memberIndex: index),
        ),
      );
    }
  }
}

class _MedicalPlayerCardInfo {
  final String? profileImageUrl;
  final String? injuryTitle;

  const _MedicalPlayerCardInfo({this.profileImageUrl, this.injuryTitle});
}
