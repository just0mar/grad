import 'package:eqq/core/app_localizations.dart';
import 'package:flutter/material.dart';

import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/responsive_system.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../models/api_models.dart';
import '../services/medical_service.dart';

class AddMedicalRecordView extends StatefulWidget {
  final String clubId;
  final String teamId;
  final String playerUserId;
  final MedicalRecordDto? record;

  const AddMedicalRecordView({
    super.key,
    required this.clubId,
    required this.teamId,
    required this.playerUserId,
    this.record,
  });

  @override
  State<AddMedicalRecordView> createState() => _AddMedicalRecordViewState();
}

class _AddMedicalRecordViewState extends State<AddMedicalRecordView>
    with TickerProviderStateMixin, SmoothKeyboardMixin {
  final _medicalService = MedicalService();

  final _injuryCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _tipsCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();
  final List<_DocumentFields> _documentFields = [];

  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record == null) {
      _documentFields.add(_DocumentFields());
      return;
    }
    _injuryCtrl.text = record.injuryType ?? '';
    _diagnosisCtrl.text = record.diagnosis ?? '';
    _tipsCtrl.text = record.recoveryTips ?? '';
    _startDate = record.recordedAt.toLocal();
    _startDateCtrl.text = _formatDisplayDate(_startDate!);
    final expected = DateTime.tryParse(record.expectedReturnDate ?? '');
    if (expected != null) {
      _endDate = expected;
      _endDateCtrl.text = _formatDisplayDate(expected);
    }
    for (final request in record.documentRequests) {
      final doc = _DocumentFields(isExisting: true);
      doc.titleController.text = request.documentName;
      if (request.note != null && request.note!.isNotEmpty) {
        doc.descController.text = request.note!;
      }
      _documentFields.add(doc);
    }
    if (_documentFields.isEmpty) {
      _documentFields.add(_DocumentFields());
    }
  }

  @override
  void dispose() {
    _injuryCtrl.dispose();
    _diagnosisCtrl.dispose();
    _tipsCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    for (final doc in _documentFields) {
      doc.dispose();
    }
    super.dispose();
  }

  String _formatDisplayDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$mm/$dd/${date.year}';
  }

  String _formatApiDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  Future<void> _pickStartDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      _startDateCtrl.text = _formatDisplayDate(picked);
    });
  }

  Future<void> _pickEndDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _endDate = picked;
      _endDateCtrl.text = _formatDisplayDate(picked);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final recordDate =
          _startDate ?? widget.record?.recordedAt ?? DateTime.now();
      final body = {
        'recordDate': recordDate.toIso8601String(),
        'injuryType': _injuryCtrl.text.trim(),
        'diagnosis': _diagnosisCtrl.text.trim(),
        'recoveryTips': _tipsCtrl.text.trim(),
        if (_endDate != null) 'expectedReturnDate': _formatApiDate(_endDate!),
      };

      final isEdit = widget.record != null;
      final record = isEdit
          ? await _medicalService.updateMedicalRecord(
              widget.clubId,
              widget.teamId,
              widget.record!.recordId,
              body,
            )
          : await _medicalService.createMedicalRecord(
              widget.clubId,
              widget.teamId,
              widget.playerUserId,
              body,
            );

      for (final doc in _documentFields) {
        if (doc.isExisting) continue;
        final docTitle = doc.titleController.text.trim();
        final docDesc = doc.descController.text.trim();
        if (docTitle.isEmpty) continue;
        await _medicalService.requestDocument(
          widget.clubId,
          widget.teamId,
          record.recordId,
          {'documentName': docTitle, if (docDesc.isNotEmpty) 'note': docDesc},
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).medicalRecordSaved)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).saveRecordError(e.toString()))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    updateKeyboardHeight(MediaQuery.viewInsetsOf(context).bottom);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final fieldFill = isDark ? const Color(0xFF0D2A1C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final isEdit = widget.record != null;
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: CustomAppBar(
        title: isEdit ? 'Edit Record' : 'Add Record',
        showTeamSwitcher: false,
      ),
      body: buildKeyboardDismissible(
        child: AppBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: 24,
                left: ResponsiveSystem.horizontalPadding(context),
              right: ResponsiveSystem.horizontalPadding(context),
              bottom: 24 + smoothKeyboardHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inputField(
                  controller: _injuryCtrl,
                  label: 'Injury title',
                  textColor: textColor,
                  labelColor: labelColor,
                  fillColor: fieldFill,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 12),
                _inputField(
                  controller: _diagnosisCtrl,
                  label: 'Diagnosis',
                  textColor: textColor,
                  labelColor: labelColor,
                  fillColor: fieldFill,
                  borderColor: borderColor,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _dateField(
                  label: 'Start date',
                  controller: _startDateCtrl,
                  hint: 'MM/DD/YYYY',
                  textColor: textColor,
                  labelColor: labelColor,
                  fillColor: fieldFill,
                  borderColor: borderColor,
                  onTap: _pickStartDate,
                ),
                const SizedBox(height: 12),
                _dateField(
                  label: 'Estimated end date',
                  controller: _endDateCtrl,
                  hint: 'MM/DD/YYYY',
                  textColor: textColor,
                  labelColor: labelColor,
                  fillColor: fieldFill,
                  borderColor: borderColor,
                  onTap: _pickEndDate,
                ),
                const SizedBox(height: 12),
                _inputField(
                  controller: _tipsCtrl,
                  label: 'Tips',
                  textColor: textColor,
                  labelColor: labelColor,
                  fillColor: fieldFill,
                  borderColor: borderColor,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Add required document',
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Column(
                  children: _documentFields.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _documentFields.length - 1 ? 0 : 10,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _inputField(
                              controller: doc.titleController,
                              label: 'Document title',
                              textColor: textColor,
                              labelColor: labelColor,
                              fillColor: fieldFill,
                              borderColor: borderColor,
                              readOnly: doc.isExisting,
                            ),
                            const SizedBox(height: 10),
                            _inputField(
                              controller: doc.descController,
                              label: 'Description',
                              textColor: textColor,
                              labelColor: labelColor,
                              fillColor: fieldFill,
                              borderColor: borderColor,
                              maxLines: 2,
                              readOnly: doc.isExisting,
                            ),
                            if (!doc.isExisting && _documentFields.length > 1)
                              ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: AnimatedButton.secondary(child: TextButton(
                                  onPressed: () {
                                    setState(
                                      () => _documentFields.removeAt(index),
                                    );
                                  },
                                  child: Text(AppLocalizations.of(context).remove),
                                )),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                AnimatedButton.secondary(child: TextButton.icon(
                  onPressed: () {
                    setState(() => _documentFields.add(_DocumentFields()));
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(AppLocalizations.of(context).addAnotherDocument),
                )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: AnimatedButton.primary(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving
                          ? 'Saving...'
                          : isEdit
                          ? 'Save changes'
                          : 'Add Medical Record',
                      style: const TextStyle(
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required Color textColor,
    required Color labelColor,
    required Color fillColor,
    required Color borderColor,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
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

  Widget _dateField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required Color textColor,
    required Color labelColor,
    required Color fillColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: TextStyle(color: textColor, fontFamily: 'SFPro', fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'SFPro', color: labelColor),
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'SFPro', color: labelColor),
        suffixIcon: Icon(Icons.calendar_today, color: labelColor, size: 18),
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
}

class _DocumentFields {
  final bool isExisting;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  _DocumentFields({this.isExisting = false});

  void dispose() {
    titleController.dispose();
    descController.dispose();
  }
}
