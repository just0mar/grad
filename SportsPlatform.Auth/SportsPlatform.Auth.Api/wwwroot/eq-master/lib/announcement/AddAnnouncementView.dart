import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/design_tokens.dart';
import '../core/responsive_system.dart';
import '../core/responsive_widgets.dart';
import '../core/smooth_keyboard_mixin.dart';
import 'AnnouncementModel.dart';
import '../core/app_localizations.dart';

class AddAnnouncementView extends StatefulWidget {
  final String authorName;
  final String authorRole;
  final String authorImage;

  const AddAnnouncementView({
    super.key,
    this.authorName = '',
    this.authorRole = '',
    this.authorImage = '',
  });

  @override
  State<AddAnnouncementView> createState() => _AddAnnouncementViewState();
}

class _AddAnnouncementViewState extends State<AddAnnouncementView> with TickerProviderStateMixin, SmoothKeyboardMixin {
  final TextEditingController _captionController = TextEditingController();

  String _priority = 'Normal';
  File? _imageFile;
  String? _imageFileName;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  bool get _isValid => _captionController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    updateKeyboardHeight(MediaQuery.viewInsetsOf(context).bottom);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final Color labelColor = isDark ? Colors.white70 : Colors.black54;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final pagePadding = ResponsiveSystem.pagePadding(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: AppLocalizations.of(context).addAnnounceTitle, showTeamSwitcher: true),
      body: buildKeyboardDismissible(child: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: pagePadding.copyWith(
                  bottom: pagePadding.bottom + smoothKeyboardHeight,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _captionController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontFamily: 'SFPro', color: textColor),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: fieldColor,
                          labelText: AppLocalizations.of(context).addAnnounceCaption,
                          labelStyle: TextStyle(
                            fontFamily: 'SFPro',
                            color: labelColor,
                          ),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primary),
                            borderRadius: BorderRadius.all(Radius.circular(28)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : AppColors.primary,
                            ),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(28),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildImagePicker(fieldColor, textColor),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _priorityChip(AppLocalizations.of(context).addAnnounceUrgent, 'Urgent', Colors.red, textColor),
                          _priorityChip(AppLocalizations.of(context).addAnnounceImportant, 'Important', Colors.blue, textColor),
                          _priorityChip(AppLocalizations.of(context).addAnnounceNormal, 'Normal', Colors.green, textColor),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AnimatedButton.primary(
                        child: ResponsivePrimaryButton(
                          context: context,
                          label: AppLocalizations.of(context).addAnnounceBtn,
                          onPressed: () {
                            if (!_isValid) {
                              return;
                            }
                            _showSuccessDialog(
                              context,
                              textColor: textColor,
                              fieldColor: fieldColor,
                              onConfirm: () {
                                final announcement = Announcement(
                                  authorName: widget.authorName,
                                  authorRole: widget.authorRole,
                                  authorImage: widget.authorImage,
                                  caption: _captionController.text.trim(),
                                  imagePath: _imageFile?.path,
                                  imageFileName: _imageFileName,
                                  priority: _priority,
                                );
                                Navigator.pop(context);
                                Navigator.pop(context, announcement);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      )),
    );
  }

  Widget _buildImagePicker(Color fieldColor, Color textColor) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        final file = result?.files.single;
        final path = file?.path;
        if (path == null) return;
        setState(() {
          _imageFile = File(path);
          _imageFileName = file?.name;
        });
      },
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: fieldColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
        ),
        child: _imageFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.primary.withValues(alpha: 0.85),
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).addAnnouncePickImage,
                    style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  _imageFile!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
      ),
    );
  }

  Widget _priorityChip(String label, String value, Color color, Color textColor) {
    final selected = _priority == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'SFPro',
          color: selected ? Colors.white : textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: selected ? color : color.withValues(alpha: 0.45)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onSelected: (_) => setState(() => _priority = value),
    );
  }

  void _showSuccessDialog(
    BuildContext context, {
    required Color textColor,
    required Color fieldColor,
    required VoidCallback onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: fieldColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: AnimatedButton.icon(
                  child: IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
              ),
              Text(
                AppLocalizations.of(context).addAnnounceSuccess,
                style: TextStyle(
                  fontFamily: 'SFPro',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AnimatedButton.primary(
                child: ResponsivePrimaryButton(
                  context: dialogContext,
                  label: AppLocalizations.of(context).ok,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
