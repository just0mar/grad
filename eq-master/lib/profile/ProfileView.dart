import 'package:flutter/foundation.dart';
import '../core/cached_image_widget.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/responsive_system.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../members/MemberModel.dart';
import '../services/api_client.dart';
import '../services/team_service.dart';
import '../services/user_service.dart';
import '../session/session_bloc.dart';
import '../team/team_bloc.dart';
import '../core/animated_button.dart';
import '../core/target_navigator.dart';
import '../core/app_localizations.dart';

class ProfileView extends StatefulWidget {
  final List<Map<String, dynamic>> plans;
  final Member? viewedMember;

  const ProfileView({super.key, required this.plans, this.viewedMember});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> with TickerProviderStateMixin, SmoothKeyboardMixin {
  bool _editing = false;
  bool _saving = false;
  PlatformFile? _pickedImage;
  Future<Set<String>>? _commonTeamIdsFuture;
  String _commonTeamIdsKey = '';

  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _expCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _expCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  void _enterEdit() {
    final user = context.read<SessionBloc>().state.user;
    _nameCtrl.text = user?.name ?? '';
    _usernameCtrl.text = user?.username ?? '';
    _bioCtrl.text = user?.bio ?? '';
    _expCtrl.text = user?.yearsOfExperience?.toString() ?? '';
    _pickedImage = null;
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _pickedImage = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final svc = UserService();
      String? newImgUrl;
      if (_pickedImage != null) {
        newImgUrl = await svc.uploadProfileImage(_pickedImage!);
      }
      final expText = _expCtrl.text.trim();
      final expVal = expText.isEmpty ? null : int.tryParse(expText);
      final nameText = _nameCtrl.text.trim();
      final finalName = nameText.isEmpty ? 'Mystery Athlete' : nameText;

      // Username is optional: when left blank, send null so the field is
      // simply omitted from the update (an empty string would be rejected by
      // the server's username rules).
      final usernameText = _usernameCtrl.text.trim();
      final updated = await svc.updateProfile(
        name: finalName,
        username: usernameText.isEmpty ? null : usernameText,
        bio: _bioCtrl.text.trim(),
        yearsOfExperience: expVal,
      );
      
      final finalUser = newImgUrl != null
          ? updated.copyWith(profileImageUrl: newImgUrl)
          : updated;

      if (mounted) {
        if (nameText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name cannot be empty! We gave you a cool fallback name.'),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
        context.read<SessionBloc>().add(SessionUserUpdated(finalUser));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).profileUpdated)),
        );
        setState(() => _editing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorText(
                e,
                fallback: AppLocalizations.of(context).profileUpdateFailed,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() => _pickedImage = file);
  }

  void _ensureCommonTeams(TeamState teamState) {
    final viewedMember = widget.viewedMember;
    if (viewedMember == null) return;

    final idsKey = teamState.availableTeams.map((t) => t.id).join(',');
    final key = '${viewedMember.userId}:$idsKey';
    if (key == _commonTeamIdsKey) return;

    _commonTeamIdsKey = key;
    _commonTeamIdsFuture = _loadCommonTeamIds(teamState, viewedMember.userId);
  }

  Future<Set<String>> _loadCommonTeamIds(
    TeamState teamState,
    String viewedUserId,
  ) async {
    final teamService = TeamService();
    final commonTeamIds = <String>{};

    for (final team in teamState.availableTeams) {
      final clubId = team.clubId;
      if (clubId == null || clubId.isEmpty || team.id.isEmpty) continue;

      final cachedMembers = teamState.membersByTeamId[team.id];
      if (cachedMembers != null) {
        if (cachedMembers.any((member) => member.userId == viewedUserId)) {
          commonTeamIds.add(team.id);
        }
        continue;
      }

      try {
        final members = await teamService.getTeamMembers(clubId, team.id);
        if (members.any((member) => member.userId == viewedUserId)) {
          commonTeamIds.add(team.id);
        }
      } catch (_) {}
    }

    if (commonTeamIds.isEmpty && teamState.selectedTeamId.isNotEmpty) {
      commonTeamIds.add(teamState.selectedTeamId);
    }

    return commonTeamIds;
  }

