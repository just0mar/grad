import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../appbar/CustomAppBar.dart';
import '../core/app_background.dart';
import '../core/design_tokens.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/fitness_service.dart';
import '../services/medical_service.dart';
import '../services/player_service.dart';
import '../services/stats_service.dart';
import '../core/animated_button.dart';
import '../team/team_bloc.dart';
import 'MemberModel.dart';

class MemberDetailView extends StatefulWidget {
  final Member member;
  final int memberIndex;

  const MemberDetailView({
    super.key,
    required this.member,
    required this.memberIndex,
  });

  @override
  State<MemberDetailView> createState() => _MemberDetailViewState();
}

class _MemberDetailViewState extends State<MemberDetailView> with TickerProviderStateMixin, SmoothKeyboardMixin {
  final PlayerService _playerService = PlayerService();
  final FitnessService _fitnessService = FitnessService();
  final MedicalService _medicalService = MedicalService();
  final StatsService _statsService = StatsService();

  Future<_PlayerBundle>? _bundleFuture;
  String _bundleKey = '';
  bool _isMedicalSaving = false;
  bool _isFitnessSaving = false;

  void _ensureBundle(TeamState state, Member member) {
    final selectedTeams = state.availableTeams
        .where((t) => t.id == state.selectedTeamId)
        .toList();
    final clubId = selectedTeams.isEmpty ? null : selectedTeams.first.clubId;
    final key = '${clubId ?? ''}:${state.selectedTeamId}:${member.userId}';
    if (key == _bundleKey) return;
    _bundleKey = key;
    if ((clubId ?? '').isEmpty ||
        state.selectedTeamId.isEmpty ||
        member.userId.isEmpty) {
      _bundleFuture = Future.value(const _PlayerBundle());
      return;
    }
    _bundleFuture = _loadBundle(clubId!, state.selectedTeamId, member.userId);
  }

