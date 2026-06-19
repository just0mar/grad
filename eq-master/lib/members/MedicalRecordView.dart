import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/animated_button.dart';
import '../core/app_transitions.dart';
import '../core/responsive_system.dart';
import '../models/api_models.dart';
import '../team/team_bloc.dart';
import 'MemberModel.dart';
import 'MedicalRecordDetailView.dart';
import 'medical_bloc.dart';

class MedicalRecordView extends StatelessWidget {
  final Member member;
  final int memberIndex;
  final String? clubId;
  final String? teamId;
  final String? playerUserId;

  const MedicalRecordView({
    super.key,
    required this.member,
    required this.memberIndex,
    this.clubId,
    this.teamId,
    this.playerUserId,
  });

  @override
  Widget build(BuildContext context) {
    final teamState = context.read<TeamBloc>().state;
    final selected = teamState.availableTeams
        .where((team) => team.id == teamState.selectedTeamId)
        .toList();
    final resolvedClubId =
        clubId ?? (selected.isEmpty ? null : selected.first.clubId);
    final resolvedTeamId = teamId ?? teamState.selectedTeamId;
    final resolvedPlayerId = playerUserId ?? member.userId;

    return BlocProvider(
      create: (_) {
        final bloc = MedicalBloc();
        if ((resolvedClubId ?? '').isNotEmpty &&
            resolvedTeamId.isNotEmpty &&
            resolvedPlayerId.isNotEmpty) {
          bloc.add(
            LoadMedicalRecords(
              clubId: resolvedClubId!,
              teamId: resolvedTeamId,
              playerUserId: resolvedPlayerId,
            ),
          );
        }
        return bloc;
      },
      child: _MedicalRecordContent(member: member),
    );
  }
}

class _MedicalRecordContent extends StatelessWidget {
  final Member member;

  const _MedicalRecordContent({required this.member});

