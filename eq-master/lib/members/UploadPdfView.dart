import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/responsive_system.dart';
import '../team/team_bloc.dart';
import 'MemberModel.dart';

class UploadPdfView extends StatefulWidget {
  final Member member;
  final int memberIndex;
  final String actionType; // "fitness" | "analysis" | "medical"

  const UploadPdfView({
    super.key,
    required this.member,
    required this.memberIndex,
    required this.actionType,
  });

  @override
  State<UploadPdfView> createState() => _UploadPdfViewState();
}

class _UploadPdfViewState extends State<UploadPdfView> {
  String? _uploadedFileName;
  bool _isUploading = false;

  String get _title {
    switch (widget.actionType) {
      case "fitness":
        return "Upload Fitness PDF";
      case "analysis":
        return "Upload Analysis PDF";
      case "medical":
        return "Upload Medical PDF";
      default:
        return "Upload PDF";
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;
    setState(() => _isUploading = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    setState(() => _isUploading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.actionType == 'medical'
              ? 'Medical uploads must be attached to a pending document request.'
              : 'This backend has no direct PDF upload endpoint for ${widget.actionType}.',
        ),
      ),
    );
  }

  void _savePdfUrl(String url, String fileName) {
    // Create a copy of the member to avoid mutating the state directly
    final updatedMember = Member(
      userId: widget.member.userId,
      email: widget.member.email,
      name: widget.member.name,
      role: widget.member.role,
      image: widget.member.image,
      profileImageUrl: widget.member.profileImageUrl,
      age: widget.member.age,
      isInSquad: widget.member.isInSquad,
      fitnessPdfUrl: widget.member.fitnessPdfUrl,
      fitnessPdfName: widget.member.fitnessPdfName,
      analysisPdfUrl: widget.member.analysisPdfUrl,
      analysisPdfName: widget.member.analysisPdfName,
      medicalPdfUrl: widget.member.medicalPdfUrl,
      medicalPdfName: widget.member.medicalPdfName,
      videoUrl: widget.member.videoUrl,
      videoFileName: widget.member.videoFileName,
      medicalNotes: widget.member.medicalNotes,
      injuryType: widget.member.injuryType,
      absencePeriod: widget.member.absencePeriod,
      injuryFlag: widget.member.injuryFlag,
    );

    switch (widget.actionType) {
      case "fitness":
        updatedMember.fitnessPdfUrl = url;
        updatedMember.fitnessPdfName = fileName;
        break;
      case "analysis":
        updatedMember.analysisPdfUrl = url;
        updatedMember.analysisPdfName = fileName;
        break;
      case "medical":
        updatedMember.medicalPdfUrl = url;
        updatedMember.medicalPdfName = fileName;
        break;
    }

    context.read<TeamBloc>().add(
      UpdateMemberData(
        widget.memberIndex,
        updatedMember,
        requiresStateEditPermission: widget.actionType == 'analysis',
      ),
    );

    setState(() {
      _uploadedFileName = fileName;
      _isUploading = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("$fileName uploaded successfully!")));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return BlocConsumer<TeamBloc, TeamState>(
      listener: (context, state) {
        if (state.permissionError != null &&
            state.permissionError!.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.permissionError!)));
          context.read<TeamBloc>().add(ClearPermissionError());
        }
      },
      builder: (context, state) {
        // Get the latest member data from state if index is valid
        final currentMember =
            (widget.memberIndex >= 0 &&
                widget.memberIndex < state.members.length)
            ? state.members[widget.memberIndex]
            : widget.member;

        String? existingPdf;
        String? existingPdfName;
        switch (widget.actionType) {
          case "fitness":
            existingPdf = currentMember.fitnessPdfUrl;
            existingPdfName = currentMember.fitnessPdfName;
            break;
          case "analysis":
            existingPdf = currentMember.analysisPdfUrl;
            existingPdfName = currentMember.analysisPdfName;
            break;
          case "medical":
            existingPdf = currentMember.medicalPdfUrl;
            existingPdfName = currentMember.medicalPdfName;
            break;
        }

        return Scaffold(
          appBar: CustomAppBar(title: _title, showTeamSwitcher: true),
          body: AppBackground(
            child: Padding(
              padding: ResponsiveSystem.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: kToolbarHeight + 8),

                  // Member info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: AssetImage(currentMember.image),
                          radius: 28,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentMember.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    ResponsiveSystem.bodyFontSize(context) + 2,
                                color: textColor,
                              ),
                            ),
                            Text(
                              currentMember.role,
                              style: TextStyle(
                                fontSize: ResponsiveSystem.bodyFontSize(
                                  context,
                                ),
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: ResponsiveSystem.verticalGap(context)),

                  // Existing PDF if any
                  if (existingPdf != null || _uploadedFileName != null) ...[
                    Text(
                      "Current PDF",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveSystem.bodyFontSize(context) + 1,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _uploadedFileName ??
                                  existingPdfName ??
                                  "Uploaded PDF",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ),
                          AnimatedButton.primary(child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              minimumSize: const Size(60, 32),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Opening PDF... (Firebase not connected yet)",
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "open",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                    SizedBox(height: ResponsiveSystem.verticalGap(context)),
                  ],

                  // Upload button
                  const Spacer(),
                  AnimatedButton.primary(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: Size(
                        double.infinity,
                        ResponsiveSystem.buttonHeight(context),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _isUploading ? null : _pickAndUpload,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.upload_file, color: Colors.white),
                    label: Text(
                      _isUploading ? "Uploading..." : "Choose & Upload PDF",
                      style: const TextStyle(color: Colors.white),
                    ),
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