  Future<_PlayerBundle> _loadBundle(
    String clubId,
    String teamId,
    String userId,
  ) async {
    Future<PlayerProfileDto?> loadProfile() async {
      try {
        return await _playerService.getPlayerProfile(clubId, teamId, userId);
      } catch (_) {
        return null;
      }
    }

    Future<List<FitnessRecordDto>> loadFitness() async {
      try {
        return await _fitnessService.getPlayerFitness(clubId, teamId, userId);
      } catch (_) {
        return <FitnessRecordDto>[];
      }
    }

    Future<List<MedicalRecordDto>> loadMedical() async {
      try {
        return await _medicalService.getPlayerMedical(clubId, teamId, userId);
      } catch (_) {
        return <MedicalRecordDto>[];
      }
    }

    Future<Map<String, dynamic>> loadStats() async {
      try {
        final raw = await _statsService.getPlayerAggregate(
          clubId,
          teamId,
          userId,
        );
        return Map<String, dynamic>.from(raw as Map);
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    final results = await Future.wait<dynamic>([
      loadProfile(),
      loadFitness(),
      loadMedical(),
      loadStats(),
    ]);
    return _PlayerBundle(
      profile: results[0] as PlayerProfileDto?,
      fitness: List<FitnessRecordDto>.from(results[1] as List),
      medical: List<MedicalRecordDto>.from(results[2] as List),
      stats: Map<String, dynamic>.from(results[3] as Map),
    );
  }

  _MedicalContext? _medicalContext(TeamState state, Member member) {
    final selectedTeams = state.availableTeams
        .where((t) => t.id == state.selectedTeamId)
        .toList();
    final clubId = selectedTeams.isEmpty ? null : selectedTeams.first.clubId;
    if ((clubId ?? '').isEmpty ||
        state.selectedTeamId.isEmpty ||
        member.userId.isEmpty) {
      return null;
    }
    return _MedicalContext(
      clubId: clubId!,
      teamId: state.selectedTeamId,
      playerUserId: member.userId,
    );
  }

  Future<_PlayerBundle?> _reload(TeamState state, Member member) async {
    setState(() => _bundleKey = '');
    _ensureBundle(state, member);
    return await _bundleFuture;
  }

  void _syncMemberInjuryState(
    TeamState state,
    Member member,
    List<MedicalRecordDto> records,
  ) {
    final index = state.members.indexWhere((m) => m.userId == member.userId);
    if (index < 0) return;

    final activeInjuries = records.where((record) => !record.isClearedToPlay);
    final hasActiveInjury = activeInjuries.isNotEmpty;
    final injuryType = hasActiveInjury
        ? activeInjuries.first.injuryType?.trim() ?? ''
        : '';

    context.read<TeamBloc>().add(
      UpdateMemberData(
        index,
        member.copyWith(
          injuryFlag: hasActiveInjury,
          injuryType: injuryType,
          medicalPdfUrl: hasActiveInjury ? member.medicalPdfUrl : '',
        ),
      ),
    );
  }

  Future<void> _openMedicalRecordDialog({
    required TeamState state,
    required Member member,
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
    final returnDateController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: fieldColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                record == null ? 'New Medical Record' : 'Edit Medical Record',
                style: TextStyle(color: textColor, fontFamily: 'SFPro'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(
                      controller: injuryController,
                      label: 'Injury type',
                      textColor: textColor,
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      controller: diagnosisController,
                      label: 'Diagnosis',
                      textColor: textColor,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      controller: recoveryController,
                      label: 'Recovery tips',
                      textColor: textColor,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: returnDateController,
                      readOnly: true,
                      style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                      decoration: const InputDecoration(
                        labelText: 'Expected return date',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: DateTime.now().add(
                            const Duration(days: 7),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (picked == null) return;
                        setDialogState(() {
                          returnDateController.text =
                              '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      },
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
                  onPressed: _isMedicalSaving
                      ? null
                      : () async {
                          final saved = await _saveMedicalRecord(
                            state: state,
                            member: member,
                            record: record,
                            injuryType: injuryController.text.trim(),
                            diagnosis: diagnosisController.text.trim(),
                            recoveryTips: recoveryController.text.trim(),
                            expectedReturnDate: returnDateController.text
                                .trim(),
                          );
                          if (saved && mounted && dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: Text(record == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    injuryController.dispose();
    diagnosisController.dispose();
    recoveryController.dispose();
    returnDateController.dispose();
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required Color textColor,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: textColor, fontFamily: 'SFPro'),
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<bool> _saveMedicalRecord({
    required TeamState state,
    required Member member,
    required MedicalRecordDto? record,
    required String injuryType,
    required String diagnosis,
    required String recoveryTips,
    required String expectedReturnDate,
  }) async {
    final medicalContext = _medicalContext(state, member);
    if (medicalContext == null) {
      _showSnack('Select a team and player first.');
      return false;
    }
    setState(() => _isMedicalSaving = true);
    final body = {
      'recordDate': DateTime.now().toIso8601String(),
      'injuryType': injuryType,
      'diagnosis': diagnosis,
      'recoveryTips': recoveryTips,
      if (expectedReturnDate.isNotEmpty)
        'expectedReturnDate': expectedReturnDate,
    };
    try {
      if (record == null) {
        await _medicalService.createMedicalRecord(
          medicalContext.clubId,
          medicalContext.teamId,
          medicalContext.playerUserId,
          body,
        );
      } else {
        await _medicalService.updateMedicalRecord(
          medicalContext.clubId,
          medicalContext.teamId,
          record.recordId,
          body,
        );
      }
      final bundle = await _reload(state, member);
      if (bundle != null) {
        _syncMemberInjuryState(state, member, bundle.medical);
      }
      _showSnack(
        record == null ? 'Medical record created.' : 'Medical record updated.',
      );
      return true;
    } on ApiException catch (e) {
      _showSnack(e.message);
      return false;
    } catch (_) {
      _showSnack('Could not save medical record.');
      return false;
    } finally {
      if (mounted) setState(() => _isMedicalSaving = false);
    }
  }

  Future<void> _toggleClearance({
    required TeamState state,
    required Member member,
    required MedicalRecordDto record,
  }) async {
    if (_clearanceLockExpired(record)) {
      _showSnack(
        'This injury was cleared more than two weeks ago and cannot be marked not cleared.',
      );
      return;
    }
    final medicalContext = _medicalContext(state, member);
    if (medicalContext == null) {
      _showSnack('Select a team and player first.');
      return;
    }
    setState(() => _isMedicalSaving = true);
    try {
      await _medicalService.updateClearance(
        medicalContext.clubId,
        medicalContext.teamId,
        record.recordId,
        !record.isClearedToPlay,
      );
      final bundle = await _reload(state, member);
      if (bundle != null) {
        _syncMemberInjuryState(state, member, bundle.medical);
      }
      _showSnack(
        !record.isClearedToPlay
            ? 'Player marked as cleared.'
            : 'Player marked as not cleared.',
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Could not update clearance.');
    } finally {
      if (mounted) setState(() => _isMedicalSaving = false);
    }
  }

  bool _clearanceLockExpired(MedicalRecordDto record) {
    if (!record.isClearedToPlay) return false;
    final clearedAt = record.updatedAt;
    if (clearedAt == null) return false;
    return DateTime.now().toUtc().isAfter(
      clearedAt.toUtc().add(const Duration(days: 14)),
    );
  }

  Future<void> _openFitnessRecordDialog({
    required TeamState state,
    required Member member,
  }) async {
    final bmiController = TextEditingController();
    final bodyFatController = TextEditingController();
    final speedController = TextEditingController();
    final enduranceController = TextEditingController();
    final customNameController = TextEditingController();
    final customResultController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;
        return AlertDialog(
          backgroundColor: fieldColor,
          title: Text(
            'Add Fitness Record',
            style: TextStyle(color: textColor, fontFamily: 'SFPro'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  controller: bmiController,
                  label: 'BMI',
                  textColor: textColor,
                ),
                _dialogField(
                  controller: bodyFatController,
                  label: 'Body fat %',
                  textColor: textColor,
                ),
                _dialogField(
                  controller: speedController,
                  label: 'Speed test',
                  textColor: textColor,
                ),
                _dialogField(
                  controller: enduranceController,
                  label: 'Endurance score',
                  textColor: textColor,
                ),
                _dialogField(
                  controller: customNameController,
                  label: 'Custom test name',
                  textColor: textColor,
                ),
                _dialogField(
                  controller: customResultController,
                  label: 'Custom test result',
                  textColor: textColor,
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
              onPressed: _isFitnessSaving
                  ? null
                  : () async {
                      final saved = await _saveFitnessRecord(
                        state: state,
                        member: member,
                        bmi: bmiController.text.trim(),
                        bodyFat: bodyFatController.text.trim(),
                        speed: speedController.text.trim(),
                        endurance: enduranceController.text.trim(),
                        customName: customNameController.text.trim(),
                        customResult: customResultController.text.trim(),
                      );
                      if (saved && mounted && dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
              child: Text(AppLocalizations.of(context).create),
            ),
          ],
        );
      },
    );

    bmiController.dispose();
    bodyFatController.dispose();
    speedController.dispose();
    enduranceController.dispose();
    customNameController.dispose();
    customResultController.dispose();
  }

  Future<bool> _saveFitnessRecord({
    required TeamState state,
    required Member member,
    required String bmi,
    required String bodyFat,
    required String speed,
    required String endurance,
    required String customName,
    required String customResult,
  }) async {
    final contextInfo = _medicalContext(state, member);
    if (contextInfo == null) {
      _showSnack('Select a team and player first.');
      return false;
    }
    setState(() => _isFitnessSaving = true);
    try {
      await _fitnessService.createFitnessRecord(
        contextInfo.clubId,
        contextInfo.teamId,
        contextInfo.playerUserId,
        {
          'testDate': DateTime.now().toIso8601String(),
          if (double.tryParse(bmi) != null) 'bmi': double.parse(bmi),
          if (double.tryParse(bodyFat) != null)
            'bodyFatPct': double.parse(bodyFat),
          if (double.tryParse(speed) != null)
            'speedTestResult': double.parse(speed),
          if (double.tryParse(endurance) != null)
            'enduranceScore': double.parse(endurance),
          if (customName.isNotEmpty) 'customTestName': customName,
          if (double.tryParse(customResult) != null)
            'customTestResult': double.parse(customResult),
        },
      );
      await _reload(state, member);
      _showSnack('Fitness record created.');
      return true;
    } on ApiException catch (e) {
      _showSnack(e.message);
      return false;
    } catch (_) {
      _showSnack('Could not create fitness record.');
      return false;
    } finally {
      if (mounted) setState(() => _isFitnessSaving = false);
    }
  }

  Future<void> _openDocumentRequestDialog({
    required TeamState state,
    required Member member,
    required MedicalRecordDto record,
  }) async {
    final nameController = TextEditingController();
    final noteController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;
        return AlertDialog(
          backgroundColor: fieldColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Request Document',
            style: TextStyle(color: textColor, fontFamily: 'SFPro'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(
                controller: nameController,
                label: 'Document name',
                textColor: textColor,
              ),
              const SizedBox(height: 12),
              _dialogField(
                controller: noteController,
                label: 'Note to player',
                textColor: textColor,
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final requested = await _requestDocument(
                  state: state,
                  member: member,
                  record: record,
                  documentName: nameController.text.trim(),
                  note: noteController.text.trim(),
                );
                if (requested && mounted && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(AppLocalizations.of(context).request),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    noteController.dispose();
  }

  Future<bool> _requestDocument({
    required TeamState state,
    required Member member,
    required MedicalRecordDto record,
    required String documentName,
    required String note,
  }) async {
    if (documentName.isEmpty) {
      _showSnack('Enter the document name.');
      return false;
    }
    final medicalContext = _medicalContext(state, member);
    if (medicalContext == null) {
      _showSnack('Select a team and player first.');
      return false;
    }
    setState(() => _isMedicalSaving = true);
    try {
      await _medicalService.requestDocument(
        medicalContext.clubId,
        medicalContext.teamId,
        record.recordId,
        {'documentName': documentName, if (note.isNotEmpty) 'note': note},
      );
      await _reload(state, member);
      _showSnack('Document requested from player.');
      return true;
    } on ApiException catch (e) {
      _showSnack(e.message);
      return false;
    } catch (_) {
      _showSnack('Could not request document.');
      return false;
    } finally {
      if (mounted) setState(() => _isMedicalSaving = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    updateKeyboardHeight(MediaQuery.viewInsetsOf(context).bottom);
    return BlocBuilder<TeamBloc, TeamState>(
      builder: (context, state) {
        final currentMember = state.members.length > widget.memberIndex
            ? state.members[widget.memberIndex]
            : widget.member;
        _ensureBundle(state, currentMember);

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;
        final subTextColor = isDark ? Colors.white54 : Colors.black54;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: CustomAppBar(
            title: currentMember.name,
            showTeamSwitcher: true,
          ),
          body: buildKeyboardDismissible(child: AppBackground(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() => _bundleKey = '');
                _ensureBundle(state, currentMember);
                await _bundleFuture;
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: kToolbarHeight + 48,
                  left: 16,
                  right: 16,
                  bottom: 16 + smoothKeyboardHeight,
                ),
                child: FutureBuilder<_PlayerBundle>(
                  future: _bundleFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      final message = snapshot.error is ApiException
                          ? (snapshot.error as ApiException).message
                          : 'Could not load player details.';
                      return _buildError(message, textColor);
                    }
                    final bundle = snapshot.data;
                    final canManageMedical =
                        state.userRoleInSelectedTeam.trim() == 'TeamDoctor';
                    final canManageFitness =
                        state.userRoleInSelectedTeam.trim() == 'FitnessCoach';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileCard(
                          currentMember,
                          bundle?.profile,
                          cardBg,
                          textColor,
                          subTextColor,
                        ),
                        const SizedBox(height: 16),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else ...[
                          _buildMedicalStatusBanner(bundle?.medical ?? []),
                          const SizedBox(height: 16),
                          if (canManageMedical) ...[
                            _buildDoctorActions(
                              state: state,
                              member: currentMember,
                              cardBg: cardBg,
                              textColor: textColor,
                              subTextColor: subTextColor,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildStatsSection(
                            bundle?.stats ?? const {},
                            cardBg,
                            textColor,
                            subTextColor,
                          ),
                          const SizedBox(height: 16),
                          _buildFitnessSection(
                            bundle?.fitness ?? const [],
                            cardBg,
                            textColor,
                            subTextColor,
                            canManageFitness,
                            state,
                            currentMember,
                          ),
                          const SizedBox(height: 16),
                          _buildMedicalSection(
                            bundle?.medical ?? const [],
                            cardBg,
                            textColor,
                            subTextColor,
                            canManageMedical,
                            state,
                            currentMember,
                          ),
                        ],
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),
              ),
            ),
          )),
        );
      },
    );
  }

  Widget _buildProfileCard(
    Member member,
    PlayerProfileDto? profile,
    Color cardBg,
    Color textColor,
    Color subTextColor,
  ) {
    final details = <String>[
      if (profile?.position?.isNotEmpty == true) profile!.position!,
      if (profile?.jerseyNumber != null) '#${profile!.jerseyNumber}',
      if (profile?.height != null) '${profile!.height} cm',
      if (profile?.weight != null) '${profile!.weight} kg',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundImage: AssetImage(member.image), radius: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.name.isNotEmpty == true
                      ? profile!.name
                      : member.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
                Text(member.role, style: TextStyle(color: subTextColor)),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    details.join(' - '),
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalStatusBanner(List<MedicalRecordDto> records) {
    final latest = records.isEmpty ? null : records.first;
    final cleared = latest?.isClearedToPlay ?? true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cleared
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        cleared
            ? 'Fit to play'
            : 'Not cleared: ${latest?.injuryType ?? 'medical review required'}',
        style: TextStyle(color: cleared ? Colors.green : Colors.red),
      ),
    );
  }

  Widget _buildStatsSection(
    Map<String, dynamic> stats,
    Color cardBg,
    Color textColor,
    Color subTextColor,
  ) {
    final entries = stats.entries
        .where(
          (entry) =>
              entry.value != null &&
              entry.value is! Map &&
              entry.value is! List,
        )
        .take(8)
        .toList();
    return _section(
      title: 'PLAYER STATS',
      icon: Icons.bar_chart,
      color: AppColors.primary,
      textColor: textColor,
      child: entries.isEmpty
          ? _emptyCard('No player stats found.', cardBg, subTextColor)
          : Column(
              children: entries
                  .map(
                    (entry) => Card(
                      color: cardBg,
                      child: ListTile(
                        title: Text(
                          entry.key,
                          style: TextStyle(color: textColor),
                        ),
                        trailing: Text(
                          '${entry.value}',
                          style: TextStyle(color: textColor),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildDoctorActions({
    required TeamState state,
    required Member member,
    required Color cardBg,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doctor controls',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'SFPro',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create records, update clearance, and request documents.',
                  style: TextStyle(color: subTextColor, fontFamily: 'SFPro'),
                ),
              ],
            ),
          ),
          AnimatedButton.primary(child: ElevatedButton.icon(
            onPressed: _isMedicalSaving
                ? null
                : () => _openMedicalRecordDialog(state: state, member: member),
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).record),
          )),
        ],
      ),
    );
  }

  Widget _buildFitnessSection(
    List<FitnessRecordDto> records,
    Color cardBg,
    Color textColor,
    Color subTextColor,
    bool canManageFitness,
    TeamState state,
    Member member,
  ) {
    return _section(
      title: 'PLAYER FITNESS RECORDS',
      icon: Icons.fitness_center,
      color: Colors.blue,
      textColor: textColor,
      child: Column(
        children: [
          if (canManageFitness) ...[
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedButton.primary(child: ElevatedButton.icon(
                onPressed: _isFitnessSaving
                    ? null
                    : () => _openFitnessRecordDialog(
                        state: state,
                        member: member,
                      ),
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context).addFitnessRecord),
              )),
            ),
            const SizedBox(height: 8),
          ],
          if (records.isEmpty)
            _emptyCard('No fitness records found.', cardBg, subTextColor)
          else
            ...records.map((record) {
              final metrics = <String>[
                if (record.bmi != null) 'BMI ${record.bmi}',
                if (record.bodyFatPct != null) 'Body fat ${record.bodyFatPct}%',
                if (record.speedTestResult != null)
                  'Speed ${record.speedTestResult}',
                if (record.enduranceScore != null)
                  'Endurance ${record.enduranceScore}',
                if (record.customTestName != null)
                  '${record.customTestName}: ${record.customTestResult ?? ''}',
              ];
              return Card(
                color: cardBg,
                child: ListTile(
                  title: Text(
                    record.recordedAt.toLocal().toString().split(' ').first,
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    metrics.isEmpty ? 'Fitness record' : metrics.join(' - '),
                    style: TextStyle(color: subTextColor),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMedicalSection(
    List<MedicalRecordDto> records,
    Color cardBg,
    Color textColor,
    Color subTextColor,
    bool canManageMedical,
    TeamState state,
    Member member,
  ) {
    return _section(
      title: 'PLAYER MEDICAL RECORDS',
      icon: Icons.healing,
      color: Colors.red,
      textColor: textColor,
      child: records.isEmpty
          ? _emptyCard('No medical records found.', cardBg, subTextColor)
          : Column(
              children: records.map((record) {
                final pendingDocs = record.documentRequests
                    .where(
                      (request) => request.status.toLowerCase() == 'pending',
                    )
                    .length;
                final subtitle = [
                  record.diagnosis ?? record.recoveryTips ?? 'No notes',
                  if (pendingDocs > 0)
                    '$pendingDocs pending document request${pendingDocs == 1 ? '' : 's'}',
                ].join('\n');
                return Card(
                  color: cardBg,
                  child: ListTile(
                    title: Text(
                      record.injuryType ?? 'Medical record',
                      style: TextStyle(color: textColor),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: TextStyle(color: subTextColor),
                    ),
                    trailing: canManageMedical
                        ? PopupMenuButton<String>(
                            icon: Icon(
                              record.isClearedToPlay
                                  ? Icons.verified
                                  : Icons.local_hospital_rounded,
                              color: record.isClearedToPlay
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openMedicalRecordDialog(
                                  state: state,
                                  member: member,
                                  record: record,
                                );
                              } else if (value == 'clearance') {
                                _toggleClearance(
                                  state: state,
                                  member: member,
                                  record: record,
                                );
                              } else if (value == 'document') {
                                _openDocumentRequestDialog(
                                  state: state,
                                  member: member,
                                  record: record,
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text(AppLocalizations.of(context).editRecord),
                              ),
                              PopupMenuItem(
                                value: 'clearance',
                                child: Text(
                                  record.isClearedToPlay
                                      ? 'Mark not cleared'
                                      : 'Mark cleared',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'document',
                                child: Text(AppLocalizations.of(context).requestDocument),
                              ),
                            ],
                          )
                        : Icon(
                            record.isClearedToPlay
                                ? Icons.verified
                                : Icons.local_hospital_rounded,
                            color: record.isClearedToPlay
                                ? Colors.green
                                : Colors.orange,
                          ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Color color,
    required Color textColor,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _emptyCard(String text, Color cardBg, Color subTextColor) {
    return Card(
      color: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: TextStyle(color: subTextColor)),
      ),
    );
  }

  Widget _buildError(String message, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(message, style: TextStyle(color: textColor)),
      ),
    );
  }
}

class _PlayerBundle {
  final PlayerProfileDto? profile;
  final List<FitnessRecordDto> fitness;
  final List<MedicalRecordDto> medical;
  final Map<String, dynamic> stats;

  const _PlayerBundle({
    this.profile,
    this.fitness = const [],
    this.medical = const [],
    this.stats = const {},
  });
}

class _MedicalContext {
  final String clubId;
  final String teamId;
  final String playerUserId;

  const _MedicalContext({
    required this.clubId,
    required this.teamId,
    required this.playerUserId,
  });
}