  @override
  Widget build(BuildContext context) {
    updateKeyboardHeight(MediaQuery.viewInsetsOf(context).bottom);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.white54 : Colors.grey;
    final screenW = MediaQuery.of(context).size.width;
    final hPad = ResponsiveSystem.horizontalPadding(context);

    final isViewingMember = widget.viewedMember != null;
    final viewedMember = widget.viewedMember;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: CustomAppBar(
        title: isViewingMember ? viewedMember!.name : AppLocalizations.of(context).profileTitle,
        plans: widget.plans,
      ),
      body: BlocBuilder<TeamBloc, TeamState>(
        builder: (context, teamState) {
          _ensureCommonTeams(teamState);
          final session = context.watch<SessionBloc>().state;
          final user = session.user;
          final t = AppLocalizations.of(context);
          final displayName = isViewingMember
              ? (viewedMember!.name.isNotEmpty
                    ? viewedMember.name
                    : viewedMember.email)
              : (user?.name.isNotEmpty == true
                    ? user!.name
                    : user?.email ?? t.profileUser);
          final displayEmail = isViewingMember
              ? viewedMember!.email
              : user?.email ?? '';
          final displayUsername = isViewingMember ? null : user?.username;
          final displayBio = isViewingMember
              ? t.profileNoBio
              : (user?.bio?.isNotEmpty == true ? user!.bio! : t.profileNoBio);
          final resolvedImg = ApiClient.resolveUrl(
            isViewingMember
                ? viewedMember!.profileImageUrl
                : user?.profileImageUrl,
          );
          final activeRole = isViewingMember
              ? viewedMember!.role
              : (teamState.userRoleInSelectedTeam.isNotEmpty
                    ? teamState.userRoleInSelectedTeam
                    : session.currentRole ?? t.profileNA);

          String ageStr = t.profileNA;
          if (!isViewingMember && user?.dob != null && user!.dob!.isNotEmpty) {
            try {
              final dob = DateTime.parse(user.dob!);
              final now = DateTime.now();
              int age = now.year - dob.year;
              if (now.month < dob.month ||
                  (now.month == dob.month && now.day < dob.day)) {
                age--;
              }
              ageStr = '$age ${t.profileYrs}';
            } catch (_) {}
          }

          final expStr = !isViewingMember && user?.yearsOfExperience != null
              ? '${user!.yearsOfExperience} ${t.profileYrs}'
              : t.profileNA;
          final idStr = isViewingMember
              ? viewedMember!.userId
              : user?.userId ?? t.profileNA;
          final shortId = idStr.length > 8
              ? idStr.substring(idStr.length - 8)
              : idStr;

            // Resolve profile image for display
            ImageProvider? profileImage;
            if (_editing && _pickedImage != null) {
              profileImage = kIsWeb 
                  ? MemoryImage(_pickedImage!.bytes!) as ImageProvider
                  : FileImage(File(_pickedImage!.path!));
            } else if (resolvedImg != null) {
              profileImage = NetworkImage(resolvedImg);
            }

          return buildKeyboardDismissible(
            child: AppBackground(
              child: SafeArea(
                child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  0,
                  hPad,
                  16 + smoothKeyboardHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══════════════════════════════
                    // PROFILE CARD — Rounded card
                    // ═══════════════════════════════
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar with optional camera badge
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  profileImage != null
                                      ? CircleAvatar(
                                          radius: 45,
                                          backgroundImage: profileImage,
                                        )
                                      : CircleAvatar(
                                          radius: 45,
                                          backgroundColor: isDark
                                              ? const Color(0xFF2E7D52)
                                              : const Color(0xFFE0E0E0),
                                          child: Icon(
                                            Icons.person,
                                            size: 45,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                  if (_editing && !isViewingMember)
                                    PositionedDirectional(
                                      bottom: 0,
                                      end: 0,
                                      child: GestureDetector(
                                        onTap: _pickImage,
                                        child: Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              // Card text content
                              Expanded(
                                child: _editing && !isViewingMember
                                    ? _buildEditCardContent(
                                        isDark,
                                        textColor,
                                        subtextColor,
                                      )
                                    : _buildViewCardContent(
                                        displayName,
                                        displayUsername,
                                        displayEmail,
                                        displayBio,
                                        isDark,
                                        textColor,
                                        subtextColor,
                                      ),
                              ),
                              const SizedBox(width: 32),
                            ],
                          ),
                        ),
                        // Edit / X icon at top-right corner
                        if (!isViewingMember)
                          PositionedDirectional(
                            top: 12,
                            end: 12,
                            child: GestureDetector(
                              onTap: _editing ? _cancelEdit : _enterEdit,
                              child: Icon(
                                _editing ? Icons.close : Icons.edit_outlined,
                                size: 18,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFFAAAAAA),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ═══════════════════════════════
                    // INFO CARD
                    // ═══════════════════════════════
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            title: t.profileRole,
                            value: activeRole,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 14),
                          _InfoRow(title: t.profileId, value: shortId, isDark: isDark),
                          const SizedBox(height: 14),
                          _InfoRow(title: t.profileAge, value: ageStr, isDark: isDark),
                          const SizedBox(height: 14),
                          _buildExpRow(isDark, expStr, textColor, subtextColor, t),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ═══════════════════════════════
                    // TEAMS HEADER
                    // ═══════════════════════════════
                    Text(
                      t.profileUserTeams(displayName),
                      style: TextStyle(
                        fontFamily: 'Facon',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ═══════════════════════════════
                    // TEAM CARDS
                    // ═══════════════════════════════
                    _buildTeamsSection(
                      context: context,
                      teamState: teamState,
                      screenW: screenW,
                      hPad: hPad,
                      isDark: isDark,
                      subtextColor: subtextColor,
                    ),
                    const SizedBox(height: 28),

                    // ═══════════════════════════════
                    // ACTION BUTTONS — edit mode only
                    // ═══════════════════════════════
                    if (_editing) ...[
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedButton.primary(
                              child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: _saving ? null : _save,
                              child: Text(
                                _saving ? AppLocalizations.of(context).profileSaving : AppLocalizations.of(context).profileSaveChanges,
                                style: const TextStyle(
                                  fontFamily: 'SFPro',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? const Color(0xFFEF5350)
                                    : const Color(0xFFD32F2F),
                                side: BorderSide(
                                  color: isDark
                                      ? const Color(0xFFEF5350)
                                      : const Color(0xFFD32F2F),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: _cancelEdit,
                              child: Text(
                                AppLocalizations.of(context).cancel,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFEF5350)
                                      : const Color(0xFFD32F2F),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (!_editing) const SizedBox(height: 24),
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

  // ── View mode card content ──
  Widget _buildTeamsSection({
    required BuildContext context,
    required TeamState teamState,
    required double screenW,
    required double hPad,
    required bool isDark,
    required Color subtextColor,
  }) {
    final t = AppLocalizations.of(context);
    Widget buildCards(List<dynamic> teams) {
      if (teams.isEmpty) {
        return Text(
          widget.viewedMember == null ? t.profileNoTeams : t.profileNoCommonTeams,
          style: TextStyle(fontFamily: 'SFPro', color: subtextColor),
        );
      }

      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: teams.map((team) {
          final teamImgUrl = ApiClient.resolveUrl(team.imageUrl);
          final clubImgUrl = ApiClient.resolveUrl(team.clubLogoUrl);
          final imgUrl = teamImgUrl ?? clubImgUrl;

          return SizedBox(
            width: (screenW - hPad * 2 - 12) / 2,
            child: _TeamCard(
              teamName: team.club,
              categoryName: team.category,
              imageUrl: imgUrl,
              isDark: isDark,
              showDismiss: widget.viewedMember == null && _editing,
              onTap: () => _openTeam(context, team),
              onDismiss: () {
                if (widget.viewedMember != null ||
                    team.clubId == null ||
                    team.clubId!.isEmpty) {
                  return;
                }
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(t.teamLeaveTeam),
                    content: Text(t.teamLeaveTeamDesc(team.club)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(t.cancel),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.read<TeamBloc>().add(
                            LeaveTeam(clubId: team.clubId!, teamId: team.id),
                          );
                        },
                        child: Text(
                          t.teamLeaveTeam,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }).toList(),
      );
    }

    if (widget.viewedMember == null) {
      return buildCards(teamState.availableTeams);
    }

    return FutureBuilder<Set<String>>(
      future: _commonTeamIdsFuture,
      builder: (context, snapshot) {
        final commonIds = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting &&
            commonIds == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final teams = teamState.availableTeams
            .where((team) => commonIds?.contains(team.id) ?? false)
            .toList();
        return buildCards(teams);
      },
    );
  }

  void _openTeam(BuildContext context, dynamic team) {
    if (team.id == null || team.id.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    context.read<TeamBloc>().add(SwitchTeamContext(team.id));
    // Switch to the Team tab (index 2) via the static callback registered
    // by MainNavigation — same pattern as HomeFocus.requestHome.
    HomeFocus.requestTeam?.call();
  }

  Widget _buildViewCardContent(
    String name,
    String? username,
    String email,
    String bio,
    bool isDark,
    Color textColor,
    Color subtextColor,
  ) {
    final nameColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final emailColor = isDark ? Colors.white54 : const Color(0xFF888888);
    final bioColor = isDark ? Colors.white70 : const Color(0xFF444444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        Text(
          name,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontFamily: 'SFPro',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: nameColor,
          ),
        ),
        const SizedBox(height: 4),
        // Username (if set)
        if (username != null && username.isNotEmpty) ...[
          Text(
            '@$username',
            style: TextStyle(
              fontFamily: 'SFPro',
              fontSize: 13,
              color: isDark
                  ? Colors.greenAccent.shade200
                  : const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 3),
        ],
        // Email
        Text(
          email,
          style: TextStyle(
            fontFamily: 'SFPro',
            fontSize: 13,
            color: emailColor,
          ),
        ),
        const SizedBox(height: 14),
        // Bio — italic, capped so it never stretches the fixed card
        Text(
          '\u201C$bio\u201D',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'SFPro',
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: bioColor,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Edit mode card content ──
  Widget _buildEditCardContent(
    bool isDark,
    Color textColor,
    Color subtextColor,
  ) {
    final t = AppLocalizations.of(context);
    final fieldColor = isDark ? const Color(0xFF0D2A1C) : Colors.white;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _editField(
          _nameCtrl,
          t.profileName,
          fieldColor,
          textColor,
          labelColor,
          borderColor,
        ),
        const SizedBox(height: 10),
        _editField(
          _usernameCtrl,
          t.profileUsername,
          fieldColor,
          textColor,
          labelColor,
          borderColor,
          hint: t.profileUsernameHint,
        ),
        const SizedBox(height: 10),
        _editField(
          _bioCtrl,
          t.profileBioLabel,
          fieldColor,
          textColor,
          labelColor,
          borderColor,
          hint: t.profileBioHint,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _editField(
    TextEditingController ctrl,
    String label,
    Color fill,
    Color text,
    Color lbl,
    Color border, {
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      style: TextStyle(fontFamily: 'SFPro', color: text, fontSize: 14),
      maxLines: maxLines,
      decoration: InputDecoration(
        filled: true,
        fillColor: fill,
        labelText: label,
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: TextStyle(
          fontFamily: 'SFPro',
          color: lbl.withValues(alpha: 0.5),
        ),
        labelStyle: TextStyle(fontFamily: 'SFPro', color: lbl),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: border),
        ),
      ),
    );
  }

  // ── Experience row — editable inline when editing ──
  Widget _buildExpRow(
    bool isDark,
    String expStr,
    Color textColor,
    Color subtextColor,
    AppLocalizations t,
  ) {
    if (!_editing) {
      return _InfoRow(
        title: t.profileExp,
        value: expStr,
        isDark: isDark,
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          t.profileExp,
          style: TextStyle(
            fontFamily: 'SFPro',
            color: isDark ? Colors.white54 : Colors.grey,
          ),
        ),
        SizedBox(
          width: 70,
          child: TextFormField(
            controller: _expCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontWeight: FontWeight.w600,
              color: textColor,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isDark;
  const _InfoRow({
    required this.title,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'SFPro',
            color: isDark ? Colors.white54 : Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'SFPro',
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  final String teamName;
  final String categoryName;
  final String? imageUrl;
  final bool isDark;
  final bool showDismiss;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _TeamCard({
    required this.teamName,
    required this.categoryName,
    required this.imageUrl,
    required this.isDark,
    this.showDismiss = false,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedButton(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isDark ? const Color(0xFF1B4D3E) : const Color(0xFFE8F5E9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  children: [
                    Container(
                      height: 85,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: imageUrl != null
                            ? CachedImageWidget(
                                imageUrl: imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: const Icon(
                                  Icons.sports_basketball,
                                  color: Colors.green,
                                  size: 36,
                                ),
                              )
                            : const Icon(
                                Icons.sports_basketball,
                                color: Colors.green,
                                size: 36,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      teamName,
                      style: TextStyle(
                        fontFamily: 'Facon',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (showDismiss)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
