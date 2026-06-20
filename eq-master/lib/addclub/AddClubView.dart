import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/responsive_system.dart';
import '../core/responsive_widgets.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../location/location_point.dart';
import '../location/osm_map.dart';
import '../core/app_localizations.dart';
import 'add_club_bloc.dart';

class AddClubView extends StatelessWidget {
  const AddClubView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddClubBloc(),
      child: const _AddClubContent(),
    );
  }
}

class _AddClubContent extends StatefulWidget {
  const _AddClubContent();

  @override
  State<_AddClubContent> createState() => _AddClubContentState();
}

class _AddClubContentState extends State<_AddClubContent>
    with TickerProviderStateMixin, SmoothKeyboardMixin {
  final TextEditingController _locationController = TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation(BuildContext context, AddClubState state) async {
    final initialPoint =
        state.locationLatitude == null || state.locationLongitude == null
        ? null
        : LocationPoint(
            latitude: state.locationLatitude!,
            longitude: state.locationLongitude!,
            label: state.location,
          );
    final result = await Navigator.push<LocationPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => OsmLocationPicker(
          initialPoint: initialPoint,
          initialLabel: state.location,
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    final label = result.label?.trim().isNotEmpty == true
        ? result.label!.trim()
        : '${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}';
    _locationController.text = label;
    context.read<AddClubBloc>().add(
      ClubLocationPointChanged(
        LocationPoint(
          latitude: result.latitude,
          longitude: result.longitude,
          label: label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    updateKeyboardHeight(MediaQuery.viewInsetsOf(context).bottom);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final helperColor = isDark ? Colors.white70 : Colors.black54;
    final pagePadding = ResponsiveSystem.pagePadding(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: AppLocalizations.of(context).addClubTitle, showTeamSwitcher: true),
      body: buildKeyboardDismissible(
        child: AppBackground(
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            top: false,
            child: BlocConsumer<AddClubBloc, AddClubState>(
                listener: (context, state) {
                  if (state.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.error!)),
                    );
                  }
                  if (state.createdClub != null) {
                    Navigator.pop(context, state.createdClub);
                  }
                },
                builder: (context, state) {
                  final t = AppLocalizations.of(context);
                  final logoMissing = state.error == 'Club logo is required' || state.error == t.addClubLogoReq;
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: pagePadding.copyWith(
                      bottom: pagePadding.bottom + smoothKeyboardHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            _LogoPicker(
                              file: state.logoFile,
                              hasError: logoMissing,
                              onTap: () async {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                  allowMultiple: false,
                                );
                                final file = result?.files.single;
                                if (file == null) return;
                                if (!context.mounted) return;
                                context
                                    .read<AddClubBloc>()
                                    .add(ClubLogoSelected(file));
                              },
                            ),
                            if (logoMissing) ...[
                              const SizedBox(height: 8),
                              Text(
                                t.addClubLogoReq,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontFamily: 'SFPro',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              Text(
                                t.addClubTapToSelect,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: helperColor,
                                  fontFamily: 'SFPro',
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            TextFormField(
                              maxLength: 200,
                              style: TextStyle(
                                color: textColor,
                                fontFamily: 'SFPro',
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: fieldColor,
                                counterStyle: TextStyle(color: helperColor),
                                labelText: t.addClubName,
                                labelStyle: TextStyle(color: helperColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onChanged: (value) => context
                                  .read<AddClubBloc>()
                                  .add(ClubNameChanged(value)),
                            ),
                            const SizedBox(height: 16),

                            // ── Established Date ──
                            GestureDetector(
                              onTap: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: now,
                                  firstDate: DateTime(1800),
                                  lastDate: now,
                                );
                                if (picked == null || !context.mounted) return;
                                final formatted =
                                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                context
                                    .read<AddClubBloc>()
                                    .add(ClubEstablishedDateChanged(formatted));
                              },
                              child: AbsorbPointer(
                                child: TextFormField(
                                  style: TextStyle(
                                    color: textColor,
                                    fontFamily: 'SFPro',
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: fieldColor,
                                    labelText: t.addClubEstDate,
                                    labelStyle: TextStyle(color: helperColor),
                                    hintText: state.establishedDate.isNotEmpty
                                        ? state.establishedDate
                                        : t.addClubSelectDate,
                                    hintStyle: TextStyle(
                                      color: state.establishedDate.isNotEmpty
                                          ? textColor
                                          : helperColor,
                                      fontFamily: 'SFPro',
                                    ),
                                    suffixIcon: Icon(
                                      Icons.calendar_today,
                                      color: helperColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Location ──
                            TextFormField(
                              controller: _locationController,
                              style: TextStyle(
                                color: textColor,
                                fontFamily: 'SFPro',
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: fieldColor,
                                labelText: t.addClubLocation,
                                hintText: t.addClubCityCountry,
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white24 : Colors.black26,
                                  fontFamily: 'SFPro',
                                ),
                                labelStyle: TextStyle(color: helperColor),
                                prefixIcon: Icon(
                                  Icons.location_on_outlined,
                                  color: helperColor,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    Icons.map_outlined,
                                    color: helperColor,
                                  ),
                                  onPressed: () => _pickLocation(context, state),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onChanged: (value) => context
                                  .read<AddClubBloc>()
                                  .add(ClubLocationChanged(value)),
                            ),
                            const SizedBox(height: 20),

                            // ── Map placeholder ──
                            if (state.locationLatitude == null ||
                                state.locationLongitude == null)
                            Container(
                              width: double.infinity,
                              height: 150,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 40,
                                    color: helperColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t.addClubTapMap,
                                    style: TextStyle(
                                      color: helperColor,
                                      fontFamily: 'SFPro',
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            else
                              OsmMapPreview(
                                point: LocationPoint(
                                  latitude: state.locationLatitude!,
                                  longitude: state.locationLongitude!,
                                  label: state.location,
                                ),
                                height: 150,
                                onTap: () => _pickLocation(context, state),
                              ),
                            const SizedBox(height: 24),

                            AnimatedButton.primary(
                              child: ResponsivePrimaryButton(
                                context: context,
                                label: state.isSubmitting
                                    ? t.addClubCreating
                                    : t.addClubCreateClubBtn,
                                onPressed: state.isSubmitting
                                    ? () {}
                                    : () => context
                                        .read<AddClubBloc>()
                                        .add(SubmitCreateClub()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  final PlatformFile? file;
  final bool hasError;
  final VoidCallback onTap;

  const _LogoPicker({
    required this.file,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 58,
              backgroundColor: hasError ? Colors.red : Colors.white,
              child: CircleAvatar(
                radius: 54,
                backgroundColor: const Color(0xFF1B3A2D),
                backgroundImage: file == null 
                    ? null 
                    : (kIsWeb 
                        ? MemoryImage(file!.bytes!) as ImageProvider
                        : FileImage(File(file!.path!))),
                child: file == null
                    ? const Icon(
                        Icons.image_outlined,
                        size: 42,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}