  void _syncTeamMemberInjuryState(
    BuildContext context,
    MedicalState medicalState,
  ) {
    final playerUserId = medicalState.playerUserId;
    if (playerUserId == null || playerUserId.isEmpty) return;

    final teamBloc = context.read<TeamBloc>();
    final teamState = teamBloc.state;
    final index = teamState.members.indexWhere(
      (member) => member.userId == playerUserId,
    );
    if (index < 0) return;

    final currentMember = teamState.members[index];
    final activeInjuries = medicalState.records.where(
      (record) => !record.isClearedToPlay,
    );
    final hasActiveInjury = activeInjuries.isNotEmpty;
    final injuryType = hasActiveInjury
        ? activeInjuries.first.injuryType?.trim() ?? ''
        : '';

    if (currentMember.injuryFlag == hasActiveInjury &&
        currentMember.injuryType == injuryType) {
      return;
    }

    teamBloc.add(
      UpdateMemberData(
        index,
        currentMember.copyWith(
          injuryFlag: hasActiveInjury,
          injuryType: injuryType,
          medicalPdfUrl: hasActiveInjury ? currentMember.medicalPdfUrl : '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Medical Record',
        showTeamSwitcher: true,
      ),
      body: AppBackground(
        child: SafeArea(
          child: BlocConsumer<MedicalBloc, MedicalState>(
            listener: (context, state) {
              _syncTeamMemberInjuryState(context, state);
              if (state.error != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.error!)));
              }
            },
            builder: (context, state) {
              return RefreshIndicator(
                onRefresh: () async {
                  final clubId = state.clubId;
                  final teamId = state.teamId;
                  final playerUserId = state.playerUserId;
                  if (clubId != null &&
                      teamId != null &&
                      playerUserId != null) {
                    context.read<MedicalBloc>().add(
                      LoadMedicalRecords(
                        clubId: clubId,
                        teamId: teamId,
                        playerUserId: playerUserId,
                      ),
                    );
                  }
                },
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: ResponsiveSystem.pagePadding(context),
                  children: [
                    _memberCard(member, cardBg, textColor, subTextColor),
                    const SizedBox(height: 16),
                    AnimatedButton.primary(child: ElevatedButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : () => _showRecordDialog(context),
                      icon: const Icon(Icons.add),
                      label: Text(AppLocalizations.of(context).addRecord),
                    )),
                    const SizedBox(height: 16),
                    if (state.isLoading && state.records.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else if (state.records.isEmpty)
                      _emptyCard(cardBg, subTextColor)
                    else
                      ...state.records.map(
                        (record) => _recordCard(
                          context,
                          record,
                          cardBg,
                          textColor,
                          subTextColor,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _memberCard(
    Member member,
    Color cardBg,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundImage: AssetImage(member.image), radius: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'SFPro',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                member.role,
                style: TextStyle(color: subTextColor, fontFamily: 'SFPro'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(Color cardBg, Color subTextColor) {
    return Card(
      color: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No medical records yet.',
          style: TextStyle(color: subTextColor, fontFamily: 'SFPro'),
        ),
      ),
    );
  }

  Widget _recordCard(
    BuildContext context,
    MedicalRecordDto record,
    Color cardBg,
    Color textColor,
    Color subTextColor,
  ) {
    final state = context.read<MedicalBloc>().state;
    final uploadedDocs = record.documentRequests
        .where(_isUploadedDocument)
        .length;
    final pendingDocs = record.documentRequests
        .where((request) => !_isUploadedDocument(request))
        .length;
    final clearanceLocked = _clearanceLockExpired(record);
    final details = [
      if (record.diagnosis?.isNotEmpty == true) record.diagnosis!,
      if (record.recoveryTips?.isNotEmpty == true)
        'Recovery: ${record.recoveryTips}',
      if (uploadedDocs > 0)
        '$uploadedDocs uploaded document${uploadedDocs == 1 ? '' : 's'}',
      if (pendingDocs > 0)
        '$pendingDocs pending document request${pendingDocs == 1 ? '' : 's'}',
    ].join('\n');

    return Card(
      color: cardBg,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          final clubId = state.clubId;
          final teamId = state.teamId;
          final playerUserId = state.playerUserId;
          if (clubId == null || teamId == null || playerUserId == null) return;
          Navigator.push(
            context,
            AppPageRoute(
              child: MedicalRecordDetailView(
                clubId: clubId,
                teamId: teamId,
                playerUserId: playerUserId,
                record: record,
              ),
            ),
          ).then((_) {
            context.read<MedicalBloc>().add(
              LoadMedicalRecords(
                clubId: clubId,
                teamId: teamId,
                playerUserId: playerUserId,
              ),
            );
          });
        },
        title: Text(
          record.injuryType?.isNotEmpty == true
              ? record.injuryType!
              : 'Medical record',
          style: TextStyle(color: textColor, fontFamily: 'SFPro'),
        ),
        subtitle: Text(
          details.isEmpty ? 'Tap to view documents' : details,
          style: TextStyle(color: subTextColor, fontFamily: 'SFPro'),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: Icon(
                record.isClearedToPlay
                    ? Icons.verified
                    : Icons.local_hospital_rounded,
                color: clearanceLocked
                    ? subTextColor
                    : record.isClearedToPlay
                    ? Colors.green
                    : Colors.orange,
              ),
              onPressed: clearanceLocked
                  ? null
                  : () => context.read<MedicalBloc>().add(
                      UpdateClearance(
                        recordId: record.recordId,
                        cleared: !record.isClearedToPlay,
                      ),
                    ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: textColor),
              onPressed: () => _showRecordDialog(context, record: record),
            ),
            Icon(Icons.chevron_right, color: subTextColor),
          ],
        ),
      ),
    );
  }

  bool _isUploadedDocument(MedicalDocumentRequestDto request) {
    return request.downloadUrl != null ||
        (request.fileName != null && request.fileName!.isNotEmpty);
  }

  bool _clearanceLockExpired(MedicalRecordDto record) {
    if (!record.isClearedToPlay) return false;
    final clearedAt = record.updatedAt;
    if (clearedAt == null) return false;
    return DateTime.now().toUtc().isAfter(
      clearedAt.toUtc().add(const Duration(days: 14)),
    );
  }

  Future<void> _showRecordDialog(
    BuildContext context, {
    MedicalRecordDto? record,
  }) async {
    final injuryController = TextEditingController(
      text: record?.injuryType ?? '',
    );
    final diagnosisController = TextEditingController(
      text: record?.diagnosis ?? '',
    );
    final recoveryController = TextEditingController(
      text: record?.recoveryTips ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final dialogBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;

        return AlertDialog(
          backgroundColor: dialogBg,
          title: Text(
            record == null ? 'Add Record' : 'Edit Record',
            style: TextStyle(color: textColor, fontFamily: 'SFPro'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(injuryController, 'Injury type', textColor),
                const SizedBox(height: 12),
                _field(
                  diagnosisController,
                  'Diagnosis',
                  textColor,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _field(
                  recoveryController,
                  'Recovery tips',
                  textColor,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final bloc = context.read<MedicalBloc>();
                if (record == null) {
                  bloc.add(
                    CreateMedicalRecord(
                      injuryType: injuryController.text.trim(),
                      diagnosis: diagnosisController.text.trim(),
                      recoveryTips: recoveryController.text.trim(),
                    ),
                  );
                } else {
                  bloc.add(
                    UpdateMedicalRecord(
                      recordId: record.recordId,
                      injuryType: injuryController.text.trim(),
                      diagnosis: diagnosisController.text.trim(),
                      recoveryTips: recoveryController.text.trim(),
                    ),
                  );
                }
                Navigator.pop(dialogContext);
              },
              child: Text(record == null ? 'Create' : 'Save'),
            ),
          ],
        );
      },
    );

    injuryController.dispose();
    diagnosisController.dispose();
    recoveryController.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label,
    Color textColor, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: textColor, fontFamily: 'SFPro'),
      decoration: InputDecoration(labelText: label),
    );
  }
}
