import 'dart:convert';
import 'package:eqq/core/responsive_system.dart';

import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/app_transitions.dart';
import '../core/responsive_widgets.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../models/api_models.dart';
import '../core/app_localizations.dart';

// ──────────────────────────────────────────────────────────────────────────────
// AddPlanScreen
// ──────────────────────────────────────────────────────────────────────────────

class AddPlanScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialDescription;
  final String? initialVisibility;
  final String? initialCategory;
  final String? initialTacticalBoardData;
  final List<PlanDocumentDto> initialDocuments;
  final bool isEditing;

  const AddPlanScreen({
    super.key,
    this.initialTitle,
    this.initialDescription,
    this.initialVisibility,
    this.initialCategory,
    this.initialTacticalBoardData,
    this.initialDocuments = const [],
    this.isEditing = false,
  });

  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen>
    with TickerProviderStateMixin, SmoothKeyboardMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _visibility = 'Draft';
  String _category = 'Offensive';

  final List<PlatformFile> _attachedFiles = [];
  final List<PlanDocumentDto> _existingDocuments = [];
  final Set<String> _discardedDocumentIds = {};
  List<_CourtPlayer> _courtPlayers = [];
  List<_DrawnArrow> _drawnArrows = [];
  List<_TacticalPreset> _savedPlays = [];

  static const String _savedPlaysKey = 'add_plan_saved_tactical_plays';

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? '';
    _descriptionController.text = widget.initialDescription ?? '';
    _visibility = widget.initialVisibility ?? 'Draft';
    _category = widget.initialCategory ?? 'Offensive';
    _existingDocuments.addAll(widget.initialDocuments);
    _courtPlayers = _TacticalPresets.defaultFormation();
    _applyInitialBoardData(widget.initialTacticalBoardData);
    _loadSavedPlays();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPlays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedPlaysKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final plays = decoded
          .whereType<Map>()
          .map(
            (item) => _tacticalPresetFromJson(Map<String, dynamic>.from(item)),
          )
          .whereType<_TacticalPreset>()
          .toList();
      if (!mounted) return;
      setState(() => _savedPlays = plays);
    } catch (_) {}
  }

  Future<void> _persistSavedPlays() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedPlaysKey,
      jsonEncode(_savedPlays.map(_tacticalPresetToJson).toList()),
    );
  }

  void _applyInitialBoardData(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      final players =
          (data['players'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => _courtPlayerFromJson(Map<String, dynamic>.from(item)),
              )
              .whereType<_CourtPlayer>()
              .toList() ??
          const [];
      final arrows =
          (data['arrows'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => _drawnArrowFromJson(Map<String, dynamic>.from(item)),
              )
              .whereType<_DrawnArrow>()
              .toList() ??
          const [];
      if (players.isNotEmpty) _courtPlayers = players;
      _drawnArrows = arrows;
    } catch (_) {}
  }

  // ── file picker ───────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _attachedFiles.addAll(result.files));
    }
  }

  void _removeFile(int index) => setState(() => _attachedFiles.removeAt(index));

  void _discardExistingDocument(PlanDocumentDto doc) {
    setState(() {
      _discardedDocumentIds.add(doc.documentId);
      _existingDocuments.removeWhere((d) => d.documentId == doc.documentId);
    });
  }

  void _loadTacticalPreset(_TacticalPreset preset) {
    setState(() {
      _courtPlayers = _cloneCourtPlayers(preset.players);
      _drawnArrows = _cloneDrawnArrows(preset.arrows);
    });
  }

  void _saveCurrentPlay(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final preset = _TacticalPreset(
      name: cleanName,
      description:
          'Custom ${_category.toLowerCase()} play with ${_drawnArrows.length} action${_drawnArrows.length == 1 ? '' : 's'}.',
      players: _cloneCourtPlayers(_courtPlayers),
      arrows: _cloneDrawnArrows(_drawnArrows),
      isCustom: true,
    );
    setState(() => _savedPlays = [preset, ..._savedPlays]);
    _persistSavedPlays();
  }

  void _syncSavedPlays(List<_TacticalPreset> plays) {
    setState(() => _savedPlays = _cloneTacticalPresets(plays));
    _persistSavedPlays();
  }

  Future<void> _openFullScreenBoard() async {
    await Navigator.of(context).push(
      AppPageRoute(
        child: _FullScreenTacticalBoardPage(
          category: _category,
          players: _courtPlayers,
          arrows: _drawnArrows,
          savedPlays: _savedPlays,
          onPlayersChanged: (players) {
            setState(() => _courtPlayers = _cloneCourtPlayers(players));
          },
          onArrowsChanged: (arrows) {
            setState(() => _drawnArrows = _cloneDrawnArrows(arrows));
          },
          onSavedPlaysChanged: _syncSavedPlays,
        ),
      ),
    );
  }

  // ── serialise board ───────────────────────────────────────────────────────

  String _serialiseBoard() {
    final data = {
      'players': _courtPlayers.map(_courtPlayerToJson).toList(),
      'arrows': _drawnArrows.map(_drawnArrowToJson).toList(),
    };
    return jsonEncode(data);
  }

  // ── submit ────────────────────────────────────────────────────────────────

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.addPlansTitleReq)));
      return;
    }
    Navigator.pop(context, {
      'title': title,
      'description': _descriptionController.text.trim(),
      'visibility': _visibility,
      'category': _category,
      'attachments': _attachedFiles,
      'discardedDocumentIds': _discardedDocumentIds.toList(),
      'tacticalBoardData': _serialiseBoard(),
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    updateKeyboardHeight(MediaQuery.viewInsetsOf(context).bottom);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final labelColor = isDark ? Colors.white70 : null;
    final textColor = isDark ? Colors.white : Colors.black;
    final pagePadding = ResponsiveSystem.pagePadding(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: CustomAppBar(
        title: widget.isEditing ? AppLocalizations.of(context).addPlansEditPlan : AppLocalizations.of(context).addPlansAddPlan,
        onBack: () => Navigator.pop(context),
        showTeamSwitcher: true,
      ),
      body: buildKeyboardDismissible(
        child: AppBackground(
        child: SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: pagePadding.copyWith(
                bottom: pagePadding.bottom + smoothKeyboardHeight + 24,
              ),
              children: [
                const SizedBox(height: 18),
                // ── Title ─────────────────────────────────────────────
                TextField(
                  controller: _titleController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: fieldColor,
                    labelText: AppLocalizations.of(context).addPlansTitle,
                    labelStyle: TextStyle(color: labelColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Category toggle ───────────────────────────────────
                _buildCategoryToggle(isDark, textColor, fieldColor),
                const SizedBox(height: 16),

                // ── Tactical Board ────────────────────────────────────
                _buildTacticalBoardSection(isDark, textColor, fieldColor),
                const SizedBox(height: 16),

                // ── Description ───────────────────────────────────────
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: fieldColor,
                    labelText: AppLocalizations.of(context).addPlansDesc,
                    labelStyle: TextStyle(color: labelColor),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Attachments ───────────────────────────────────────
                _buildAttachmentsSection(isDark, textColor, fieldColor),
                const SizedBox(height: 20),

                // ── Visibility toggle ─────────────────────────────────
                _buildVisibilityToggle(isDark, textColor, fieldColor),
                const SizedBox(height: 24),

                // ── Submit ────────────────────────────────────────────
                AnimatedButton.primary(
                  child: ResponsivePrimaryButton(
                    context: context,
                    label: widget.isEditing ? AppLocalizations.of(context).addPlansSavePlanBtn : AppLocalizations.of(context).addPlansAddPlanBtn,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Category toggle (compact, app-green) ──────────────────────────────────

  Widget _buildCategoryToggle(bool isDark, Color textColor, Color fieldColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          _toggleOption(AppLocalizations.of(context).addPlansOffensive, 'Offensive', Icons.sports_basketball, isDark),
          _toggleOption(AppLocalizations.of(context).addPlansDefensive, 'Defensive', Icons.shield, isDark),
        ],
      ),
    );
  }

  Widget _toggleOption(String label, String value, IconData icon, bool isDark) {
    final selected = _category == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _category = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white54 : Colors.grey),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white54 : Colors.grey.shade600),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontFamily: 'SFPro',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityToggle(
    bool isDark,
    Color textColor,
    Color fieldColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            AppLocalizations.of(context).addPlansVisibility,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontFamily: 'SFPro',
              fontSize: 15,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              _visibilityOption(AppLocalizations.of(context).addPlansOnlyMe, 'Draft', Icons.lock_outline, isDark),
              _visibilityOption(
                AppLocalizations.of(context).addPlansTeam,
                'TeamVisible',
                Icons.groups_rounded,
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _visibilityOption(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    final selected = _visibility == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _visibility = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white54 : Colors.grey),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white54 : Colors.grey.shade600),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    fontFamily: 'SFPro',
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Attachments section ───────────────────────────────────────────────────

  Widget _buildAttachmentsSection(
    bool isDark,
    Color textColor,
    Color fieldColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            AppLocalizations.of(context).addPlansAttachments,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontFamily: 'SFPro',
              fontSize: 15,
            ),
          ),
        ),
        if (_existingDocuments.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              AppLocalizations.of(context).addPlansUploadedDocs,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontWeight: FontWeight.w500,
                fontFamily: 'SFPro',
                fontSize: 13,
              ),
            ),
          ),
          ...List.generate(_existingDocuments.length, (i) {
            final doc = _existingDocuments[i];
            final ext = doc.fileName.contains('.')
                ? doc.fileName.split('.').last.toLowerCase()
                : '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.12)
                    : Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white10
                      : Colors.green.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Icon(_fileIcon(ext), size: 28, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'SFPro',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doc.fileSizeBytes == null
                              ? AppLocalizations.of(context).addPlansUploaded
                              : _formatFileSize(doc.fileSizeBytes!),
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey,
                            fontFamily: 'SFPro',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _discardExistingDocument(doc),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(
                      AppLocalizations.of(context).addPlansDiscard,
                      style: const TextStyle(
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
        if (_attachedFiles.isEmpty)
            _AttachmentDropZone(isDark: isDark, onTap: _pickFiles)
          else ...[
            _AttachmentDropZone(
              isDark: isDark,
              compact: true,
              onTap: _pickFiles,
            ),
            const SizedBox(height: 10),
            ...List.generate(_attachedFiles.length, (i) {
              final file = _attachedFiles[i];
              final ext = file.extension?.toLowerCase() ?? '';
              return Container(
                margin: EdgeInsets.only(
                  bottom: i == _attachedFiles.length - 1 ? 0 : 8,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.12)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_fileIcon(ext), size: 28, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'SFPro',
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatFileSize(file.size),
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey,
                              fontFamily: 'SFPro',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedButton.icon(
                      child: IconButton(
                        onPressed: () => _removeFile(i),
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.redAccent,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
      ],
    );
  }
  // ── Tactical Board section ────────────────────────────────────────────────

  Widget _buildTacticalBoardSection(
    bool isDark,
    Color textColor,
    Color fieldColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.sports_basketball,
                    size: 20,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).addPlansTacticalBoard,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'SFPro',
                        fontSize: 15,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openFullScreenBoard,
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(
                      AppLocalizations.of(context).addPlansEdit,
                      style: const TextStyle(fontFamily: 'SFPro', fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BasketballTacticalBoard(
                players: _courtPlayers,
                arrows: _drawnArrows,
                onPlayersChanged: (p) => setState(() => _courtPlayers = p),
                onArrowsChanged: (a) => setState(() => _drawnArrows = a),
                onLoadPreset: _loadTacticalPreset,
                savedPlays: _savedPlays,
                onSaveCurrentPlay: _saveCurrentPlay,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── utils ─────────────────────────────────────────────────────────────────

  static IconData _fileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}

class _FullScreenTacticalBoardPage extends StatefulWidget {
  final String category;
  final List<_CourtPlayer> players;
  final List<_DrawnArrow> arrows;
  final List<_TacticalPreset> savedPlays;
  final ValueChanged<List<_CourtPlayer>> onPlayersChanged;
  final ValueChanged<List<_DrawnArrow>> onArrowsChanged;
  final ValueChanged<List<_TacticalPreset>> onSavedPlaysChanged;

  const _FullScreenTacticalBoardPage({
    required this.category,
    required this.players,
    required this.arrows,
    required this.savedPlays,
    required this.onPlayersChanged,
    required this.onArrowsChanged,
    required this.onSavedPlaysChanged,
  });

  @override
  State<_FullScreenTacticalBoardPage> createState() =>
      _FullScreenTacticalBoardPageState();
}

class _AttachmentDropZone extends StatelessWidget {
  final bool isDark;
  final bool compact;
  final VoidCallback onTap;

  const _AttachmentDropZone({
    required this.isDark,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: compact ? 16 : 42),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B3A2D) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: compact ? 28 : 46,
                color: Colors.green.withValues(alpha: isDark ? 0.8 : 1.0),
              ),
              if (!compact) ...[
                const SizedBox(height: 18),
                Text(
                  AppLocalizations.of(context).addPlansTapToAttach,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontFamily: 'SFPro',
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).addPlansTapToAddAnother,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontFamily: 'SFPro',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenTacticalBoardPageState
    extends State<_FullScreenTacticalBoardPage> {
  late List<_CourtPlayer> _players;
  late List<_DrawnArrow> _arrows;
  late List<_TacticalPreset> _savedPlays;

  @override
  void initState() {
    super.initState();
    _players = _cloneCourtPlayers(widget.players);
    _arrows = _cloneDrawnArrows(widget.arrows);
    _savedPlays = _cloneTacticalPresets(widget.savedPlays);
  }

  void _setPlayers(List<_CourtPlayer> players) {
    final copy = _cloneCourtPlayers(players);
    _players = copy;
    widget.onPlayersChanged(copy);
  }

  void _setArrows(List<_DrawnArrow> arrows) {
    final copy = _cloneDrawnArrows(arrows);
    setState(() => _arrows = copy);
    widget.onArrowsChanged(copy);
  }

  void _loadPreset(_TacticalPreset preset) {
    _setPlayers(preset.players);
    _setArrows(preset.arrows);
  }

  void _saveCurrentPlay(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final preset = _TacticalPreset(
      name: cleanName,
      description:
          'Custom ${widget.category.toLowerCase()} play with ${_arrows.length} action${_arrows.length == 1 ? '' : 's'}.',
      players: _cloneCourtPlayers(_players),
      arrows: _cloneDrawnArrows(_arrows),
      isCustom: true,
    );
    final updated = [preset, ..._savedPlays];
    setState(() => _savedPlays = updated);
    widget.onSavedPlaysChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColors = isDark
        ? [const Color(0xFF0A1F15), const Color(0xFF020806)]
        : [const Color(0xFF2E7D32), const Color(0xFFF6FFF8)];

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: CustomAppBar(
        title: AppLocalizations.of(context).addPlansTacticalBoard,
        onBack: () => Navigator.pop(context),
        showTeamSwitcher: false,
      ),
      body: AppBackground(
        child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: _BasketballTacticalBoard(
                players: _players,
                arrows: _arrows,
                onPlayersChanged: _setPlayers,
                onArrowsChanged: _setArrows,
                onLoadPreset: _loadPreset,
                savedPlays: _savedPlays,
                onSaveCurrentPlay: _saveCurrentPlay,
                isFullScreen: true,
              ),
            ),
          ),
        ),
      );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Data classes
// ═══════════════════════════════════════════════════════════════════════════════

class _CourtPlayer {
  final String id;
  final String label;
  final double x; // 0..1 normalised
  final double y; // 0..1 normalised
  final bool isHome;

  const _CourtPlayer({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.isHome,
  });

  _CourtPlayer copyWith({String? label, double? x, double? y}) => _CourtPlayer(
    id: id,
    label: label ?? this.label,
    x: x ?? this.x,
    y: y ?? this.y,
    isHome: isHome,
  );
}

class _DrawnArrow {
  final Offset start;
  final Offset end;

  /// Intermediate points collected during freehand drawing for a smooth curve.
  final List<Offset> points;
  const _DrawnArrow({
    required this.start,
    required this.end,
    this.points = const [],
  });
}

class _TacticalPreset {
  final String name;
  final String description;
  final List<_CourtPlayer> players;
  final List<_DrawnArrow> arrows;
  final bool isCustom;
  const _TacticalPreset({
    required this.name,
    required this.description,
    required this.players,
    required this.arrows,
    this.isCustom = false,
  });
}

List<_CourtPlayer> _cloneCourtPlayers(List<_CourtPlayer> players) => players
    .map(
      (p) => _CourtPlayer(
        id: p.id,
        label: p.label,
        x: p.x,
        y: p.y,
        isHome: p.isHome,
      ),
    )
    .toList();

List<_DrawnArrow> _cloneDrawnArrows(List<_DrawnArrow> arrows) => arrows
    .map(
      (a) => _DrawnArrow(
        start: a.start,
        end: a.end,
        points: List<Offset>.of(a.points),
      ),
    )
    .toList();

List<_TacticalPreset> _cloneTacticalPresets(List<_TacticalPreset> plays) =>
    plays
        .map(
          (p) => _TacticalPreset(
            name: p.name,
            description: p.description,
            players: _cloneCourtPlayers(p.players),
            arrows: _cloneDrawnArrows(p.arrows),
            isCustom: p.isCustom,
          ),
        )
        .toList();

Map<String, dynamic> _courtPlayerToJson(_CourtPlayer player) => {
  'id': player.id,
  'label': player.label,
  'x': player.x,
  'y': player.y,
  'isHome': player.isHome,
};

_CourtPlayer? _courtPlayerFromJson(Map<String, dynamic> json) {
  final id = json['id']?.toString();
  final label = json['label']?.toString();
  final x = (json['x'] as num?)?.toDouble();
  final y = (json['y'] as num?)?.toDouble();
  final isHome = json['isHome'] as bool?;
  if (id == null || label == null || x == null || y == null || isHome == null) {
    return null;
  }
  return _CourtPlayer(id: id, label: label, x: x, y: y, isHome: isHome);
}

Map<String, dynamic> _drawnArrowToJson(_DrawnArrow arrow) => {
  'startX': arrow.start.dx,
  'startY': arrow.start.dy,
  'endX': arrow.end.dx,
  'endY': arrow.end.dy,
  'points': arrow.points
      .map((point) => {'x': point.dx, 'y': point.dy})
      .toList(),
};

_DrawnArrow? _drawnArrowFromJson(Map<String, dynamic> json) {
  final startX = (json['startX'] as num?)?.toDouble();
  final startY = (json['startY'] as num?)?.toDouble();
  final endX = (json['endX'] as num?)?.toDouble();
  final endY = (json['endY'] as num?)?.toDouble();
  if (startX == null || startY == null || endX == null || endY == null) {
    return null;
  }
  final points =
      (json['points'] as List?)
          ?.whereType<Map>()
          .map((item) {
            final point = Map<String, dynamic>.from(item);
            final x = (point['x'] as num?)?.toDouble();
            final y = (point['y'] as num?)?.toDouble();
            if (x == null || y == null) return null;
            return Offset(x, y);
          })
          .whereType<Offset>()
          .toList() ??
      const <Offset>[];
  return _DrawnArrow(
    start: Offset(startX, startY),
    end: Offset(endX, endY),
    points: points,
  );
}

Map<String, dynamic> _tacticalPresetToJson(_TacticalPreset preset) => {
  'name': preset.name,
  'description': preset.description,
  'players': preset.players.map(_courtPlayerToJson).toList(),
  'arrows': preset.arrows.map(_drawnArrowToJson).toList(),
  'isCustom': preset.isCustom,
};

_TacticalPreset? _tacticalPresetFromJson(Map<String, dynamic> json) {
  final name = json['name']?.toString();
  final description = json['description']?.toString();
  if (name == null || description == null) return null;
  final players =
      (json['players'] as List?)
          ?.whereType<Map>()
          .map((item) => _courtPlayerFromJson(Map<String, dynamic>.from(item)))
          .whereType<_CourtPlayer>()
          .toList() ??
      const <_CourtPlayer>[];
  if (players.isEmpty) return null;
  final arrows =
      (json['arrows'] as List?)
          ?.whereType<Map>()
          .map((item) => _drawnArrowFromJson(Map<String, dynamic>.from(item)))
          .whereType<_DrawnArrow>()
          .toList() ??
      const <_DrawnArrow>[];
  return _TacticalPreset(
    name: name,
    description: description,
    players: players,
    arrows: arrows,
    isCustom: json['isCustom'] == true,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tactical presets — including Knicks-style plays
// ═══════════════════════════════════════════════════════════════════════════════

class _TacticalPresets {
  static List<_CourtPlayer> defaultFormation() => [
    const _CourtPlayer(id: 'H1', label: 'PG', x: 0.46, y: 0.80, isHome: true),
    const _CourtPlayer(id: 'H2', label: 'SG', x: 0.18, y: 0.65, isHome: true),
    const _CourtPlayer(id: 'H3', label: 'SF', x: 0.74, y: 0.65, isHome: true),
    const _CourtPlayer(id: 'H4', label: 'PF', x: 0.28, y: 0.46, isHome: true),
    const _CourtPlayer(id: 'H5', label: 'C', x: 0.64, y: 0.46, isHome: true),
    const _CourtPlayer(id: 'A1', label: '1', x: 0.46, y: 0.28, isHome: false),
    const _CourtPlayer(id: 'A2', label: '2', x: 0.18, y: 0.36, isHome: false),
    const _CourtPlayer(id: 'A3', label: '3', x: 0.74, y: 0.36, isHome: false),
    const _CourtPlayer(id: 'A4', label: '4', x: 0.30, y: 0.18, isHome: false),
    const _CourtPlayer(id: 'A5', label: '5', x: 0.62, y: 0.18, isHome: false),
  ];

  /// Knicks-style Triangle Offense — ball-side triangle with strong post play.
  static _TacticalPreset knicksTriangleOffense() => _TacticalPreset(
    name: 'Triangle Offense',
    description:
        'Knicks signature: PG initiates from the wing, C in the low post, '
        'PF at the elbow. Creates read-and-react triangles on the strong side.',
    players: [
      const _CourtPlayer(id: 'H1', label: 'PG', x: 0.22, y: 0.72, isHome: true),
      const _CourtPlayer(id: 'H2', label: 'SG', x: 0.72, y: 0.72, isHome: true),
      const _CourtPlayer(id: 'H3', label: 'SF', x: 0.50, y: 0.56, isHome: true),
      const _CourtPlayer(id: 'H4', label: 'PF', x: 0.35, y: 0.38, isHome: true),
      const _CourtPlayer(id: 'H5', label: 'C', x: 0.24, y: 0.26, isHome: true),
      const _CourtPlayer(id: 'A1', label: '1', x: 0.24, y: 0.60, isHome: false),
      const _CourtPlayer(id: 'A2', label: '2', x: 0.70, y: 0.60, isHome: false),
      const _CourtPlayer(id: 'A3', label: '3', x: 0.50, y: 0.44, isHome: false),
      const _CourtPlayer(id: 'A4', label: '4', x: 0.36, y: 0.28, isHome: false),
      const _CourtPlayer(id: 'A5', label: '5', x: 0.26, y: 0.18, isHome: false),
    ],
    arrows: [
      // PG entry pass to SF at the wing
      const _DrawnArrow(start: Offset(0.26, 0.72), end: Offset(0.47, 0.56)),
      // SF feeds C in the post
      const _DrawnArrow(start: Offset(0.50, 0.54), end: Offset(0.28, 0.28)),
      // PF cuts to the basket
      const _DrawnArrow(start: Offset(0.35, 0.38), end: Offset(0.45, 0.18)),
    ],
  );

  /// Knicks-style Pick and Roll — Brunson / Hartenstein style.
  static _TacticalPreset knicksPickAndRoll() => _TacticalPreset(
    name: 'Pick & Roll',
    description:
        'High pick-and-roll: PG uses C screen at the top of the key, '
        'roll man dives to the rim. Shooters space the corners.',
    players: [
      const _CourtPlayer(id: 'H1', label: 'PG', x: 0.46, y: 0.78, isHome: true),
      const _CourtPlayer(id: 'H2', label: 'SG', x: 0.10, y: 0.68, isHome: true),
      const _CourtPlayer(id: 'H3', label: 'SF', x: 0.82, y: 0.68, isHome: true),
      const _CourtPlayer(id: 'H4', label: 'PF', x: 0.78, y: 0.40, isHome: true),
      const _CourtPlayer(id: 'H5', label: 'C', x: 0.46, y: 0.56, isHome: true),
      const _CourtPlayer(id: 'A1', label: '1', x: 0.46, y: 0.66, isHome: false),
      const _CourtPlayer(id: 'A2', label: '2', x: 0.12, y: 0.58, isHome: false),
      const _CourtPlayer(id: 'A3', label: '3', x: 0.80, y: 0.58, isHome: false),
      const _CourtPlayer(id: 'A4', label: '4', x: 0.76, y: 0.32, isHome: false),
      const _CourtPlayer(id: 'A5', label: '5', x: 0.46, y: 0.44, isHome: false),
    ],
    arrows: [
      // PG drives off the screen
      const _DrawnArrow(start: Offset(0.46, 0.76), end: Offset(0.32, 0.50)),
      // C rolls to the basket
      const _DrawnArrow(start: Offset(0.46, 0.54), end: Offset(0.46, 0.22)),
      // Kick-out option to corner SG
      const _DrawnArrow(start: Offset(0.34, 0.50), end: Offset(0.12, 0.68)),
    ],
  );

  /// Knicks-style Isolation (Brunson mid-range iso).
  static _TacticalPreset knicksIsolation() => _TacticalPreset(
    name: 'Isolation Play',
    description:
        'Clear-out isolation: PG operates one-on-one in space, '
        'bigs pin down on the weak side, shooters stretch the floor.',
    players: [
      const _CourtPlayer(id: 'H1', label: 'PG', x: 0.46, y: 0.74, isHome: true),
      const _CourtPlayer(id: 'H2', label: 'SG', x: 0.84, y: 0.50, isHome: true),
      const _CourtPlayer(id: 'H3', label: 'SF', x: 0.84, y: 0.72, isHome: true),
      const _CourtPlayer(id: 'H4', label: 'PF', x: 0.12, y: 0.40, isHome: true),
      const _CourtPlayer(id: 'H5', label: 'C', x: 0.12, y: 0.58, isHome: true),
      const _CourtPlayer(id: 'A1', label: '1', x: 0.46, y: 0.62, isHome: false),
      const _CourtPlayer(id: 'A2', label: '2', x: 0.82, y: 0.42, isHome: false),
      const _CourtPlayer(id: 'A3', label: '3', x: 0.82, y: 0.62, isHome: false),
      const _CourtPlayer(id: 'A4', label: '4', x: 0.14, y: 0.32, isHome: false),
      const _CourtPlayer(id: 'A5', label: '5', x: 0.14, y: 0.48, isHome: false),
    ],
    arrows: [
      // PG drives to the mid-range
      const _DrawnArrow(start: Offset(0.46, 0.72), end: Offset(0.40, 0.44)),
    ],
  );

  /// Knicks-style Pinch Post / Elbow action.
  static _TacticalPreset knicksPinchPost() => _TacticalPreset(
    name: 'Pinch Post (Elbow)',
    description:
        'PF catches at the elbow, PG and SG cut off the post. '
        'Creates backdoor and mid-range opportunities.',
    players: [
      const _CourtPlayer(id: 'H1', label: 'PG', x: 0.30, y: 0.76, isHome: true),
      const _CourtPlayer(id: 'H2', label: 'SG', x: 0.66, y: 0.76, isHome: true),
      const _CourtPlayer(id: 'H3', label: 'SF', x: 0.84, y: 0.54, isHome: true),
      const _CourtPlayer(id: 'H4', label: 'PF', x: 0.36, y: 0.42, isHome: true),
      const _CourtPlayer(id: 'H5', label: 'C', x: 0.56, y: 0.24, isHome: true),
      const _CourtPlayer(id: 'A1', label: '1', x: 0.32, y: 0.64, isHome: false),
      const _CourtPlayer(id: 'A2', label: '2', x: 0.64, y: 0.64, isHome: false),
      const _CourtPlayer(id: 'A3', label: '3', x: 0.82, y: 0.44, isHome: false),
      const _CourtPlayer(id: 'A4', label: '4', x: 0.38, y: 0.34, isHome: false),
      const _CourtPlayer(id: 'A5', label: '5', x: 0.54, y: 0.16, isHome: false),
    ],
    arrows: [
      // PG entry to PF at the elbow
      const _DrawnArrow(start: Offset(0.32, 0.74), end: Offset(0.36, 0.44)),
      // SG cuts backdoor
      const _DrawnArrow(start: Offset(0.66, 0.74), end: Offset(0.56, 0.30)),
      // PG relocates
      const _DrawnArrow(start: Offset(0.30, 0.74), end: Offset(0.14, 0.58)),
    ],
  );

  /// 2-3 Zone Defense.
  static _TacticalPreset zone23Defense() => _TacticalPreset(
    name: '2-3 Zone Defense',
    description:
        'Two guards up top, three players across the baseline. '
        'Protects the paint and contests perimeter shots.',
    players: [
      const _CourtPlayer(id: 'H1', label: 'PG', x: 0.34, y: 0.62, isHome: true),
      const _CourtPlayer(id: 'H2', label: 'SG', x: 0.58, y: 0.62, isHome: true),
      const _CourtPlayer(id: 'H3', label: 'SF', x: 0.16, y: 0.34, isHome: true),
      const _CourtPlayer(id: 'H4', label: 'PF', x: 0.76, y: 0.34, isHome: true),
      const _CourtPlayer(id: 'H5', label: 'C', x: 0.46, y: 0.28, isHome: true),
      const _CourtPlayer(id: 'A1', label: '1', x: 0.46, y: 0.80, isHome: false),
      const _CourtPlayer(id: 'A2', label: '2', x: 0.14, y: 0.68, isHome: false),
      const _CourtPlayer(id: 'A3', label: '3', x: 0.78, y: 0.68, isHome: false),
      const _CourtPlayer(id: 'A4', label: '4', x: 0.28, y: 0.50, isHome: false),
      const _CourtPlayer(id: 'A5', label: '5', x: 0.64, y: 0.50, isHome: false),
    ],
    arrows: [
      const _DrawnArrow(start: Offset(0.34, 0.60), end: Offset(0.24, 0.50)),
      const _DrawnArrow(start: Offset(0.58, 0.60), end: Offset(0.68, 0.50)),
    ],
  );

  /// Man-to-man full-court press.
  static _TacticalPreset manToManDefense() => _TacticalPreset(
    name: 'Man-to-Man Tight',
    description:
        'Each defender matched up tight on their assignment. '
        'Switch on screens, strong help-side rotation.',
    players: [
      const _CourtPlayer(id: 'H1', label: 'PG', x: 0.46, y: 0.76, isHome: true),
      const _CourtPlayer(id: 'H2', label: 'SG', x: 0.16, y: 0.62, isHome: true),
      const _CourtPlayer(id: 'H3', label: 'SF', x: 0.76, y: 0.62, isHome: true),
      const _CourtPlayer(id: 'H4', label: 'PF', x: 0.30, y: 0.42, isHome: true),
      const _CourtPlayer(id: 'H5', label: 'C', x: 0.62, y: 0.42, isHome: true),
      const _CourtPlayer(id: 'A1', label: '1', x: 0.46, y: 0.80, isHome: false),
      const _CourtPlayer(id: 'A2', label: '2', x: 0.16, y: 0.66, isHome: false),
      const _CourtPlayer(id: 'A3', label: '3', x: 0.76, y: 0.66, isHome: false),
      const _CourtPlayer(id: 'A4', label: '4', x: 0.30, y: 0.46, isHome: false),
      const _CourtPlayer(id: 'A5', label: '5', x: 0.62, y: 0.46, isHome: false),
    ],
    arrows: [],
  );

  static List<_TacticalPreset> all() => [
    knicksTriangleOffense(),
    knicksPickAndRoll(),
    knicksIsolation(),
    knicksPinchPost(),
    zone23Defense(),
    manToManDefense(),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// The full tactical board widget
// ═══════════════════════════════════════════════════════════════════════════════

enum _BoardMode { move, draw, erase }

class _BasketballTacticalBoard extends StatefulWidget {
  final List<_CourtPlayer> players;
  final List<_DrawnArrow> arrows;
  final ValueChanged<List<_CourtPlayer>> onPlayersChanged;
  final ValueChanged<List<_DrawnArrow>> onArrowsChanged;
  final ValueChanged<_TacticalPreset> onLoadPreset;
  final List<_TacticalPreset> savedPlays;
  final ValueChanged<String>? onSaveCurrentPlay;
  final bool isFullScreen;

  const _BasketballTacticalBoard({
    required this.players,
    required this.arrows,
    required this.onPlayersChanged,
    required this.onArrowsChanged,
    required this.onLoadPreset,
    this.savedPlays = const [],
    this.onSaveCurrentPlay,
    this.isFullScreen = false,
  });

  @override
  State<_BasketballTacticalBoard> createState() =>
      _BasketballTacticalBoardState();
}

class _BasketballTacticalBoardState extends State<_BasketballTacticalBoard> {
  final _BoardMode _mode = _BoardMode.move;
  final GlobalKey _courtKey = GlobalKey();
  List<_CourtPlayer>? _livePlayers;

  // Drawing state — collects freehand points for smooth curves
  List<Offset> _drawPoints = [];

  final List<Map<String, dynamic>> _undoStack = [];

  void _pushUndoState() {
    setState(() {
      _undoStack.add({
        'players': _cloneCourtPlayers(_players),
        'arrows': _cloneDrawnArrows(widget.arrows),
      });
      if (_undoStack.length > 30) _undoStack.removeAt(0);
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      final last = _undoStack.removeLast();
      final p = last['players'] as List<_CourtPlayer>;
      final a = last['arrows'] as List<_DrawnArrow>;
      _livePlayers = p;
      widget.onPlayersChanged(p);
      widget.onArrowsChanged(a);
    });
  }

  // Player drag state
  String? _draggingPlayerId;
  Offset? _dragGrabOffset;

  // Court layout dimensions (set by LayoutBuilder)
  double _courtW = 0;
  double _courtH = 0;

  static const double _markerSize = 46;

  List<_CourtPlayer> get _players => _livePlayers ?? widget.players;

  @override
  void didUpdateWidget(covariant _BasketballTacticalBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_draggingPlayerId == null && oldWidget.players != widget.players) {
      _livePlayers = _cloneCourtPlayers(widget.players);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screen = MediaQuery.sizeOf(context);
    final maxCourtHeight = widget.isFullScreen ? screen.height * 0.52 : null;

    return Column(
      children: [
        // ── Toolbar ─────────────────────────────────────────────────────
        // ── Court ───────────────────────────────────────────────────────
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxCourtHeight ?? double.infinity,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 0.72,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _courtW = constraints.maxWidth;
                    _courtH = constraints.maxHeight;
                    return Stack(
                      key: _courtKey,
                      children: [
                        // Background court + saved arrows + pending stroke
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CourtPainter(
                              isDark: isDark,
                              arrows: widget.arrows,
                              pendingPoints:
                                  (widget.isFullScreen ||
                                      _mode == _BoardMode.draw)
                                  ? _drawPoints
                                  : const [],
                            ),
                          ),
                        ),

                        // Draw / erase gesture layer (sits BEHIND players in
                        // draw mode so players don't intercept touches)
                        if (widget.isFullScreen)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onPanStart: _onDrawPanStart,
                              onPanUpdate: _onDrawPanUpdate,
                              onPanEnd: _onDrawPanEnd,
                              onDoubleTapDown: widget.isFullScreen
                                  ? _onEraseTap
                                  : null,
                              onTapDown: widget.isFullScreen
                                  ? null
                                  : _onEraseTap,
                            ),
                          ),

                        // Player markers — each is independently draggable
                        for (final player in _players)
                          _buildDraggablePlayer(player),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Legend ───────────────────────────────────────────────────────
        if (widget.isFullScreen)
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _legendDot(const Color(0xFF2E7D32), AppLocalizations.of(context).addPlansYourTeam),
              _legendDot(const Color(0xFFC62828), AppLocalizations.of(context).addPlansOpponent),
              if (widget.isFullScreen && widget.onSaveCurrentPlay != null)
                AnimatedButton.secondary(
                  child: TextButton.icon(
                    onPressed: _promptSavePlay,
                    icon: const Icon(Icons.playlist_add, size: 16),
                    label: Text(
                      AppLocalizations.of(context).addPlansSavePlay,
                      style: const TextStyle(fontFamily: 'SFPro', fontSize: 13),
                    ),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ),
              AnimatedButton.secondary(
                child: TextButton.icon(
                  onPressed: () {
                    _pushUndoState();
                    final resetPlayers = _TacticalPresets.defaultFormation();
                    setState(() => _livePlayers = resetPlayers);
                    widget.onPlayersChanged(resetPlayers);
                    widget.onArrowsChanged([]);
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(
                    AppLocalizations.of(context).addPlansReset,
                    style: const TextStyle(fontFamily: 'SFPro', fontSize: 13),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
              ),
              AnimatedButton.secondary(
                child: TextButton.icon(
                  onPressed: _undoStack.isEmpty ? null : () {
                    HapticFeedback.lightImpact();
                    _undo();
                  },
                  icon: const Icon(Icons.undo, size: 16),
                  label: Text(
                    AppLocalizations.of(context).addPlansUndo,
                    style: const TextStyle(fontFamily: 'SFPro', fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _undoStack.isEmpty ? Colors.grey : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        if (widget.isFullScreen) const SizedBox(height: 12),
        if (widget.isFullScreen)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                AppLocalizations.of(context).addPlansDone,
                style: const TextStyle(fontFamily: 'SFPro', fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        if (widget.isFullScreen) const SizedBox(height: 12),

        // ── Preset plays ────────────────────────────────────────────────
        if (widget.isFullScreen)
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _buildPresetsSection(isDark),
            ),
          ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Draggable player — uses raw Listener for zero-lag pointer tracking
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildDraggablePlayer(_CourtPlayer player) {
    final isDragging = _draggingPlayerId == player.id;
    final left = (player.x * _courtW).clamp(0.0, _courtW - _markerSize);
    final top = (player.y * _courtH).clamp(0.0, _courtH - _markerSize);

    // Use plain Positioned during drag (instant), AnimatedPositioned on release
    final Widget positioned = isDragging
        ? Positioned(
            key: ValueKey(player.id),
            left: left,
            top: top,
            child: _buildMarkerBody(player, true),
          )
        : AnimatedPositioned(
            key: ValueKey(player.id),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            left: left,
            top: top,
            child: _buildMarkerBody(player, false),
          );

    return positioned;
  }

  Widget _buildMarkerBody(_CourtPlayer player, bool isDragging) {
    final marker = _PlayerMarker(
      label: player.label,
      color: player.isHome ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
      size: _markerSize,
      elevated: isDragging,
    );

    if (!widget.isFullScreen || _mode != _BoardMode.move) {
      return IgnorePointer(child: marker);
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        HapticFeedback.lightImpact();
        _pushUndoState();
        final courtBox =
            _courtKey.currentContext?.findRenderObject() as RenderBox?;
        final pointerOnCourt =
            courtBox?.globalToLocal(event.position) ??
            Offset(player.x * _courtW, player.y * _courtH);
        final playerTopLeft = Offset(player.x * _courtW, player.y * _courtH);
        setState(() {
          _draggingPlayerId = player.id;
          _dragGrabOffset = pointerOnCourt - playerTopLeft;
        });
      },
      onPointerMove: (event) {
        if (_draggingPlayerId != player.id) return;
        final courtBox =
            _courtKey.currentContext?.findRenderObject() as RenderBox?;
        if (courtBox == null || _courtW <= 0 || _courtH <= 0) return;
        final grabOffset =
            _dragGrabOffset ?? const Offset(_markerSize / 2, _markerSize / 2);
        final pointerOnCourt = courtBox.globalToLocal(event.position);
        final newLeft = (pointerOnCourt.dx - grabOffset.dx).clamp(
          0.0,
          _courtW - _markerSize,
        );
        final newTop = (pointerOnCourt.dy - grabOffset.dy).clamp(
          0.0,
          _courtH - _markerSize,
        );
        final newX = newLeft / _courtW;
        final newY = newTop / _courtH;

        final updated = List<_CourtPlayer>.from(_players);
        final idx = updated.indexWhere((p) => p.id == player.id);
        if (idx != -1) {
          updated[idx] = updated[idx].copyWith(x: newX, y: newY);
        }
        setState(() => _livePlayers = updated);
        widget.onPlayersChanged(updated);
      },
      onPointerUp: (_) {
        HapticFeedback.selectionClick();
        setState(() {
          _draggingPlayerId = null;
          _dragGrabOffset = null;
        });
      },
      onPointerCancel: (_) {
        setState(() {
          _draggingPlayerId = null;
          _dragGrabOffset = null;
        });
      },
      child: marker,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Draw / erase handlers
  // ────────────────────────────────────────────────────────────────────────

  void _onDrawPanStart(DragStartDetails d) {
    if (!widget.isFullScreen && _mode != _BoardMode.draw) return;
    HapticFeedback.selectionClick();
    _pushUndoState();
    setState(() {
      _drawPoints = [_normaliseCourtPoint(d.localPosition)];
    });
  }

  void _onDrawPanUpdate(DragUpdateDetails d) {
    if ((!widget.isFullScreen && _mode != _BoardMode.draw) ||
        _drawPoints.isEmpty) {
      return;
    }
    setState(() {
      _drawPoints.add(_normaliseCourtPoint(d.localPosition));
    });
  }

  void _onDrawPanEnd(DragEndDetails _) {
    if ((!widget.isFullScreen && _mode != _BoardMode.draw) ||
        _drawPoints.length < 2) {
      setState(() => _drawPoints = []);
      return;
    }

    final start = _drawPoints.first;
    final end = _drawPoints.last;
    final dist = (start - end).distance;

    if (dist > 0.03) {
      // Simplify points — keep every Nth to smooth storage
      final simplified = _simplifyPoints(_drawPoints, 4);
      widget.onArrowsChanged([
        ...widget.arrows,
        _DrawnArrow(start: start, end: end, points: simplified),
      ]);
      HapticFeedback.lightImpact();
    }

    setState(() => _drawPoints = []);
  }

  void _onEraseTap(TapDownDetails d) {
    if ((!widget.isFullScreen && _mode != _BoardMode.erase) ||
        widget.arrows.isEmpty) {
      return;
    }
    final tapNorm = _normaliseCourtPoint(d.localPosition);

    // Find the closest arrow (check all points, not just midpoint)
    double bestDist = double.infinity;
    int bestIdx = -1;
    for (int i = 0; i < widget.arrows.length; i++) {
      final a = widget.arrows[i];
      final pts = a.points.isNotEmpty ? a.points : [a.start, a.end];
      for (final p in pts) {
        final dist = (p - tapNorm).distance;
        if (dist < bestDist) {
          bestDist = dist;
          bestIdx = i;
        }
      }
    }
    if (bestIdx != -1 && bestDist < 0.10) {
      HapticFeedback.mediumImpact();
      _pushUndoState();
      final updated = List<_DrawnArrow>.from(widget.arrows)..removeAt(bestIdx);
      widget.onArrowsChanged(updated);
    }
  }

  Offset _normaliseCourtPoint(Offset localPosition) {
    final safeW = max(_courtW, 1);
    final safeH = max(_courtH, 1);
    return Offset(
      (localPosition.dx / safeW).clamp(0.0, 1.0),
      (localPosition.dy / safeH).clamp(0.0, 1.0),
    );
  }

  /// Keep every [step]th point (always including first and last).
  static List<Offset> _simplifyPoints(List<Offset> raw, int step) {
    if (raw.length <= 3) return List.of(raw);
    final result = <Offset>[raw.first];
    for (int i = step; i < raw.length - 1; i += step) {
      result.add(raw[i]);
    }
    result.add(raw.last);
    return result;
  }

  // ── Toolbar ─────────────────────────────────────────────────────────────

  Future<void> _promptSavePlay() async {
    String playName = 'Play ${widget.savedPlays.length + 1}';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final dialogIsDark =
            Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          backgroundColor: dialogIsDark
              ? const Color(0xFF123024)
              : Colors.white,
          title: Text(AppLocalizations.of(context).addPlansSavePlay),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: TextFormField(
              initialValue: playName,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).addPlansPlayName,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => playName = value,
              onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, playName),
              child: Text(AppLocalizations.of(context).addPlansSave),
            ),
          ],
        );
      },
    );
    if (name != null && name.trim().isNotEmpty) {
      widget.onSaveCurrentPlay?.call(name.trim());
    }
  }

  // ── Presets ───────────────────────────────────────────────────────────

  Widget _buildPresetsSection(bool isDark) {
    final presets = _TacticalPresets.all();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.savedPlays.isNotEmpty) ...[
          _playShelfTitle(AppLocalizations.of(context).addPlansSavedPlays, isDark),
          _playShelf(widget.savedPlays, isDark),
          const SizedBox(height: 14),
        ],
        _playShelfTitle(AppLocalizations.of(context).addPlansPresetPlays, isDark),
        _playShelf(presets, isDark),
      ],
    );
  }

  Widget _playShelfTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontWeight: FontWeight.w600,
          fontFamily: 'SFPro',
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _playShelf(List<_TacticalPreset> plays, bool isDark) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: plays.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _playCard(plays[i], isDark),
      ),
    );
  }

  Widget _playCard(_TacticalPreset play, bool isDark) {
    final isOffensive = _isOffensivePlay(play);
    final color = isOffensive
        ? const Color(0xFFFF6D00)
        : const Color(0xFF1565C0);
    return GestureDetector(
      onTap: () {
        if (context.findAncestorStateOfType<_BasketballTacticalBoardState>() != null) {
          context.findAncestorStateOfType<_BasketballTacticalBoardState>()!._pushUndoState();
        }
        setState(() => _livePlayers = _cloneCourtPlayers(play.players));
        widget.onLoadPreset(play);
      },
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: play.isCustom
                ? Colors.green.withValues(alpha: 0.45)
                : isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  play.isCustom
                      ? Icons.edit_note
                      : isOffensive
                      ? Icons.sports_basketball
                      : Icons.shield,
                  size: 14,
                  color: play.isCustom ? Colors.green : color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    play.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SFPro',
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                play.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'SFPro',
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isOffensivePlay(_TacticalPreset play) {
    final name = play.name.toLowerCase();
    return !name.contains('defense') &&
        !name.contains('zone') &&
        !name.contains('man-to-man');
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontFamily: 'SFPro', fontSize: 12)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Player marker — scale transform on drag for tactile feedback
// ═══════════════════════════════════════════════════════════════════════════════

class _PlayerMarker extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  final bool elevated;

  const _PlayerMarker({
    required this.label,
    required this.color,
    this.size = 46,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: elevated ? 1.25 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: elevated ? 3 : 2.5),
          boxShadow: [
            // Outer glow while dragging
            if (elevated)
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            // Standard shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: elevated ? 0.5 : 0.3),
              blurRadius: elevated ? 12 : 5,
              offset: Offset(0, elevated ? 6 : 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'SFPro',
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Court painter — half-court lines + smooth curved arrows
// ═══════════════════════════════════════════════════════════════════════════════

class _CourtPainter extends CustomPainter {
  final bool isDark;
  final List<_DrawnArrow> arrows;

  /// Raw points of the stroke being drawn right now.
  final List<Offset> pendingPoints;

  _CourtPainter({
    this.isDark = false,
    this.arrows = const [],
    this.pendingPoints = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Hardwood background ───────────────────────────────────────────
    final bgPaint = Paint()..color = const Color(0xFFCD853F);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Subtle wood-grain stripes
    final grainPaint = Paint()
      ..color = const Color(0xFFC07C3A).withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (double x = 0; x < w; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grainPaint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // ── Outer boundary ────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(1, 1, w - 2, h - 2),
      linePaint..strokeWidth = 2.5,
    );

    // ── Half-court line (top) ─────────────────────────────────────────
    linePaint.strokeWidth = 2;
    canvas.drawLine(Offset(0, 1), Offset(w, 1), linePaint);

    // ── Center circle at half-court ───────────────────────────────────
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w / 2, 1),
        width: w * 0.36,
        height: w * 0.36,
      ),
      0,
      pi,
      false,
      linePaint,
    );

    // ── Free-throw lane (paint / key) ─────────────────────────────────
    final laneW = w * 0.40;
    final laneH = h * 0.36;
    final laneLeft = (w - laneW) / 2;
    canvas.drawRect(
      Rect.fromLTWH(laneLeft, h - laneH, laneW, laneH),
      linePaint,
    );

    // Lane hash marks
    final hashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..strokeWidth = 1.5;
    for (int i = 1; i <= 3; i++) {
      final y = h - laneH + (laneH * i / 4);
      canvas.drawLine(Offset(laneLeft - 6, y), Offset(laneLeft, y), hashPaint);
      canvas.drawLine(
        Offset(laneLeft + laneW, y),
        Offset(laneLeft + laneW + 6, y),
        hashPaint,
      );
    }

    // ── Free-throw circle ─────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h - laneH),
        width: laneW,
        height: laneW * 0.55,
      ),
      linePaint,
    );

    // ── Three-point arc ───────────────────────────────────────────────
    final threePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final cornerHeight = h * 0.14;
    canvas.drawLine(
      Offset(w * 0.06, h),
      Offset(w * 0.06, h - cornerHeight),
      threePaint,
    );
    canvas.drawLine(
      Offset(w * 0.94, h),
      Offset(w * 0.94, h - cornerHeight),
      threePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w / 2, h - 8),
        width: w * 0.88,
        height: h * 1.28,
      ),
      pi,
      pi,
      false,
      threePaint,
    );

    // ── Restricted area arc ───────────────────────────────────────────
    final restrictedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w / 2, h - 8),
        width: w * 0.18,
        height: w * 0.18,
      ),
      pi,
      pi,
      false,
      restrictedPaint,
    );

    // ── Backboard + Rim ───────────────────────────────────────────────
    final rimY = h - 14;
    final backboardPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w / 2 - 16, rimY + 6),
      Offset(w / 2 + 16, rimY + 6),
      backboardPaint,
    );
    canvas.drawCircle(
      Offset(w / 2, rimY - 4),
      9,
      Paint()
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final netPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 0.8;
    for (double dx = -6; dx <= 6; dx += 4) {
      canvas.drawLine(
        Offset(w / 2 + dx, rimY - 4),
        Offset(w / 2 + dx * 0.6, rimY + 4),
        netPaint,
      );
    }

    // ── Saved arrows ──────────────────────────────────────────────────
    for (final arrow in arrows) {
      _drawArrow(canvas, size, arrow, false);
    }

    // ── Pending live stroke ───────────────────────────────────────────
    if (pendingPoints.length >= 2) {
      _drawLiveStroke(canvas, size, pendingPoints);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Arrow rendering — smooth Catmull-Rom-like curves with glow + arrowhead
  // ────────────────────────────────────────────────────────────────────────

  void _drawArrow(Canvas canvas, Size size, _DrawnArrow arrow, bool isPending) {
    final pts = arrow.points.isNotEmpty
        ? arrow.points
        : [arrow.start, arrow.end];
    if (pts.length < 2) return;

    final pixelPts = pts
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    final path = _smoothPath(pixelPts);

    _drawDottedPath(
      canvas,
      path,
      Colors.white,
      radius: isPending ? 2.4 : 2.8,
      gap: isPending ? 10 : 11,
    );

    // Arrowhead at the end
    _drawArrowhead(canvas, pixelPts, Colors.white, 14);
  }

  void _drawLiveStroke(Canvas canvas, Size size, List<Offset> raw) {
    final pixelPts = raw
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    if (pixelPts.length < 2) return;

    final path = _smoothPath(pixelPts);

    _drawDottedPath(
      canvas,
      path,
      Colors.white.withValues(alpha: 0.88),
      radius: 2.5,
      gap: 10,
    );

    // Live arrowhead
    _drawArrowhead(canvas, pixelPts, Colors.white.withValues(alpha: 0.8), 13);
  }

  void _drawDottedPath(
    Canvas canvas,
    Path path,
    Color color, {
    required double radius,
    required double gap,
  }) {
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final dotPaint = Paint()..color = color;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance <= metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, radius + 2.5, glowPaint);
          canvas.drawCircle(tangent.position, radius, dotPaint);
        }
        distance += gap;
      }
    }
  }

  /// Build a smooth path through pixel-space points using quadratic bezier
  /// curves between midpoints (Catmull-Rom approximation).
  Path _smoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 2) {
      path.lineTo(pts.last.dx, pts.last.dy);
      return path;
    }
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  /// Draw a filled chevron arrowhead pointing in the direction of the last
  /// segment.
  void _drawArrowhead(
    Canvas canvas,
    List<Offset> pts,
    Color color,
    double headLen,
  ) {
    if (pts.length < 2) return;
    final tip = pts.last;
    // Use the last two distinct points for direction
    Offset from = pts[pts.length - 2];
    for (int i = pts.length - 2; i >= 0; i--) {
      if ((pts[i] - tip).distance > 2) {
        from = pts[i];
        break;
      }
    }
    final dir = tip - from;
    final len = dir.distance;
    if (len < 1) return;
    final unit = dir / len;
    final perp = Offset(-unit.dy, unit.dx);

    final p1 = tip - unit * headLen + perp * headLen * 0.45;
    final p2 = tip - unit * headLen - perp * headLen * 0.45;

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    // Glow behind head
    canvas.drawPath(
      headPath,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Fill
    canvas.drawPath(headPath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CourtPainter oldDelegate) =>
      isDark != oldDelegate.isDark ||
      arrows != oldDelegate.arrows ||
      pendingPoints != oldDelegate.pendingPoints;
}
