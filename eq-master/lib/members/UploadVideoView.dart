import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/design_tokens.dart';
import '../core/responsive_system.dart';
import '../team/team_bloc.dart';
import 'MemberModel.dart';
import '../core/app_localizations.dart';

class UploadVideoView extends StatefulWidget {
  final Member member;
  final int memberIndex;

  const UploadVideoView({
    super.key,
    required this.member,
    required this.memberIndex,
  });

  @override
  State<UploadVideoView> createState() => _UploadVideoViewState();
}

class _UploadVideoViewState extends State<UploadVideoView> {
  String? _uploadedFileName;
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: false,
    );
    if (result == null) return;
    setState(() => _isUploading = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    setState(() => _isUploading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).noVideoEndpoint),
      ),
    );
  }

  void _saveVideoUrl(String url, String fileName) {
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

    updatedMember.videoUrl = url;
    updatedMember.videoFileName = fileName;

    context.read<TeamBloc>().add(
      UpdateMemberData(
        widget.memberIndex,
        updatedMember,
        requiresStateEditPermission: true,
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
        final currentMember =
            (widget.memberIndex >= 0 &&
                widget.memberIndex < state.members.length)
            ? state.members[widget.memberIndex]
            : widget.member;

        final existingVideo = currentMember.videoUrl;

        return Scaffold(
          appBar: const CustomAppBar(
            title: "Upload Analysis Video",
            showTeamSwitcher: true,
          ),
          body: AppBackground(
            child: Padding(
              padding: ResponsiveSystem.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: kToolbarHeight + 10),

                  // Member info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(width: 12),
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

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blue.shade900.withValues(alpha: 0.3)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.blue.shade800
                            : Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: isDark
                              ? Colors.blue.shade300
                              : Colors.blue.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Upload a performance analysis video for this player. Supported formats: MP4, MOV.",
                            style: TextStyle(
                              fontSize:
                                  ResponsiveSystem.bodyFontSize(context) - 1,
                              color: isDark
                                  ? Colors.blue.shade200
                                  : Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: ResponsiveSystem.verticalGap(context)),

                  // Existing video if any
                  if (existingVideo != null || _uploadedFileName != null) ...[
                    Text(
                      "Current Video",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveSystem.bodyFontSize(context) + 1,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.videocam,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _uploadedFileName ??
                                      currentMember.videoFileName ??
                                      "Analysis Video",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  "Tap to preview",
                                  style: TextStyle(
                                    fontSize:
                                        ResponsiveSystem.bodyFontSize(context) -
                                        2,
                                    color: subTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedButton.primary(child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              minimumSize: const Size(60, 32),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Playing video... (Firebase not connected yet)",
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "play",
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

                  const Spacer(),

                  // Upload button
                  AnimatedButton.primary(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                        : const Icon(Icons.video_library, color: Colors.white),
                    label: Text(
                      _isUploading ? "Uploading..." : "Choose & Upload Video",
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
