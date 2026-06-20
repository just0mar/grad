import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../congrats/CongratsView.dart';
import '../core/app_transitions.dart';
import '../core/app_background.dart';
import '../core/animated_button.dart';
import '../core/design_tokens.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../main.dart' show OnboardingView;
import '../models/api_models.dart';
import '../services/user_service.dart';
import '../session/session_bloc.dart';
import 'auth_bloc.dart';
import '../core/app_localizations.dart';

// Brand green — matches onboarding buttons.
const _kGreen = Colors.green;

/// Shown after a successful Google sign-in/sign-up when the account is new
/// and still needs a name and date-of-birth. The name is pre-filled from the
/// Google account and can be edited. Profile photo is optional.
class CompleteProfileView extends StatefulWidget {
  /// The temporary [AuthResponse] returned by the backend when
  /// [AuthResponse.requiresProfileCompletion] is true.
  final AuthResponse googleAuth;

  const CompleteProfileView({super.key, required this.googleAuth});

  @override
  State<CompleteProfileView> createState() => _CompleteProfileViewState();
}

class _CompleteProfileViewState extends State<CompleteProfileView>
    with TickerProviderStateMixin, SmoothKeyboardMixin {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl; // FIX: was created inline in build()
  final TextEditingController _dobCtrl = TextEditingController();
  late final FocusNode _nameFocus;
  PlatformFile? _profileImage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name from the Google account data.
    _nameCtrl = TextEditingController(text: widget.googleAuth.user?.name ?? '');
    _emailCtrl = TextEditingController(text: widget.googleAuth.user?.email ?? '');
    _nameFocus = makeFocusNode();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  // ── Date of birth picker ────────────────────────────────────────────────────

  Future<void> _pickDob() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future(() {});
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _dobCtrl.text =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  // ── Profile photo picker ────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() => _profileImage = file);
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  void _submit(BuildContext ctx) {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pleaseEnterName),
        ),
      );
      return;
    }
    if (_dobCtrl.text.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).pleaseSelectDob)),
      );
      return;
    }
    ctx.read<AuthBloc>().add(
      CompleteProfileRequested(
        name: name,
        dob: _dobCtrl.text,
        tempToken: widget.googleAuth.accessToken ?? '',
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;
    updateKeyboardHeight(keyboardH);

    return BlocProvider(
      create: (_) => AuthBloc(),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (ctx, state) async {
          if (state is AuthLoading) {
            setState(() => _loading = true);
            return;
          }
          setState(() => _loading = false);

          if (state is Authenticated) {
            ctx.read<SessionBloc>().add(SessionStarted(state.auth));

            // Wait for session to be fully authenticated before uploading photo.
            await ctx.read<SessionBloc>().stream.firstWhere(
              (s) => s.status == SessionStatus.authenticated,
            );

            if (_profileImage != null) {
              try {
                final url = await UserService().uploadProfileImage(
                  _profileImage!,
                );
                if (!mounted) return;
                final user = ctx.read<SessionBloc>().state.user;
                if (user != null) {
                  ctx.read<SessionBloc>().add(
                    SessionUserUpdated(user.copyWith(profileImageUrl: url)),
                  );
                }
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).profileImageUploadFailed)),
                );
              }
            }

            if (!mounted) return;
            Navigator.pushReplacement(
              ctx,
              AppFadeRoute(
                child: const CongratsView(),
                settings: const RouteSettings(name: '/'),
              ),
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(
              ctx,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: AppBackground(
            authStyle: true,
              // ── Scrollable form ─────────────────────────────────────────
            child: SafeArea(
                  child: Builder(
                    builder: (ctx) => buildKeyboardDismissible(
                      child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Padding(
                        padding: keyboardPadding(baseBottom: 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          // ── Back + title ──────────────────────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                onPressed: () => Navigator.pushReplacement(
                                  context,
                                  AppFadeRoute(
                                    child: const OnboardingView(initialPage: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t.completeProfileTitle1,
                                    style: TextStyle(
                                      fontFamily: 'Facon',
                                      fontSize: _titleSize(context),
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      height: 1.1,
                                    ),
                                  ),
                                  Text(
                                    t.completeProfileTitle2,
                                    style: TextStyle(
                                      fontFamily: 'Facon',
                                      fontSize: _titleSize(context),
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              t.completeProfileDesc,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Profile photo ─────────────────────────────────
                          Center(
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _pickPhoto,
                              child: Stack(
                                alignment: AlignmentDirectional.bottomEnd,
                                children: [
                                  CircleAvatar(
                                    radius: 52,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 48,
                                      backgroundColor: isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[200],
                                      backgroundImage: _profileImage != null
                                          ? (kIsWeb
                                              ? MemoryImage(_profileImage!.bytes!) as ImageProvider
                                              : FileImage(File(_profileImage!.path!)))
                                          : null,
                                      child: _profileImage == null
                                          ? Icon(
                                              Icons.person,
                                              size: 44,
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.grey,
                                            )
                                          : null,
                                    ),
                                  ),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _kGreen,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              t.addPhotoOpt,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Name ──────────────────────────────────────────
                          _field(
                            context,
                            ctrl: _nameCtrl,
                            label: t.fullName,
                            icon: Icons.person_outline_rounded,
                            action: TextInputAction.next,
                            focusNode: _nameFocus,
                          ),
                          const SizedBox(height: 16),

                          // ── Email (read-only, informational) ──────────────
                          if (widget.googleAuth.user?.email != null) ...[
                            _field(
                              context,
                              ctrl: _emailCtrl,
                              label: t.emailLabel,
                              icon: Icons.email_outlined,
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── Date of birth (required) ──────────────────────
                          _field(
                            context,
                            ctrl: _dobCtrl,
                            label: t.dobLabelRequired,
                            icon: Icons.cake_outlined,
                            readOnly: true,
                            onTap: _pickDob,
                            suffix: Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Complete button ───────────────────────────────
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (ctx, state) {
                              final loading = state is AuthLoading;
                              return AnimatedButton.primary(
                                child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kGreen,
                                  minimumSize: const Size(double.infinity, 52),
                                  elevation: 0,
                                ),
                                onPressed: loading ? null : () => _submit(ctx),
                                child: loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        t.completeProfileBtn,
                                        style: const TextStyle(
                                          fontFamily: 'SFPro',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── Small hint ────────────────────────────────────
                          Center(
                            child: Text(
                              t.updateDetailsHint,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ),
                ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  double _titleSize(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return 22;
    if (w < 420) return 26;
    return 30;
  }

  Widget _field(
    BuildContext context, {
    required TextEditingController ctrl,
    required String label,
    IconData? icon,
    Widget? suffix,
    bool readOnly = false,
    TextInputAction? action,
    VoidCallback? onTap,
    FocusNode? focusNode,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderRadius = BorderRadius.circular(28);
    return TextField(
      controller: ctrl,
      focusNode: focusNode,
      readOnly: readOnly,
      textInputAction: action,
      onTap: onTap,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'SFPro',
          color: labelColor,
          fontSize: 14,
        ),
        prefixIcon: icon != null
            ? Icon(
                icon,
                size: 20,
                color: isDark ? Colors.white38 : Colors.black45,
              )
            : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: fieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary),
          borderRadius: borderRadius,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : AppColors.primary,
          ),
          borderRadius: borderRadius,
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : AppColors.primary,
          ),
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
