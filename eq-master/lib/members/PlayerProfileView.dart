import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';

import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/network_video_player_screen.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../chat/ChatView.dart';
import '../core/app_localizations.dart';
import '../core/app_transitions.dart';
import '../core/responsive_system.dart';
import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/fitness_service.dart';
import '../services/medical_service.dart';
import '../services/messaging_service.dart';
import '../services/player_service.dart';
import '../services/player_video_service.dart';
import '../services/stats_service.dart';
import '../session/session_bloc.dart';
import '../team/team_bloc.dart';
import 'MemberModel.dart';
import 'AddMedicalRecordView.dart';
import 'MedicalRecordDetailView.dart';
import '../core/design_tokens.dart';

class PlayerProfileView extends StatefulWidget {
  final Member member;
  final int memberIndex;
  final bool showOnlyThroughFitToPlay;

  /// Optional section to auto-scroll to on open: 'fitness' or 'medical'.
  /// Used when arriving from a notification about a new record.
  final String? initialSection;

  const PlayerProfileView({
    super.key,
    required this.member,
    required this.memberIndex,
    this.showOnlyThroughFitToPlay = false,
    this.initialSection,
  });

  @override
  State<PlayerProfileView> createState() => _PlayerProfileViewState();
}

class _PlayerProfileViewState extends State<PlayerProfileView> with TickerProviderStateMixin, SmoothKeyboardMixin {
  final PlayerService _playerService = PlayerService();
  final FitnessService _fitnessService = FitnessService();
  final MedicalService _medicalService = MedicalService();
  final StatsService _statsService = StatsService();
  final MessagingService _messagingService = MessagingService();
  final PlayerVideoService _playerVideoService = PlayerVideoService();

  // Player videos (loaded lazily per club/team/player context).
  List<PlayerVideoDto> _playerVideos = [];
  String _videosKey = '';
  bool _videosLoading = false;
  bool _videosLoaded = false;
  bool _uploadingVideo = false;

  Future<_PlayerBundle>? _bundleFuture;
  String _bundleKey = '';
  bool _isMedicalSaving = false;
  bool _isFitnessSaving = false;
  bool _isStartingChat = false;
  final Map<String, String> _localBiometricLatest = {};
  final Map<String, List<MapEntry<String, String>>> _localBiometricHistory = {};
  final List<FitnessRecordDto> _localFitnessRecords = [];

