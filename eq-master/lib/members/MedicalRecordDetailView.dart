import 'package:eqq/core/app_localizations.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/responsive_system.dart';
import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/medical_service.dart';
import '../session/session_bloc.dart';

/// Full-detail page for a single medical record.
///
/// Shows injury title, diagnosis, dates, recovery tips, clearance status,
/// required documents with their statuses, and lets a *Player* upload
/// documents against pending requests.
class MedicalRecordDetailView extends StatefulWidget {
  final String clubId;
  final String teamId;
  final String playerUserId;
  final MedicalRecordDto record;

  const MedicalRecordDetailView({
    super.key,
    required this.clubId,
    required this.teamId,
    required this.playerUserId,
    required this.record,
  });

  @override
  State<MedicalRecordDetailView> createState() =>
      _MedicalRecordDetailViewState();
}

class _MedicalRecordDetailViewState extends State<MedicalRecordDetailView> {
  final MedicalService _medicalService = MedicalService();

  late MedicalRecordDto _record;
  bool _isUploading = false;
  bool _isReloading = false;
  bool _isDownloading = false;
  String? _downloadingRequestId;
  bool _isPreviewing = false;
  String? _previewingRequestId;
  final Map<String, Future<({Uint8List bytes, String contentType, String fileName})>>
      _previewFutures = {};

  @override
  void initState() {
    super.initState();
    _record = widget.record;
  }

  /// Re-fetch the full record list and find the updated one.
  Future<void> _refreshRecord() async {
    setState(() => _isReloading = true);
    try {
      final records = await _medicalService.getPlayerMedical(
        widget.clubId,
        widget.teamId,
        widget.playerUserId,
      );
      final updated = records.firstWhere(
        (r) => r.recordId == _record.recordId,
        orElse: () => _record,
      );
      if (mounted) setState(() => _record = updated);
    } catch (_) {
      // silently ignore – we still have the old data
    } finally {
      if (mounted) setState(() => _isReloading = false);
    }
  }

