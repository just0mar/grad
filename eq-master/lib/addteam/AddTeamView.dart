import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../appbar/CustomAppBar.dart';
import '../core/animated_dropdown.dart';
import '../core/app_background.dart';
import '../core/animated_button.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../core/responsive_system.dart';
import '../core/responsive_widgets.dart';
import '../services/api_client.dart';
import '../services/team_service.dart';
import 'AddTeamModel.dart';
import 'add_team_bloc.dart';
import '../core/app_localizations.dart';

class AddTeamView extends StatelessWidget {
  const AddTeamView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddTeamBloc()..add(LoadAddTeamOptions()),
      child: const _AddTeamContent(),
    );
  }
}

class _AddTeamContent extends StatefulWidget {
  const _AddTeamContent();

  @override
  State<_AddTeamContent> createState() => _AddTeamContentState();
}

class _AddTeamContentState extends State<_AddTeamContent>
    with TickerProviderStateMixin, SmoothKeyboardMixin {
  final TeamService _teamService = TeamService();
  final TextEditingController _teamNameController = TextEditingController();
  late final FocusNode _teamNameFocus;
  bool _isSaving = false;
  File? _teamImage;

  @override
  void initState() {
    super.initState();
    _teamNameFocus = makeFocusNode();
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final labelColor = isDark ? Colors.white70 : null;
    final textColor = isDark ? Colors.white : Colors.black;
    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;
    updateKeyboardHeight(keyboardH);
    final pagePadding = ResponsiveSystem.pagePadding(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: CustomAppBar(title: AppLocalizations.of(context).addTeamTitle),
      body: AppBackground(
        child: buildKeyboardDismissible(
          child: SafeArea(
            child: BlocConsumer<AddTeamBloc, AddTeamState>(
                listener: (context, state) {
                  if (state.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.error!)),
                    );
                  }
                },
                builder: (context, state) {
                  final t = AppLocalizations.of(context);
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: pagePadding.copyWith(
                      bottom: pagePadding.bottom + smoothKeyboardHeight,
                    ),
                    child: Column(
                      children: [
                        _buildImagePicker(context, fieldColor, textColor),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _teamNameController,
                          focusNode: _teamNameFocus,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'SFPro',
                            fontSize: ResponsiveSystem.bodyFontSize(context),
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: fieldColor,
                            labelText: t.addTeamName,
                            labelStyle: TextStyle(
                              color: labelColor,
                              fontFamily: 'SFPro',
                              fontSize:
                                  ResponsiveSystem.bodyFontSize(context),
                            ),
                            border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedDropdown(
                          delay: const Duration(milliseconds: 60),
                          child: _buildDropdown(
                            context,
                            label: t.addTeamClub,
                            items: state.clubs,
                            currentValue: state.selectedClub,
                            fieldColor: fieldColor,
                            labelColor: labelColor,
                            textColor: textColor,
                            onChanged: (val) => context.read<AddTeamBloc>().add(ClubChanged(val)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedDropdown(
                          delay: const Duration(milliseconds: 120),
                          child: _buildDropdown(
                            context,
                            label: t.addTeamCategory,
                            items: state.categories,
                            currentValue: state.selectedCategory,
                            fieldColor: fieldColor,
                            labelColor: labelColor,
                            textColor: textColor,
                            onChanged: (val) => context.read<AddTeamBloc>().add(CategoryChanged(val)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const SizedBox(height: 24),
                        AnimatedButton.primary(
                          child: ResponsivePrimaryButton(
                            context: context,
                            label: _isSaving ? t.addTeamAdding : t.addTeamAddTeamBtn,
                            onPressed: () async {
                              if (_isSaving) return;
                              final selectedClub = state.selectedClubDto;
                              final selectedCategory = state.selectedCategoryDto;
                              final teamName =
                                  _teamNameController.text.trim();
                              if (teamName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(t.addTeamEnterName),
                                  ),
                                );
                                return;
                              }
                              if (selectedClub == null ||
                                  selectedCategory == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      t.addTeamChooseClubFirst,
                                    ),
                                  ),
                                );
                                return;
                              }
                              setState(() => _isSaving = true);
                              try {
                                final now = DateTime.now();
                                final dto = await _teamService.createTeam(
                                  selectedClub.clubId,
                                  {
                                    'teamName': teamName,
                                    'categoryId': selectedCategory.categoryId,
                                    'seasonLabel': '${now.year}/${now.year + 1}',
                                    'seasonStartDate':
                                        '${now.year}-01-01',
                                    'seasonEndDate':
                                        '${now.year + 1}-12-31',
                                  },
                                  image: _teamImage,
                                );
                                if (!mounted) return;
                                Navigator.pop(
                                  context,
                                  Team(
                                    id: dto.teamId,
                                    clubId: dto.clubId ?? selectedClub.clubId,
                                    country: '',
                                    club: dto.teamName,
                                    imageUrl: dto.imageUrl,
                                    clubLogoUrl:
                                        dto.clubLogoUrl ?? selectedClub.logoUrl,
                                    category: dto.categoryName ??
                                        state.selectedCategory ??
                                        '',
                                    memberRoles: {'self': dto.myRole ?? ''},
                                  ),
                                );
                              } on ApiException catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message)),
                                );
                              } catch (_) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(t.addTeamErrorCreate),
                                  ),
                                );
                              } finally {
                                if (mounted) setState(() => _isSaving = false);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String label,
    required List<String> items,
    required String? currentValue,
    required Color fieldColor,
    required Color? labelColor,
    required Color textColor,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
                  menuMaxHeight: 280,
    borderRadius: BorderRadius.circular(16),
    elevation: 8,
    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.green, size: 22),
      initialValue: currentValue,
      dropdownColor: fieldColor,
      style: TextStyle(
          color: textColor,
          fontFamily: 'SFPro',
          fontSize: ResponsiveSystem.bodyFontSize(context)),
      decoration: InputDecoration(
        filled: true,
        fillColor: fieldColor,
        labelText: label,
        labelStyle: TextStyle(
            color: labelColor,
            fontFamily: 'SFPro',
            fontSize: ResponsiveSystem.bodyFontSize(context)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontFamily: 'SFPro')),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildImagePicker(
    BuildContext context,
    Color fieldColor,
    Color textColor,
  ) {
    return Column(
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.image,
              allowMultiple: false,
            );
            final path = result?.files.single.path;
            if (path == null) return;
            setState(() => _teamImage = File(path));
          },
          child: CircleAvatar(
            radius: 48,
            backgroundColor: fieldColor,
            child: CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF1B3A2D),
              backgroundImage: _teamImage == null ? null : FileImage(_teamImage!),
              child: _teamImage == null
                  ? const Icon(Icons.camera_alt, color: Colors.white, size: 28)
                  : null,
            ),
          ),
        ),
      ],
    );
  }


}