  // Auto-scroll-to-section support (used when opened from a notification).
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _fitnessSectionKey = GlobalKey();
  final GlobalKey _medicalSectionKey = GlobalKey();
  bool _didFocusSection = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleSectionFocus() {
    if (_didFocusSection || widget.initialSection == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = widget.initialSection == 'medical'
          ? _medicalSectionKey
          : _fitnessSectionKey;
      final ctx = key.currentContext;
      if (ctx != null) {
        _didFocusSection = true;
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
      }
    });
  }

  void _ensureBundle(TeamState state, Member member) {
    final selectedTeams = state.availableTeams
        .where((t) => t.id == state.selectedTeamId)
        .toList();
    final clubId = selectedTeams.isEmpty ? null : selectedTeams.first.clubId;
    final key = '${clubId ?? ''}:${state.selectedTeamId}:${member.userId}';
    if (key == _bundleKey) return;
    _bundleKey = key;
    _localFitnessRecords.clear();
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

    Future<List<Map<String, dynamic>>> loadMatchHistory() async {
      try {
        final raw = await _statsService.getPlayerMatchHistory(
          clubId,
          teamId,
          userId,
        );
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }

    final results = await Future.wait<dynamic>([
      loadProfile(),
      loadFitness(),
      loadMedical(),
      loadStats(),
      loadMatchHistory(),
    ]);
    return _PlayerBundle(
      profile: results[0] as PlayerProfileDto?,
      fitness: List<FitnessRecordDto>.from(results[1] as List),
      medical: List<MedicalRecordDto>.from(results[2] as List),
      stats: Map<String, dynamic>.from(results[3] as Map),
      matchHistory: List<Map<String, dynamic>>.from(results[4] as List),
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
    if (!mounted) return null;
    _bundleKey = '';
    _ensureBundle(state, member);
    final future = _bundleFuture;
    final bundle = await future;
    if (mounted) setState(() {});
    return bundle;
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openChat(Member member, UserInfo? currentUser) async {
    if (currentUser == null || member.userId.isEmpty) return;
    setState(() => _isStartingChat = true);
    try {
      final conversation = await _messagingService.createConversation(
        participantIds: [member.userId],
      );
      if (!mounted) return;
      await Navigator.push(
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
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Could not start conversation.');
    } finally {
      if (mounted) setState(() => _isStartingChat = false);
    }
  }

  // ── Medical record dialog ──
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

    // Resolve theme from the parent context BEFORE opening the dialog
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final fieldFill = isDark ? const Color(0xFF0D2A1C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                record == null ? AppLocalizations.of(context).newMedRecord : AppLocalizations.of(context).editMedRecord,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'SFPro',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(
                      controller: injuryController,
                      label: AppLocalizations.of(context).injuryType,
                      textColor: textColor,
                      labelColor: labelColor,
                      fillColor: fieldFill,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      controller: diagnosisController,
                      label: AppLocalizations.of(context).diagnosis,
                      textColor: textColor,
                      labelColor: labelColor,
                      fillColor: fieldFill,
                      borderColor: borderColor,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      controller: recoveryController,
                      label: AppLocalizations.of(context).recoveryTips,
                      textColor: textColor,
                      labelColor: labelColor,
                      fillColor: fieldFill,
                      borderColor: borderColor,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: returnDateController,
                      readOnly: true,
                      style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldFill,
                        labelText: AppLocalizations.of(context).expReturnDate,
                        labelStyle: TextStyle(
                          fontFamily: 'SFPro',
                          color: labelColor,
                        ),
                        suffixIcon: Icon(
                          Icons.calendar_today,
                          color: labelColor,
                          size: 18,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.green),
                        ),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sbCtx,
                          initialDate: DateTime.now().add(
                            const Duration(days: 7),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (picked == null) return;
                        if (!sbCtx.mounted) return;
                        setDialogState(() {
                          returnDateController.text =
                              '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(
                          AppLocalizations.of(context).cancel,
                          style: const TextStyle(fontFamily: 'SFPro'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _isMedicalSaving
                            ? null
                            : () async {
                                final nav = Navigator.of(dialogCtx);
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
                                if (saved && mounted) {
                                  nav.pop();
                                }
                              },
                        child: Text(
                          record == null ? AppLocalizations.of(context).create : AppLocalizations.of(context).save,
                          style: const TextStyle(
                            fontFamily: 'SFPro',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
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
    required Color labelColor,
    required Color fillColor,
    required Color borderColor,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: textColor, fontFamily: 'SFPro', fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'SFPro', color: labelColor),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.green),
        ),
      ),
    );
  }

  Widget _dialogInlineField({
    required String label,
    required Color textColor,
    required Color labelColor,
    required Color fillColor,
    required Color borderColor,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    return TextField(
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor, fontFamily: 'SFPro', fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'SFPro', color: labelColor),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.green),
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final fieldFill = isDark ? const Color(0xFF0D2A1C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    var recordName = '';
    var recordValue = '';

    final record = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            AppLocalizations.of(context).addFitnessRecordTitle,
            style: TextStyle(
              color: textColor,
              fontFamily: 'SFPro',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogInlineField(
                label: AppLocalizations.of(context).recordName,
                textColor: textColor,
                labelColor: labelColor,
                fillColor: fieldFill,
                borderColor: borderColor,
                onChanged: (value) => recordName = value,
              ),
              const SizedBox(height: 12),
              _dialogInlineField(
                label: AppLocalizations.of(context).value,
                textColor: textColor,
                labelColor: labelColor,
                fillColor: fieldFill,
                borderColor: borderColor,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) => recordValue = value,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(
                      AppLocalizations.of(context).cancel,
                      style: const TextStyle(fontFamily: 'SFPro'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(dialogCtx, {
                        'name': recordName.trim(),
                        'value': recordValue.trim(),
                      });
                    },
                    child: Text(
                      AppLocalizations.of(context).add,
                      style: const TextStyle(
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (record == null) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    setState(() => _isFitnessSaving = true);
    final savedRecord = await _saveFitnessRecord(
      state: state,
      member: member,
      recordName: record['name'] ?? '',
      recordValue: record['value'] ?? '',
    );
    try {
      if (savedRecord != null && mounted) {
        await _appendLocalFitnessRecord(savedRecord);
        _showSnack('Fitness record created.');
      }
    } finally {
      if (mounted) setState(() => _isFitnessSaving = false);
    }
  }

  Future<FitnessRecordDto?> _saveFitnessRecord({
    required TeamState state,
    required Member member,
    required String recordName,
    required String recordValue,
  }) async {
    final contextInfo = _medicalContext(state, member);
    if (contextInfo == null) {
      _showSnack('Select a team and player first.');
      return null;
    }
    final parsedValue = double.tryParse(recordValue);
    if (recordName.isEmpty || parsedValue == null) {
      _showSnack('Enter a record name and a valid value.');
      return null;
    }
    try {
      return await _fitnessService.createFitnessRecord(
        contextInfo.clubId,
        contextInfo.teamId,
        contextInfo.playerUserId,
        {
          'testDate': DateTime.now().toIso8601String(),
          'customTestName': recordName,
          'customTestResult': parsedValue,
        },
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
      return null;
    } catch (_) {
      _showSnack('Could not create fitness record.');
      return null;
    }
  }

  Future<void> _appendLocalFitnessRecord(FitnessRecordDto record) async {
    if (!mounted) return;
    setState(() {
      _localFitnessRecords.removeWhere(
        (item) => item.recordId == record.recordId,
      );
      _localFitnessRecords.insert(0, record);
    });
  }

  List<FitnessRecordDto> _mergedFitnessRecords(List<FitnessRecordDto> records) {
    final localIds = _localFitnessRecords
        .map((record) => record.recordId)
        .where((id) => id.isNotEmpty)
        .toSet();
    return [
      ..._localFitnessRecords,
      ...records.where((record) => !localIds.contains(record.recordId)),
    ];
  }

  Future<void> _openBiometricUpdateDialog({
    required _BiometricMetric metric,
    required TeamState state,
    required Member member,
    required PlayerProfileDto? profile,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final fieldFill = isDark ? const Color(0xFF0D2A1C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    var rawValue = '';

    final value = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Update ${metric.label}',
            style: TextStyle(
              color: textColor,
              fontFamily: 'SFPro',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            onChanged: (value) => rawValue = value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              color: textColor,
              fontFamily: 'SFPro',
              fontSize: 14,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: fieldFill,
              labelText: metric.inputLabel,
              labelStyle: TextStyle(fontFamily: 'SFPro', color: labelColor),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.green),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontFamily: 'SFPro'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(dialogCtx, rawValue.trim());
                    },
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (value == null) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final saved = await _saveBiometricUpdate(
      metric: metric,
      state: state,
      member: member,
      profile: profile,
      value: value,
    );
    if (!mounted) return;

    if (saved) {
      _applyLocalBiometricUpdate(metric, value);
      _showSnack('${metric.label} updated.');
    }
  }

  void _applyLocalBiometricUpdate(_BiometricMetric metric, String rawValue) {
    final displayValue = _formatBiometricInput(metric, rawValue);
    if (displayValue == null) return;

    setState(() {
      _localBiometricLatest[metric.key] = displayValue;
      final existing = _localBiometricHistory[metric.key] ?? metric.history;
      _localBiometricHistory[metric.key] = [
        MapEntry(_formatRecordDate(DateTime.now()), displayValue),
        ...existing.where((entry) => entry.value != displayValue),
      ];
    });
  }

  String? _formatBiometricInput(_BiometricMetric metric, String rawValue) {
    final value = double.tryParse(rawValue);
    if (value == null) return null;
    if (metric.key == 'height') return '${value.toStringAsFixed(0)} cm';
    if (metric.key == 'weight') return '${value.toStringAsFixed(0)} kg';
    if (metric.key == 'bodyFat') return '${value.toStringAsFixed(1)}%';
    return value.toStringAsFixed(1);
  }

  Future<bool> _saveBiometricUpdate({
    required _BiometricMetric metric,
    required TeamState state,
    required Member member,
    required PlayerProfileDto? profile,
    required String value,
  }) async {
    final parsedValue = double.tryParse(value);
    if (parsedValue == null) {
      _showSnack('Enter a valid number.');
      return false;
    }

    final contextInfo = _medicalContext(state, member);
    if (contextInfo == null) {
      _showSnack('Select a team and player first.');
      return false;
    }

    try {
      if (metric.key == 'height' || metric.key == 'weight') {
        final heightValue = metric.key == 'height'
            ? parsedValue
            : _localBiometricNumber('height') ?? profile?.height;
        final weightValue = metric.key == 'weight'
            ? parsedValue
            : _localBiometricNumber('weight') ?? profile?.weight;

        await _playerService.upsertPlayerProfile(
          contextInfo.clubId,
          contextInfo.teamId,
          contextInfo.playerUserId,
          {
            if (profile?.name.isNotEmpty == true) 'name': profile!.name,
            if (profile?.email.isNotEmpty == true) 'email': profile!.email,
            if (profile?.username?.isNotEmpty == true)
              'username': profile!.username,
            if (profile?.bio?.isNotEmpty == true) 'bio': profile!.bio,
            if (profile?.dob?.isNotEmpty == true) 'dob': profile!.dob,
            if (profile?.position?.isNotEmpty == true)
              'position': profile!.position,
            if (profile?.jerseyNumber != null)
              'jerseyNumber': profile!.jerseyNumber,
            'height': heightValue,
            'weight': weightValue,
          },
        );
      } else {
        await _fitnessService.createFitnessRecord(
          contextInfo.clubId,
          contextInfo.teamId,
          contextInfo.playerUserId,
          {
            'testDate': DateTime.now().toIso8601String(),
            if (metric.key == 'bmi') 'bmi': parsedValue,
            if (metric.key == 'bodyFat') 'bodyFatPct': parsedValue,
            if (metric.key.startsWith('custom:')) ...{
              'customTestName': metric.label,
              'customTestResult': parsedValue,
            },
          },
        );
      }
      return true;
    } on ApiException catch (e) {
      _showSnack(e.message);
      return false;
    } catch (_) {
      _showSnack('Could not update ${metric.label.toLowerCase()}.');
      return false;
    }
  }

  double? _localBiometricNumber(String key) {
    final value = _localBiometricLatest[key];
    if (value == null) return null;
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  Future<void> _openDocumentRequestDialog({
    required TeamState state,
    required Member member,
    required MedicalRecordDto record,
  }) async {
    final nameController = TextEditingController();
    final noteController = TextEditingController();

    // Resolve theme from the parent context BEFORE opening the dialog
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final fieldFill = isDark ? const Color(0xFF0D2A1C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            AppLocalizations.of(context).requestDocument,
            style: TextStyle(
              color: textColor,
              fontFamily: 'SFPro',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(
                controller: nameController,
                label: AppLocalizations.of(context).documentName,
                textColor: textColor,
                labelColor: labelColor,
                fillColor: fieldFill,
                borderColor: borderColor,
              ),
              const SizedBox(height: 12),
              _dialogField(
                controller: noteController,
                label: AppLocalizations.of(context).noteToPlayer,
                textColor: textColor,
                labelColor: labelColor,
                fillColor: fieldFill,
                borderColor: borderColor,
                maxLines: 3,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(
                      AppLocalizations.of(context).cancel,
                      style: const TextStyle(fontFamily: 'SFPro'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () async {
                      final nav = Navigator.of(dialogCtx);
                      final requested = await _requestDocument(
                        state: state,
                        member: member,
                        record: record,
                        documentName: nameController.text.trim(),
                        note: noteController.text.trim(),
                      );
                      if (requested && mounted) {
                        nav.pop();
                      }
                    },
                    child: Text(
                      AppLocalizations.of(context).request,
                      style: const TextStyle(
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
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

  // ═══════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    updateKeyboardHeight(MediaQuery.viewInsetsOf(context).bottom);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.white54 : Colors.grey;
    final hPad = ResponsiveSystem.horizontalPadding(context);

    return BlocBuilder<TeamBloc, TeamState>(
      builder: (context, state) {
        final currentMember = state.members.length > widget.memberIndex
            ? state.members[widget.memberIndex]
            : widget.member;
        _ensureBundle(state, currentMember);
        _scheduleSectionFocus();

        final canManageMedical =
            state.userRoleInSelectedTeam.trim() == 'TeamDoctor';
        final canManageFitness =
            state.userRoleInSelectedTeam.trim() == 'FitnessCoach';
        final isAnalyst =
            state.userRoleInSelectedTeam.trim().toLowerCase() == 'teamanalyst';

        return Scaffold(
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          appBar: CustomAppBar(
            title: currentMember.name,
            showTeamSwitcher: false,
            actions: [
              _buildPlayerMenu(context, state, currentMember, canManageFitness || canManageMedical || state.userRoleInSelectedTeam.trim() == 'ClubManager' || state.userRoleInSelectedTeam.trim() == 'TeamManager'),
            ],
          ),
          body: buildKeyboardDismissible(
            child: AppBackground(
              child: SafeArea(
                child: RefreshIndicator(
                onRefresh: () async {
                  await _reload(state, currentMember);
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    hPad,
                    0,
                    hPad,
                    16 + smoothKeyboardHeight,
                  ),
                  child: FutureBuilder<_PlayerBundle>(
                    future: _bundleFuture,
                    builder: (context, snapshot) {
                      final bundle = snapshot.data;
                      final profile = bundle?.profile;
                      final fitnessRecords = _mergedFitnessRecords(
                        bundle?.fitness ?? [],
                      );

                      final displayName = profile?.name.isNotEmpty == true
                          ? profile!.name
                          : currentMember.name;
                      final displayEmail = profile?.email.isNotEmpty == true
                          ? profile!.email
                          : currentMember.email;
                      final displayUsername =
                          profile?.username?.isNotEmpty == true
                          ? profile!.username
                          : null;
                      final displayBio = profile?.bio?.isNotEmpty == true
                          ? profile!.bio!
                          : 'No bio yet.';

                      final profileImage = _resolveProfileImage(
                        profile?.profileImageUrl,
                        currentMember.image,
                      );

                      final jerseyStr = profile?.jerseyNumber != null
                          ? '#${profile!.jerseyNumber}'
                          : 'N/A';
                      final positionStr = profile?.position?.isNotEmpty == true
                          ? profile!.position!
                          : 'N/A';

                      String ageStr = 'N/A';
                      final dobStr = profile?.dob;
                      if (dobStr != null && dobStr.isNotEmpty) {
                        try {
                          final dob = DateTime.parse(dobStr);
                          final now = DateTime.now();
                          var age = now.year - dob.year;
                          if (now.month < dob.month ||
                              (now.month == dob.month && now.day < dob.day)) {
                            age--;
                          }
                          ageStr = '$age yrs';
                        } catch (_) {}
                      } else if (currentMember.age > 0) {
                        ageStr = '${currentMember.age} yrs';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ═══════════════════════════════
                          // PROFILE CARD
                          // ═══════════════════════════════
                          Builder(
                            builder: (context) {
                              final session = context
                                  .watch<SessionBloc>()
                                  .state;
                              final isOwnProfile =
                                  session.user?.userId == currentMember.userId;

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  16,
                                ),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            _buildProfileAvatar(
                                              profileImage,
                                              isDark,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: _buildPlayerCardContent(
                                            displayName,
                                            displayUsername,
                                            displayEmail,
                                            displayBio,
                                            isDark,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                      ],
                                    ),
                                    // Message button — only when viewing
                                    // another player's profile
                                    if (!isOwnProfile) ...[
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: AnimatedButton.primary(child: ElevatedButton.icon(
                                          onPressed: _isStartingChat
                                              ? null
                                              : () => _openChat(
                                                  currentMember,
                                                  session.user,
                                                ),
                                          icon: Icon(
                                            _isStartingChat
                                                ? Icons.hourglass_top
                                                : Icons.message_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            _isStartingChat
                                                ? AppLocalizations.of(context).opening
                                                : AppLocalizations.of(context).message,
                                            style: const TextStyle(
                                              fontFamily: 'SFPro',
                                              fontSize: 13,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(
                                              double.infinity,
                                              50,
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
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // ═══════════════════════════════
                          // INFO CARD — Jersey, Position, Age, Role
                          // ═══════════════════════════════
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.md,
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
                                  title: AppLocalizations.of(context).role,
                                  value: currentMember.role,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 14),
                                _InfoRow(
                                  title: AppLocalizations.of(context).jerseyNumber,
                                  value: jerseyStr,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 14),
                                _InfoRow(
                                  title: "Age",
                                  value: ageStr,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 14),
                                _InfoRow(
                                  title: "Position",
                                  value: positionStr,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Medical status banner
                          _buildMedicalStatusBanner(
                            bundle?.medical ?? [],
                            isDark,
                          ),

                          if (!widget.showOnlyThroughFitToPlay) ...[
                            const SizedBox(height: 28),

                            // ═══════════════════════════════
                            // LOADING INDICATOR
                            // ═══════════════════════════════
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (snapshot.hasError)
                              _buildErrorWidget(
                                snapshot.error is ApiException
                                    ? (snapshot.error as ApiException).message
                                    : 'Could not load player details.',
                                textColor,
                              )
                            else ...[
                              // ═══════════════════════════════
                              // SECTION: PLAYER BIOMETRICS
                              // ═══════════════════════════════
                              _buildSectionHeader(
                                AppLocalizations.of(context).titlePlayerBiometrics,
                                Icons.straighten,
                                textColor,
                              ),
                              const SizedBox(height: 14),
                              _buildBiometricsDropdowns(
                                profile,
                                fitnessRecords,
                                cardBg,
                                textColor,
                                subtextColor,
                                canManageFitness,
                                state,
                                currentMember,
                              ),
                              const SizedBox(height: 28),

                              // ═══════════════════════════════
                              // SECTION: FITNESS RECORDS
                              // ═══════════════════════════════
                              KeyedSubtree(
                                key: _fitnessSectionKey,
                                child: _buildSectionHeader(
                                  AppLocalizations.of(context).titleFitnessRecords,
                                  Icons.fitness_center,
                                  textColor,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (canManageFitness) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: _buildOnboardingButton(
                                    label: AppLocalizations.of(context).addARecord,
                                    onPressed: _isFitnessSaving
                                        ? null
                                        : () => _openFitnessRecordDialog(
                                            state: state,
                                            member: currentMember,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              _buildFitnessRecordDropdowns(
                                fitnessRecords,
                                cardBg,
                                textColor,
                                subtextColor,
                                canManageFitness,
                                state,
                                currentMember,
                              ),
                              const SizedBox(height: 28),

                              // ═══════════════════════════════
                              // SECTION: MEDICAL RECORDS
                              // ═══════════════════════════════
                              KeyedSubtree(
                                key: _medicalSectionKey,
                                child: _buildSectionHeader(
                                  "MEDICAL RECORDS",
                                  Icons.healing,
                                  textColor,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildMedicalCards(
                                bundle?.medical ?? [],
                                cardBg,
                                textColor,
                                subtextColor,
                                canManageMedical,
                                state,
                                currentMember,
                              ),
                              if (canManageMedical) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: _buildOnboardingButton(
                                    label: AppLocalizations.of(context).addMedicalRecord,
                                    onPressed: _isMedicalSaving
                                        ? null
                                        : () async {
                                            final medicalContext =
                                                _medicalContext(
                                                  state,
                                                  currentMember,
                                                );
                                            if (medicalContext == null) {
                                              _showSnack(
                                                'Select a team and player first.',
                                              );
                                              return;
                                            }
                                            final saved =
                                                await Navigator.push<bool>(
                                                  context,
                                                  AppPageRoute(
                                                    child:
                                                        AddMedicalRecordView(
                                                          clubId: medicalContext
                                                              .clubId,
                                                          teamId: medicalContext
                                                              .teamId,
                                                          playerUserId:
                                                              medicalContext
                                                                  .playerUserId,
                                                        ),
                                                  ),
                                                );
                                            if (saved == true && mounted) {
                                              await _reload(
                                                state,
                                                currentMember,
                                              );
                                            }
                                          },
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),

                              // ═══════════════════════════════
                              // SECTION: PLAYER STATS
                              // ═══════════════════════════════
                              _buildSectionHeader(
                                "PLAYER STATS",
                                Icons.analytics,
                                textColor,
                              ),
                              const SizedBox(height: 14),
                              _buildPlayerStatsCard(
                                bundle?.matchHistory ?? [],
                                currentMember,
                                cardBg,
                                textColor,
                                subtextColor,
                              ),
                              const SizedBox(height: 28),

                              // ═══════════════════════════════
                              // SECTION: PLAYER VIDEOS
                              // ═══════════════════════════════
                              // ═══════════════════════════════
                              // SECTION: PLAYER VIDEOS
                              // ═══════════════════════════════
                              _buildSectionHeader(
                                "PLAYER VIDEOS",
                                Icons.videocam,
                                textColor,
                              ),
                              const SizedBox(height: 14),
                              _buildVideosCard(
                                state,
                                currentMember,
                                cardBg,
                                textColor,
                                subtextColor,
                                isAnalyst,
                              ),
                            ],
                          ],

                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  ),
                ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════
  // SECTION HEADER — matches the TEAMS header style
  // ═══════════════════════════════════════════════════
  Widget _buildSectionHeader(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 20),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Facon',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: textColor,
          ),
        ),
      ],
    );
  }

  ImageProvider? _resolveProfileImage(
    String? profileImageUrl,
    String memberImage,
  ) {
    return _buildImageProvider(profileImageUrl) ??
        _buildImageProvider(memberImage);
  }

  ImageProvider? _buildImageProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path == 'assets/profile.png') return null;
    if (path.startsWith('assets/')) return AssetImage(path);
    final resolved = ApiClient.resolveUrl(path);
    return resolved != null ? NetworkImage(resolved) : null;
  }

  Widget _buildProfileAvatar(ImageProvider? image, bool isDark) {
    final bgColor = isDark ? const Color(0xFF0D2A1C) : const Color(0xFFE8E8E8);
    final iconColor = isDark ? Colors.white54 : Colors.black45;

    Widget avatar;
    if (image == null) {
      avatar = CircleAvatar(
        radius: 45,
        backgroundColor: bgColor,
        child: Icon(Icons.person, size: 36, color: iconColor),
      );
    } else {
      avatar = CircleAvatar(
        radius: 45,
        backgroundColor: bgColor,
        child: ClipOval(
          child: Image(
            image: image,
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(Icons.person, size: 36, color: iconColor),
              );
            },
          ),
        ),
      );
    }

    return Hero(
      tag: 'member-avatar-${widget.member.userId}',
      child: avatar,
    );
  }

  DateTime? _parseDateOnly(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthName = months[date.month - 1];
    return '$monthName ${date.year}';
  }

  // ── Player card content (mirrors user profile card layout) ──
  Widget _buildPlayerCardContent(
    String name,
    String? username,
    String email,
    String bio,
    bool isDark,
  ) {
    final nameColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final emailColor = isDark ? Colors.white54 : const Color(0xFF888888);
    final detailColor = isDark ? Colors.white70 : const Color(0xFF444444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Text(
          email,
          style: TextStyle(
            fontFamily: 'SFPro',
            fontSize: 13,
            color: emailColor,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '\u201C$bio\u201D',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'SFPro',
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: detailColor,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // ACTION BUTTON
  // ═══════════════════════════════════════════════════
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return AnimatedButton.primary(child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontFamily: 'SFPro', fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ));
  }

  Widget _buildOnboardingButton({
    required String label,
    VoidCallback? onPressed,
  }) {
    return AnimatedButton.primary(child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'SFPro',
          fontWeight: FontWeight.w600,
        ),
      ),
    ));
  }

  // ═══════════════════════════════════════════════════
  // BIOMETRICS SECTION
  // ═══════════════════════════════════════════════════
  Widget _buildBiometricsDropdowns(
    PlayerProfileDto? profile,
    List<FitnessRecordDto> records,
    Color cardBg,
    Color textColor,
    Color subtextColor,
    bool canManageFitness,
    TeamState state,
    Member member,
  ) {
    final height = profile?.height;
    final weight = profile?.weight;
    final bmi = (height != null && weight != null && height > 0)
        ? (weight / ((height / 100) * (height / 100)))
        : null;

    final metrics = <_BiometricMetric>[
      _BiometricMetric(
        key: 'height',
        label: AppLocalizations.of(context).height,
        inputLabel: 'Height in cm',
        latestValue: height != null ? '${height.toStringAsFixed(0)} cm' : 'N/A',
        history: [
          if (height != null)
            MapEntry('Current', '${height.toStringAsFixed(0)} cm'),
          ..._metricHistory(
            records,
            (record) => record.height,
            suffix: ' cm',
            fractionDigits: 0,
          ),
        ],
      ),
      _BiometricMetric(
        key: 'weight',
        label: AppLocalizations.of(context).weight,
        inputLabel: 'Weight in kg',
        latestValue: weight != null ? '${weight.toStringAsFixed(0)} kg' : 'N/A',
        history: [
          if (weight != null)
            MapEntry('Current', '${weight.toStringAsFixed(0)} kg'),
          ..._metricHistory(
            records,
            (record) => record.weight,
            suffix: ' kg',
            fractionDigits: 0,
          ),
        ],
      ),
      _BiometricMetric(
        key: 'bmi',
        label: AppLocalizations.of(context).bmi,
        inputLabel: 'BMI',
        latestValue: _latestRecordValue(
          records,
          (record) => record.bmi,
          fallback: bmi,
          suffix: '',
        ),
        history: _metricHistory(records, (record) => record.bmi),
      ),
      _BiometricMetric(
        key: 'bodyFat',
        label: AppLocalizations.of(context).bodyFat,
        inputLabel: 'Body fat %',
        latestValue: _latestRecordValue(
          records,
          (record) => record.bodyFatPct,
          suffix: '%',
        ),
        history: _metricHistory(
          records,
          (record) => record.bodyFatPct,
          suffix: '%',
        ),
      ),
    ].map(_withLocalBiometricUpdate).toList();

    return Column(
      children: metrics
          .map(
            (entry) => Padding(
              key: ValueKey(entry.key),
              padding: const EdgeInsets.only(bottom: 12),
              child: _BiometricDropdownField(
                metric: entry,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                canManageFitness: canManageFitness,
                isSaving: _isFitnessSaving,
                onUpdate: () => _openBiometricUpdateDialog(
                  metric: entry,
                  state: state,
                  member: member,
                  profile: profile,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFitnessRecordDropdowns(
    List<FitnessRecordDto> records,
    Color cardBg,
    Color textColor,
    Color subtextColor,
    bool canManageFitness,
    TeamState state,
    Member member,
  ) {
    final customMetrics = records
        .where(
          (record) =>
              record.customTestName != null &&
              record.customTestName!.trim().isNotEmpty,
        )
        .map((record) => record.customTestName!.trim())
        .toSet()
        .map(
          (name) => _BiometricMetric(
            key: 'fitness:$name',
            label: name,
            inputLabel: '$name value',
            latestValue: _latestCustomValue(records, name),
            history: _customMetricHistory(records, name),
          ),
        )
        .toList();

    if (customMetrics.isEmpty) return const SizedBox.shrink();

    return Column(
      children: customMetrics
          .map(
            (entry) => Padding(
              key: ValueKey(entry.key),
              padding: const EdgeInsets.only(bottom: 12),
              child: _BiometricDropdownField(
                metric: entry,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                canManageFitness: canManageFitness,
                isSaving: _isFitnessSaving,
                onUpdate: () => _openFitnessRecordValueDialog(
                  metric: entry,
                  state: state,
                  member: member,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _openFitnessRecordValueDialog({
    required _BiometricMetric metric,
    required TeamState state,
    required Member member,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final fieldFill = isDark ? const Color(0xFF0D2A1C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    var recordValue = '';

    final value = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            AppLocalizations.of(context).updateMetric(metric.label),
            style: TextStyle(
              color: textColor,
              fontFamily: 'SFPro',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: _dialogInlineField(
            label: metric.inputLabel,
            textColor: textColor,
            labelColor: labelColor,
            fillColor: fieldFill,
            borderColor: borderColor,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => recordValue = value,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(
                      AppLocalizations.of(context).cancel,
                      style: TextStyle(fontFamily: 'SFPro'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(dialogCtx, recordValue.trim());
                    },
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (value == null) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    setState(() => _isFitnessSaving = true);
    final savedRecord = await _saveFitnessRecord(
      state: state,
      member: member,
      recordName: metric.label,
      recordValue: value,
    );
    try {
      if (savedRecord != null && mounted) {
        await _appendLocalFitnessRecord(savedRecord);
        _showSnack('${metric.label} updated.');
      }
    } finally {
      if (mounted) setState(() => _isFitnessSaving = false);
    }
  }

  _BiometricMetric _withLocalBiometricUpdate(_BiometricMetric metric) {
    return _BiometricMetric(
      key: metric.key,
      label: metric.label,
      inputLabel: metric.inputLabel,
      latestValue: _localBiometricLatest[metric.key] ?? metric.latestValue,
      history: _localBiometricHistory[metric.key] ?? metric.history,
    );
  }

  String _latestRecordValue(
    List<FitnessRecordDto> records,
    double? Function(FitnessRecordDto record) selector, {
    double? fallback,
    String suffix = '',
  }) {
    for (final record in _recordsNewestFirst(records)) {
      final value = selector(record);
      if (value != null) return '${value.toStringAsFixed(1)}$suffix';
    }
    if (fallback != null) return '${fallback.toStringAsFixed(1)}$suffix';
    return 'N/A';
  }

  List<MapEntry<String, String>> _metricHistory(
    List<FitnessRecordDto> records,
    double? Function(FitnessRecordDto record) selector, {
    String suffix = '',
    int fractionDigits = 1,
  }) {
    return _recordsNewestFirst(records)
        .where((record) => selector(record) != null)
        .map(
          (record) => MapEntry(
            _formatRecordDate(record.recordedAt),
            '${selector(record)!.toStringAsFixed(fractionDigits)}$suffix',
          ),
        )
        .toList();
  }

  String _latestCustomValue(List<FitnessRecordDto> records, String name) {
    for (final record in _recordsNewestFirst(records)) {
      if (record.customTestName?.trim() == name &&
          record.customTestResult != null) {
        return record.customTestResult!.toStringAsFixed(1);
      }
    }
    return 'N/A';
  }

  List<MapEntry<String, String>> _customMetricHistory(
    List<FitnessRecordDto> records,
    String name,
  ) {
    return _recordsNewestFirst(records)
        .where(
          (record) =>
              record.customTestName?.trim() == name &&
              record.customTestResult != null,
        )
        .map(
          (record) => MapEntry(
            _formatRecordDate(record.recordedAt),
            record.customTestResult!.toStringAsFixed(1),
          ),
        )
        .toList();
  }

  List<FitnessRecordDto> _recordsNewestFirst(List<FitnessRecordDto> records) {
    return [...records]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  String _formatRecordDate(DateTime date) {
    final local = date.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  // ═══════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════
  // MEDICAL RECORDS SECTION
  // ═══════════════════════════════════════════════════
  Widget _buildMedicalCards(
    List<MedicalRecordDto> records,
    Color cardBg,
    Color textColor,
    Color subtextColor,
    bool canManageMedical,
    TeamState state,
    Member member,
  ) {
    if (records.isEmpty) {
      return _buildEmptyCard('No medical records found.', cardBg, subtextColor);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: records.map((record) {
        final startText = _formatMonthYear(record.recordedAt);
        final expectedEndDate = _parseDateOnly(record.expectedReturnDate);
        final clearedAt = record.updatedAt?.toLocal();
        final endLabel = record.isClearedToPlay ? 'End' : 'Expected end';
        final endDate = record.isClearedToPlay
            ? (clearedAt ?? DateTime.now())
            : expectedEndDate;
        final endText = endDate != null ? _formatMonthYear(endDate) : 'N/A';

        final medCtx = _medicalContext(state, member);

        final uploadedDocs = record.documentRequests
            .where(
              (request) =>
                  request.downloadUrl != null ||
                  (request.fileName != null && request.fileName!.isNotEmpty),
            )
            .length;
        final pendingDocs = record.documentRequests.length - uploadedDocs;
        final clearanceLocked = _clearanceLockExpired(record);

        // The main card content
        Widget cardContent = GestureDetector(
          onTap: () {
            if (medCtx == null) return;
            Navigator.push(
              context,
              AppPageRoute(
                child: MedicalRecordDetailView(
                  clubId: medCtx.clubId,
                  teamId: medCtx.teamId,
                  playerUserId: medCtx.playerUserId,
                  record: record,
                ),
              ),
            ).then((_) {
              if (mounted) _reload(state, member);
            });
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with chevron
                Row(
                  children: [
                    Icon(
                      record.isClearedToPlay
                          ? Icons.verified
                          : Icons.local_hospital_rounded,
                      color: record.isClearedToPlay
                          ? Colors.green
                          : Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.injuryType ?? 'Medical record',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: subtextColor, size: 22),
                  ],
                ),
                const SizedBox(height: 10),
                // Date rows
                Text(
                  'Start: $startText',
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 12,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$endLabel: $endText',
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 12,
                    color: subtextColor,
                  ),
                ),
                if (record.documentRequests.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    [
                      if (uploadedDocs > 0)
                        '$uploadedDocs uploaded document${uploadedDocs == 1 ? '' : 's'}',
                      if (pendingDocs > 0)
                        '$pendingDocs pending document request${pendingDocs == 1 ? '' : 's'}',
                    ].join(' - '),
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 12,
                      color: subtextColor,
                    ),
                  ),
                ],
                // Clearance toggle for doctors
                if (canManageMedical) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cleared to play',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        child: Switch.adaptive(
                          value: record.isClearedToPlay,
                          activeColor: Colors.green,
                          onChanged: clearanceLocked
                              ? null
                              : (_) {
                                  _toggleClearance(
                                    state: state,
                                    member: member,
                                    record: record,
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );

        // Wrap in action slider for swipe actions (only for doctors)
        if (canManageMedical && medCtx != null) {
          // Resolve theme values before async operations
          final dlgBg = isDark
              ? const Color(0xFF1B3A2D)
              : const Color(0xFFF5F5F0);
          final dlgTextColor = textColor;
          final dlgSubtextColor = subtextColor;

          return _MedicalActionSlider(
            key: ValueKey(record.recordId),
            onEdit: () async {
              final saved = await Navigator.push<bool>(
                context,
                AppPageRoute(
                  child: AddMedicalRecordView(
                    clubId: medCtx.clubId,
                    teamId: medCtx.teamId,
                    playerUserId: medCtx.playerUserId,
                    record: record,
                  ),
                ),
              );
              if (saved == true && mounted) {
                await _reload(state, member);
              }
            },
            onDelete: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    backgroundColor: dlgBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    title: Text(
                      'Delete Record',
                      style: TextStyle(
                        color: dlgTextColor,
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      'Are you sure you want to delete this medical record?',
                      style: TextStyle(
                        color: dlgSubtextColor,
                        fontFamily: 'SFPro',
                      ),
                    ),
                    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    actions: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: dlgTextColor,
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontFamily: 'SFPro'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
              if (confirmed == true && mounted) {
                try {
                  await _medicalService.deleteMedicalRecord(
                    medCtx.clubId,
                    medCtx.teamId,
                    record.recordId,
                  );
                  _showSnack('Medical record deleted.');
                  await _reload(state, member);
                } on ApiException catch (e) {
                  _showSnack(e.message);
                } catch (_) {
                  _showSnack('Could not delete medical record.');
                }
              }
            },
            child: cardContent,
          );
        }

        return cardContent;
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════
  // MEDICAL STATUS BANNER
  // ═══════════════════════════════════════════════════
  Widget _buildMedicalStatusBanner(
    List<MedicalRecordDto> records,
    bool isDark,
  ) {
    final cleared = records.isEmpty || records.every((r) => r.isClearedToPlay);
    final unclearedRecords = records.where((r) => !r.isClearedToPlay).toList();
    final unclearedLabel = unclearedRecords.isNotEmpty
        ? unclearedRecords.map((r) => r.injuryType ?? 'injury').join(', ')
        : 'medical review required';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cleared
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(
            cleared ? Icons.check_circle : Icons.local_hospital_rounded,
            color: cleared ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cleared ? 'Fit to play' : 'Not cleared: $unclearedLabel',
              style: TextStyle(
                fontFamily: 'SFPro',
                fontWeight: FontWeight.w600,
                color: cleared ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ANALYSIS STATS — Per-match history
  // ═══════════════════════════════════════════════════
  List<Map<String, dynamic>> _playerVisibleStats(
    List<Map<String, dynamic>> matchHistory,
  ) {
    return matchHistory
        .where(_hasPlayerBasketballStats)
        .map((row) => Map<String, dynamic>.from(row))
        .toList()
      ..sort((a, b) => _playerRowDate(b).compareTo(_playerRowDate(a)));
  }

  bool _hasPlayerBasketballStats(Map<String, dynamic> row) {
    if ((row['status']?.toString().toUpperCase() ?? '') == 'DNP') {
      return false;
    }
    return _playerBasketballStats.any((stat) {
      final value = row[stat.key];
      return value != null && value.toString().trim().isNotEmpty;
    });
  }

  DateTime _playerRowDate(Map<String, dynamic> row) {
    return DateTime.tryParse(
          '${row['updatedAt'] ?? row['createdAt'] ?? row['eventStartAt'] ?? ''}',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, String>> _buildPlayerBasketballTableRows(
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) {
      return _playerBasketballStats
          .map(
            (stat) => {
              'title': stat.label,
              'lastGame': '-',
              'cumulative': '-',
            },
          )
          .toList();
    }

    final last = rows.first;
    return _playerBasketballStats.map((stat) {
      final cumulative = stat.isMadeAttempt
          ? _sumPlayerMadeAttempt(rows.map((row) => row[stat.key]))
          : stat.isMinutes
              ? _formatPlayerMinutes(
                  rows.fold<int>(
                    0,
                    (sum, row) => sum + _parsePlayerMinutes(row[stat.key]),
                  ),
                )
              : '${rows.fold<int>(0, (sum, row) => sum + _playerAsInt(row[stat.key]))}';
      return {
        'title': stat.label,
        'lastGame': _formatPlayerStatValue(last[stat.key]),
        'cumulative': cumulative,
      };
    }).toList();
  }

  String _formatPlayerStatValue(dynamic value) {
    if (value == null) return '-';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  int _playerAsInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _parsePlayerMinutes(dynamic value) {
    final text = value?.toString().trim() ?? '';
    final parts = text.split(':');
    if (parts.length != 2) return 0;
    final minutes = int.tryParse(parts[0].trim()) ?? 0;
    final seconds = int.tryParse(parts[1].trim()) ?? 0;
    return (minutes * 60) + seconds;
  }

  String _formatPlayerMinutes(int totalSeconds) {
    if (totalSeconds <= 0) return '-';
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _sumPlayerMadeAttempt(Iterable<dynamic> values) {
    var made = 0;
    var attempted = 0;
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      final parts = text.split('/');
      if (parts.length != 2) continue;
      made += int.tryParse(parts[0].trim()) ?? 0;
      attempted += int.tryParse(parts[1].trim()) ?? 0;
    }
    return attempted == 0 ? '-' : '$made/$attempted';
  }

  Widget _buildPlayerStatsCard(
    List<Map<String, dynamic>> matchHistory,
    Member member,
    Color cardBg,
    Color textColor,
    Color subtextColor,
  ) {
    final hasAnalysisPdf =
        member.analysisPdfUrl != null && member.analysisPdfUrl!.isNotEmpty;
    final rows = _playerVisibleStats(matchHistory);

    if (rows.isEmpty && !hasAnalysisPdf) {
      return _buildEmptyCard('No player stats found.', cardBg, subtextColor);
    }

    final tableRows = _buildPlayerBasketballTableRows(rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasAnalysisPdf)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    member.analysisPdfName ?? 'Analysis Report',
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (rows.isNotEmpty) ...[
          Text(
            'PLAYER MATCH STATS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 0.5,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Title',
                    style: TextStyle(color: subtextColor, fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Text(
                      'Last entry',
                      style: TextStyle(color: subtextColor, fontSize: 13),
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Text(
                      'Cumulative',
                      style: TextStyle(color: subtextColor, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...tableRows.map(
            (row) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row['title'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: Text(
                        row['lastGame'] as String,
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: Text(
                        row['cumulative'] as String,
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalysisStatsCard(
    List<Map<String, dynamic>> matchHistory,
    Member member,
    Color cardBg,
    Color textColor,
    Color subtextColor,
  ) {
    // Also check member's analysisPdf
    final hasAnalysisPdf =
        member.analysisPdfUrl != null && member.analysisPdfUrl!.isNotEmpty;

    if (matchHistory.isEmpty && !hasAnalysisPdf) {
      return _buildEmptyCard('No analysis stats found.', cardBg, subtextColor);
    }

    return Column(
      children: [
        if (hasAnalysisPdf)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    member.analysisPdfName ?? 'Analysis Report',
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ...matchHistory.take(5).map((match) {
          final entries = match.entries
              .where(
                (e) => e.value != null && e.value is! Map && e.value is! List,
              )
              .toList();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InfoRow(
                        title: entry.key,
                        value: '${entry.value}',
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // CUMULATIVE STATS
  // ═══════════════════════════════════════════════════
  Widget _buildCumulativeStatsCard(
    Map<String, dynamic> stats,
    Color cardBg,
    Color textColor,
    Color subtextColor,
  ) {
    final entries = stats.entries
        .where((e) => e.value != null && e.value is! Map && e.value is! List)
        .toList();

    if (entries.isEmpty) {
      return _buildEmptyCard(
        'No cumulative stats found.',
        cardBg,
        subtextColor,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
        children: entries
            .map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == entries.last.key ? 0 : 14,
                ),
                child: _InfoRow(
                  title: entry.key,
                  value: '${entry.value}',
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PLAYER VIDEOS
  // ═══════════════════════════════════════════════════
  Widget _buildVideosCard(
    TeamState state,
    Member member,
    Color cardBg,
    Color textColor,
    Color subtextColor,
    bool isAnalyst,
  ) {
    final ctx = _medicalContext(state, member);
    _ensurePlayerVideos(ctx);

    return Column(
      children: [
        if (isAnalyst)
          GestureDetector(
            onTap: (_uploadingVideo || ctx == null)
                ? null
                : () => _showUploadVideoDialog(
                    ctx, cardBg, textColor, subtextColor),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1),
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
                  Icon(
                    _uploadingVideo
                        ? Icons.hourglass_top
                        : Icons.cloud_upload_outlined,
                    color: Colors.green,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _uploadingVideo ? "Uploading..." : "Upload Player Video",
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'SFPro'),
                  ),
                ],
              ),
            ),
          ),
        if (_videosLoading && !_videosLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_playerVideos.isEmpty)
          _buildEmptyCard('No videos found.', cardBg, subtextColor)
        else
          ..._playerVideos.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPlayerVideoTile(
                    ctx, v, cardBg, textColor, subtextColor),
              )),
      ],
    );
  }

  Widget _buildPlayerVideoTile(
    _MedicalContext? ctx,
    PlayerVideoDto video,
    Color cardBg,
    Color textColor,
    Color subtextColor,
  ) {
    return GestureDetector(
      onTap: () => _playPlayerVideo(video),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_circle_fill,
                  color: Colors.green, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title.isNotEmpty
                        ? video.title
                        : (video.originalFileName.isNotEmpty
                            ? video.originalFileName
                            : 'Player Video'),
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    video.addedByName.isNotEmpty
                        ? 'Added by ${video.addedByName}'
                        : 'Tap to view',
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 12,
                      color: subtextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (video.canEdit && ctx != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: subtextColor),
                onPressed: () => _confirmDeletePlayerVideo(ctx, video),
              )
            else
              Icon(Icons.chevron_right, color: subtextColor),
          ],
        ),
      ),
    );
  }

  void _ensurePlayerVideos(_MedicalContext? ctx) {
    if (ctx == null) return;
    final key = '${ctx.clubId}:${ctx.teamId}:${ctx.playerUserId}';
    if (_videosKey == key && (_videosLoaded || _videosLoading)) return;
    _videosKey = key;
    _videosLoading = true;
    _videosLoaded = false;
    _playerVideoService
        .getVideos(ctx.clubId, ctx.teamId, ctx.playerUserId)
        .then((vids) {
      if (!mounted) return;
      setState(() {
        _playerVideos = vids;
        _videosLoading = false;
        _videosLoaded = true;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _playerVideos = [];
        _videosLoading = false;
        _videosLoaded = true;
      });
    });
  }

  Future<void> _playPlayerVideo(PlayerVideoDto video) async {
    final url = await _playerVideoService.authorizedStreamUrl(video);
    if (!mounted) return;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).videoUnavailable)),
      );
      return;
    }
    final headers = await _playerVideoService.streamHeaders();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NetworkVideoPlayerScreen(
          url: url,
          headers: headers,
          title: video.title.isNotEmpty ? video.title : 'Player Video',
        ),
      ),
    );
  }

  Future<void> _confirmDeletePlayerVideo(
      _MedicalContext ctx, PlayerVideoDto video) async {
    final label =
        video.title.isNotEmpty ? video.title : video.originalFileName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).removeVideoTitle),
        content: Text(AppLocalizations.of(context).removeVideoConfirm.replaceAll('%s', label)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text(AppLocalizations.of(context).cancel)),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(AppLocalizations.of(context).remove)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _playerVideoService.deleteVideo(
          ctx.clubId, ctx.teamId, ctx.playerUserId, video.videoId);
      if (!mounted) return;
      setState(() {
        _playerVideos =
            _playerVideos.where((v) => v.videoId != video.videoId).toList();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).videoRemoved)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).videoRemoveError)));
    }
  }

  Future<void> _pickAndUploadPlayerVideo(
      _MedicalContext ctx, String title) async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(type: FileType.video);
    } catch (_) {
      picked = null;
    }
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    

    const maxBytes = 500 * 1024 * 1024;
    if (file.size > maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).videoSizeLimit)),
      );
      return;
    }

    final cleanTitle = title.trim().isNotEmpty
        ? title.trim()
        : file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    setState(() => _uploadingVideo = true);
    try {
      final dto = await _playerVideoService.uploadVideo(
          ctx.clubId,
          ctx.teamId,
          ctx.playerUserId,
          cleanTitle,
          file,
        );
      if (!mounted) return;
      setState(() {
        _playerVideos = [dto, ..._playerVideos];
        _uploadingVideo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).videoUploaded)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingVideo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).videoUploadFailed)),
      );
    }
  }

  void _showUploadVideoDialog(
      _MedicalContext mctx, Color cardBg, Color textColor, Color subtextColor) {
    final TextEditingController captionController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).uploadPlayerVideo,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'SFPro',
                      color: textColor)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPlayerVideo(mctx, captionController.text.trim());
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black12
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_upload_outlined,
                          color: Colors.green, size: 36),
                      const SizedBox(height: 8),
                      Text(AppLocalizations.of(context).selectVideoFile,
                          style: TextStyle(
                              color: textColor, fontWeight: FontWeight.w600, fontFamily: 'SFPro')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: captionController,
                maxLines: 2,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black12
                      : Colors.white,
                  hintText: "Enter a caption...",
                  hintStyle:
                      TextStyle(color: textColor.withValues(alpha: 0.4)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: Colors.green.withValues(alpha: 0.3))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: Colors.green.withValues(alpha: 0.3))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Colors.green, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(
                          color: Colors.green.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppLocalizations.of(context).cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickAndUploadPlayerVideo(
                            mctx, captionController.text.trim());
                      },
                      icon: const Icon(Icons.upload, size: 18),
                      label: Text(AppLocalizations.of(context).upload),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // EMPTY CARD
  // ═══════════════════════════════════════════════════
  Widget _buildEmptyCard(String text, Color cardBg, Color subtextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'SFPro',
            color: subtextColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(message, style: TextStyle(color: textColor)),
      ),
    );
  }

  Widget _buildPlayerMenu(BuildContext context, TeamState state, Member currentMember, bool isManager) {
    if (!isManager) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    final currentUserId =
        context.read<SessionBloc>().state.user?.userId ?? state.currentUserId;
    final isOwnProfile = currentMember.userId == currentUserId;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: textColor),
      onSelected: (value) {
        if (value == 'edit') {
          _showEditPlayerDialog(context, state, currentMember);
        } else if (value == 'kick') {
          _showKickPlayerDialog(context, state, currentMember);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'edit', child: Text(AppLocalizations.of(context).edit ?? 'Edit Info')),
        if (!isOwnProfile)
          PopupMenuItem(value: 'kick', child: Text(AppLocalizations.of(context).remove ?? 'Remove from Team')),
      ],
    );
  }

  void _showEditPlayerDialog(BuildContext context, TeamState state, Member member) {
    final positionController = TextEditingController(text: member.position);
    final jerseyController = TextEditingController(text: member.jerseyNumber?.toString() ?? '');
    
    final selectedTeams = state.availableTeams.where((t) => t.id == state.selectedTeamId);
    final clubId = selectedTeams.isEmpty ? null : selectedTeams.first.clubId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Player Info', style: TextStyle(fontFamily: 'SFPro')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: positionController,
              decoration: const InputDecoration(labelText: 'Position'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: jerseyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jersey Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () async {
              if (clubId == null) return;
              Navigator.pop(ctx);
              
              try {
                await _playerService.upsertPlayerProfile(
                  clubId,
                  state.selectedTeamId,
                  member.userId,
                  {
                    'position': positionController.text,
                    'jerseyNumber': int.tryParse(jerseyController.text),
                  },
                );

                if (!context.mounted) return;
                // Reload the profile
                setState(() {
                  _bundleKey = '';
                });
                context.read<TeamBloc>().add(
                  LoadTeamMembers(activeTeamId: state.selectedTeamId),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update player info: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showKickPlayerDialog(BuildContext context, TeamState state, Member member) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final selectedTeams = state.availableTeams.where((t) => t.id == state.selectedTeamId);
    final clubId = selectedTeams.isEmpty ? null : selectedTeams.first.clubId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(
          'Remove Player',
          style: TextStyle(color: textColor, fontFamily: 'SFPro'),
        ),
        content: Text(
          'Are you sure you want to remove ${member.name} from the team?',
          style: TextStyle(color: textColor, fontFamily: 'SFPro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              if (clubId == null) return;
              Navigator.pop(ctx);
              context.read<TeamBloc>().add(
                RemoveMember(
                  clubId: clubId,
                  teamId: state.selectedTeamId,
                  memberId: member.userId,
                ),
              );
              Navigator.pop(context); // Go back from profile after kicking
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════

class _BiometricMetric {
  final String key;
  final String label;
  final String inputLabel;
  final String latestValue;
  final List<MapEntry<String, String>> history;

  const _BiometricMetric({
    required this.key,
    required this.label,
    required this.inputLabel,
    required this.latestValue,
    required this.history,
  });
}

class _BiometricDropdownField extends StatefulWidget {
  final _BiometricMetric metric;
  final Color cardBg;
  final Color textColor;
  final Color subtextColor;
  final bool canManageFitness;
  final bool isSaving;
  final VoidCallback onUpdate;

  const _BiometricDropdownField({
    super.key,
    required this.metric,
    required this.cardBg,
    required this.textColor,
    required this.subtextColor,
    required this.canManageFitness,
    required this.isSaving,
    required this.onUpdate,
  });

  @override
  State<_BiometricDropdownField> createState() =>
      _BiometricDropdownFieldState();
}

class _BiometricDropdownFieldState extends State<_BiometricDropdownField> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final lastUpdateDate = widget.metric.history.isNotEmpty
        ? widget.metric.history.first.key
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.metric.label,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  color: widget.subtextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (lastUpdateDate != null)
                              Text(
                                lastUpdateDate,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  color: widget.subtextColor,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.metric.latestValue,
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontWeight: FontWeight.w700,
                            color: widget.textColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _expanded ? Colors.green : widget.subtextColor,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  if (widget.metric.history.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history,
                            size: 14,
                            color: widget.subtextColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Update History',
                            style: TextStyle(
                              fontFamily: 'SFPro',
                              color: widget.subtextColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.metric.history.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No history yet.',
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          color: widget.subtextColor,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ...widget.metric.history.asMap().entries.map((entry) {
                      final index = entry.key;
                      final historyEntry = entry.value;
                      final isLatest = index == 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isLatest
                                    ? Colors.green
                                    : (isDark
                                          ? Colors.white24
                                          : Colors.grey.shade400),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                historyEntry.key,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontSize: 13,
                                  color: widget.subtextColor,
                                  fontWeight: isLatest
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            Text(
                              historyEntry.value,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isLatest
                                    ? widget.textColor
                                    : widget.subtextColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  if (widget.canManageFitness) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedButton.primary(child: ElevatedButton.icon(
                        onPressed: widget.isSaving ? null : widget.onUpdate,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text(
                          'Update',
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      )),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

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
        Flexible(
          flex: 2,
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'SFPro',
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: 'SFPro',
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

const List<_PlayerBasketballStatDef> _playerBasketballStats = [
  _PlayerBasketballStatDef('points', 'Points'),
  _PlayerBasketballStatDef('totalRebounds', 'Total Rebounds'),
  _PlayerBasketballStatDef('offensiveRebounds', 'Offensive Rebounds'),
  _PlayerBasketballStatDef('defensiveRebounds', 'Defensive Rebounds'),
  _PlayerBasketballStatDef('basketballAssists', 'Assists'),
  _PlayerBasketballStatDef('steals', 'Steals'),
  _PlayerBasketballStatDef('blocks', 'Blocks'),
  _PlayerBasketballStatDef('turnovers', 'Turnovers'),
  _PlayerBasketballStatDef('personalFouls', 'Personal Fouls'),
  _PlayerBasketballStatDef('foulsDrawn', 'Fouls Drawn'),
  _PlayerBasketballStatDef('efficiency', 'Efficiency'),
  _PlayerBasketballStatDef('minutes', 'Minutes', isMinutes: true),
  _PlayerBasketballStatDef(
    'twoPtMA',
    '2-Point Field Goals',
    isMadeAttempt: true,
  ),
  _PlayerBasketballStatDef(
    'threePtMA',
    '3-Point Field Goals',
    isMadeAttempt: true,
  ),
  _PlayerBasketballStatDef('ftMA', 'Free Throws', isMadeAttempt: true),
];

class _PlayerBasketballStatDef {
  final String key;
  final String label;
  final bool isMadeAttempt;
  final bool isMinutes;

  const _PlayerBasketballStatDef(
    this.key,
    this.label, {
    this.isMadeAttempt = false,
    this.isMinutes = false,
  });
}

class _PlayerBundle {
  final PlayerProfileDto? profile;
  final List<FitnessRecordDto> fitness;
  final List<MedicalRecordDto> medical;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> matchHistory;

  const _PlayerBundle({
    this.profile,
    this.fitness = const [],
    this.medical = const [],
    this.stats = const {},
    this.matchHistory = const [],
  });

  _PlayerBundle copyWith({
    PlayerProfileDto? profile,
    List<FitnessRecordDto>? fitness,
    List<MedicalRecordDto>? medical,
    Map<String, dynamic>? stats,
    List<Map<String, dynamic>>? matchHistory,
  }) {
    return _PlayerBundle(
      profile: profile ?? this.profile,
      fitness: fitness ?? this.fitness,
      medical: medical ?? this.medical,
      stats: stats ?? this.stats,
      matchHistory: matchHistory ?? this.matchHistory,
    );
  }
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

// ═══════════════════════════════════════════════════
// MEDICAL ACTION SLIDER (same-side edit + delete)
// ═══════════════════════════════════════════════════

class _MedicalActionSlider extends StatefulWidget {
  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool enabled;

  const _MedicalActionSlider({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
    this.enabled = true,
  });

  @override
  State<_MedicalActionSlider> createState() => _MedicalActionSliderState();
}

class _MedicalActionSliderState extends State<_MedicalActionSlider> {
  static const double _actionWidth = 152;
  double _offset = 0;

  bool get _isOpen => _offset <= -_actionWidth / 2;

  void _snap({required bool open}) {
    setState(() => _offset = open ? -_actionWidth : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: widget.enabled
              ? (details) {
                  setState(() {
                    _offset = (_offset + details.delta.dx).clamp(
                      -_actionWidth,
                      0,
                    );
                  });
                }
              : null,
          onHorizontalDragEnd: widget.enabled
              ? (_) => _snap(open: _isOpen)
              : null,
          onTap: _offset == 0 ? null : () => _snap(open: false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ),
        if (_offset < 0)
          Positioned.fill(
            bottom: 12,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: -_offset,
                  child: Row(
                    children: [
                      Expanded(
                        child: _MedicalActionButton(
                          color: Colors.blue,
                          icon: Icons.edit_rounded,
                          label: AppLocalizations.of(context).edit,
                          onTap: () {
                            _snap(open: false);
                            widget.onEdit();
                          },
                        ),
                      ),
                      Expanded(
                        child: _MedicalActionButton(
                          color: Colors.red,
                          icon: Icons.delete_rounded,
                          label: AppLocalizations.of(context).delete,
                          onTap: () {
                            _snap(open: false);
                            widget.onDelete();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MedicalActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MedicalActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'SFPro',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