  Future<void> _uploadDocument(MedicalDocumentRequestDto request) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      allowMultiple: false,
    );
    final file = result?.files.single;
    if (file == null) return;

    setState(() => _isUploading = true);
    try {
      await _medicalService.uploadDocument(request.requestId, file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).documentUploadedSuccess)),
        );
        await _refreshRecord();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).documentUploadFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _downloadAndOpenDocument(MedicalDocumentRequestDto doc) async {
    setState(() {
      _isDownloading = true;
      _downloadingRequestId = doc.requestId;
    });
    try {
      final result = await _medicalService.downloadDocument(doc.requestId);

      // Save to temp directory and open with external app
      final tempDir = await getTemporaryDirectory();
      final safeName = _safeFileName(result.fileName);
      final file = File('${tempDir.path}${Platform.pathSeparator}$safeName');
      await file.writeAsBytes(result.bytes);

      if (!mounted) return;

      final openResult = await OpenFilex.open(
        file.path,
        type: result.contentType,
      );

      if (openResult.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).openFileError(openResult.message))),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).documentDownloadFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingRequestId = null;
        });
      }
    }
  }

  Future<void> _previewDocument(MedicalDocumentRequestDto doc) async {
    setState(() {
      _isPreviewing = true;
      _previewingRequestId = doc.requestId;
    });
    try {
      final result = await _medicalService.downloadDocument(doc.requestId);
      if (!mounted) return;

      // Save to temp and open with external app
      final tempDir = await getTemporaryDirectory();
      final safeName = _safeFileName(result.fileName);
      final file = File('${tempDir.path}${Platform.pathSeparator}$safeName');
      await file.writeAsBytes(result.bytes);

      final openResult = await OpenFilex.open(
        file.path,
        type: result.contentType,
      );

      if (openResult.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).openFileError(openResult.message))),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).documentPreviewFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPreviewing = false;
          _previewingRequestId = null;
        });
      }
    }
  }

  Future<({Uint8List bytes, String contentType, String fileName})>
      _previewData(MedicalDocumentRequestDto doc) {
    return _previewFutures.putIfAbsent(
      doc.requestId,
      () => _medicalService.downloadDocument(doc.requestId),
    );
  }


  String _safeFileName(String fileName) {
    final sanitized = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'medical-document' : sanitized;
  }

  bool _isPdfPreview(String contentType, String fileName) {
    final normalizedType = contentType.toLowerCase();
    final normalizedName = fileName.toLowerCase();
    return normalizedType.contains('pdf') || normalizedName.endsWith('.pdf');
  }

  bool _isImagePreview(String contentType, String fileName) {
    final normalizedType = contentType.toLowerCase();
    final normalizedName = fileName.toLowerCase();
    return normalizedType.startsWith('image/') ||
        normalizedName.endsWith('.png') ||
        normalizedName.endsWith('.jpg') ||
        normalizedName.endsWith('.jpeg');
  }

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg =
        isDark ? const Color(0xFF1B3A2D) : const Color(0xFFF5F5F0);
    final fieldFill = isDark ? const Color(0xFF0D2A1C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.white54 : Colors.grey;
    final hPad = ResponsiveSystem.horizontalPadding(context);

    // Is the logged-in user the player whose record this is?
    final session = context.watch<SessionBloc>().state;
    final isPlayer = session.user?.userId == widget.playerUserId;

    final startDate = _formatDate(_record.recordedAt.toLocal());
    final expectedEnd = DateTime.tryParse(_record.expectedReturnDate ?? '');
    final endDateStr =
        expectedEnd != null ? _formatDate(expectedEnd) : 'N/A';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: 'Medical Record',
        showTeamSwitcher: false,
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshRecord,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                top: 24,
                left: hPad,
                right: hPad,
                bottom: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══════════════════════════════
                  // INJURY TITLE
                  // ═══════════════════════════════
                  Text(
                    'INJURY TITLE',
                    style: TextStyle(
                      fontFamily: 'Facon',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _record.injuryType ?? 'N/A',
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════
                  // DIAGNOSIS
                  // ═══════════════════════════════
                  Text(
                    'DIAGNOSIS',
                    style: TextStyle(
                      fontFamily: 'Facon',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _record.diagnosis?.isNotEmpty == true
                        ? _record.diagnosis!
                        : 'No diagnosis provided.',
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 15,
                      color: textColor,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════
                  // DATES CARD
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Injury start date',
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                startDate,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: subtextColor.withValues(alpha: 0.3),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Estimated end date',
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                endDateStr,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════
                  // TIPS
                  // ═══════════════════════════════
                  Text(
                    'TIPS',
                    style: TextStyle(
                      fontFamily: 'Facon',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTipsCard(cardBg, textColor, subtextColor),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════
                  // REQUIRED DOCUMENTS
                  // ═══════════════════════════════
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'REQUIRED DOCUMENTS',
                          style: TextStyle(
                            fontFamily: 'Facon',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      if (_isReloading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildDocumentsSection(
                    cardBg,
                    fieldFill,
                    textColor,
                    subtextColor,
                    isPlayer,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // TIPS CARD
  // ═══════════════════════════════════════════════════
  Widget _buildTipsCard(Color cardBg, Color textColor, Color subtextColor) {
    final tips = _record.recoveryTips;
    if (tips == null || tips.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(
            'No recovery tips provided.',
            style: TextStyle(
              fontFamily: 'SFPro',
              color: subtextColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    // Split tips by newlines to show as individual items
    final tipLines = tips
        .split(RegExp(r'[\n;]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tipLines.map((tip) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 14,
                      color: textColor,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // DOCUMENTS SECTION
  // ═══════════════════════════════════════════════════
  Widget _buildDocumentsSection(
    Color cardBg,
    Color fieldFill,
    Color textColor,
    Color subtextColor,
    bool isPlayer,
  ) {
    final docs = _record.documentRequests;
    if (docs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(
            'No documents requested.',
            style: TextStyle(
              fontFamily: 'SFPro',
              color: subtextColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(
      children: docs.map((doc) {
        final isPending = doc.status.toLowerCase() == 'pending';
        final isUploaded =
            doc.downloadUrl != null ||
            (doc.fileName != null && doc.fileName!.isNotEmpty);
        final isThisDownloading =
            _isDownloading && _downloadingRequestId == doc.requestId;
        final isThisPreviewing =
            _isPreviewing && _previewingRequestId == doc.requestId;

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
            children: [
              Row(
                children: [
                  Icon(
                    isUploaded
                        ? Icons.description
                        : Icons.upload_file,
                    color: isUploaded ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      doc.documentName,
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isUploaded
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isUploaded ? 'Uploaded' : 'Pending',
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isUploaded ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              if (doc.note != null && doc.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  doc.note!,
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 13,
                    color: subtextColor,
                    height: 1.4,
                  ),
                ),
              ],
              if (isUploaded) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_file, size: 14, color: subtextColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        doc.fileName ?? doc.documentName,
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 12,
                          color: subtextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildInlineDocumentPreview(
                  doc,
                  fieldFill,
                  textColor,
                  subtextColor,
                  isThisPreviewing,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading
                        ? null
                        : () => _downloadAndOpenDocument(doc),
                    icon: Icon(
                      isThisDownloading
                          ? Icons.hourglass_top
                          : Icons.download_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isThisDownloading ? 'Saving...' : 'Download',
                      style: const TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
              // Upload button for players on pending documents
              if (isPlayer && isPending && !isUploaded) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: AnimatedButton.primary(child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : () => _uploadDocument(doc),
                    icon: Icon(
                      _isUploading ? Icons.hourglass_top : Icons.cloud_upload,
                      size: 16,
                    ),
                    label: Text(
                      _isUploading ? 'Uploading...' : 'Upload Document',
                      style: const TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  )),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInlineDocumentPreview(
    MedicalDocumentRequestDto doc,
    Color fillColor,
    Color textColor,
    Color subtextColor,
    bool isOpening,
  ) {
    return FutureBuilder<({Uint8List bytes, String contentType, String fileName})>(
      future: _previewData(doc),
      builder: (context, snapshot) {
        final hasData = snapshot.hasData;
        final data = snapshot.data;
        final canPreview = data != null &&
            (_isPdfPreview(data.contentType, data.fileName) ||
                _isImagePreview(data.contentType, data.fileName));

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isOpening ? null : () => _previewDocument(doc),
          child: Container(
            height: 190,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (hasData && canPreview)
                  _buildPreviewContent(data)
                else
                  _buildUnsupportedPreview(doc, textColor, subtextColor),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    color: Colors.black.withValues(alpha: 0.48),
                    child: Row(
                      children: [
                        Icon(
                          isOpening ? Icons.hourglass_top : Icons.open_in_full,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isOpening ? 'Opening...' : 'Tap to open',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'SFPro',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewContent(
    ({Uint8List bytes, String contentType, String fileName}) data,
  ) {
    if (_isImagePreview(data.contentType, data.fileName)) {
      return Image.memory(data.bytes, fit: BoxFit.cover);
    }

    // For PDFs and other files, show a placeholder icon
    return Center(
      child: Icon(
        Icons.picture_as_pdf_rounded,
        size: 48,
        color: Colors.green.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildUnsupportedPreview(
    MedicalDocumentRequestDto doc,
    Color textColor,
    Color subtextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description, color: subtextColor, size: 42),
            const SizedBox(height: 10),
            Text(
              doc.fileName ?? doc.documentName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontFamily: 'SFPro',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Preview available after opening',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtextColor,
                fontFamily: 'SFPro',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
