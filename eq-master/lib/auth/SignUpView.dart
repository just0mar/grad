import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../congrats/CongratsView.dart';
import '../main.dart' show OnboardingView;
import '../core/app_transitions.dart';
import '../core/app_background.dart';
import '../core/animated_button.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../core/design_tokens.dart';
import '../session/session_bloc.dart';
import '../services/user_service.dart';
import 'auth_bloc.dart';
import 'auth_widgets.dart';
import 'CompleteProfileView.dart';
import 'google_sign_in_config.dart';
import '../core/app_localizations.dart';

// Brand green — matches the onboarding page buttons.
const _kGreen = Colors.green;
const _kPhoneCountryCode = '+20';

class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView>
    with TickerProviderStateMixin, SmoothKeyboardMixin {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  late final FocusNode _nameFocus;
  late final FocusNode _usernameFocus;
  late final FocusNode _emailFocus;
  late final FocusNode _phoneFocus;
  late final FocusNode _passwordFocus;
  late final FocusNode _confirmFocus;

  final _google = createGoogleSignIn();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _googleLoading = false; // tracks Google flow independently
  PlatformFile? _profileImage;

  @override
  void initState() {
    super.initState();
    _nameFocus = makeFocusNode();
    _usernameFocus = makeFocusNode();
    _emailFocus = makeFocusNode();
    _phoneFocus = makeFocusNode();
    _passwordFocus = makeFocusNode();
    _confirmFocus = makeFocusNode();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _pickDob() async {
    FocusManager.instance.primaryFocus?.unfocus();
    // Wait for the unfocus to complete rendering instead of a fixed delay
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

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() => _profileImage = file);
  }

  Future<void> _googleSignUp(BuildContext bloc) async {
    setState(() => _googleLoading = true);
    final authBloc = bloc.read<AuthBloc>();
    final messenger = ScaffoldMessenger.of(bloc);
    try {
      if (!mounted) return;
      await _google.signOut();
      final account = await _google.signIn();
      if (account == null) {
        if (mounted) setState(() => _googleLoading = false);
        return;
      }
      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google did not return an ID token.');
      }
      authBloc.add(GoogleSignInRequested(idToken: idToken));
    } catch (e) {
      if (!mounted) return;
      setState(() => _googleLoading = false);
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).googleSignUpFailed)),
      );
    }
  }


  String? _normalizedPhone() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return '$_kPhoneCountryCode$digits';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;
    updateKeyboardHeight(keyboardH);

    return BlocProvider(
      create: (_) => AuthBloc(),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is Authenticated) {
            final sessionBloc = context.read<SessionBloc>();
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);

            sessionBloc.add(SessionStarted(state.auth));
            await sessionBloc.stream.firstWhere(
              (s) => s.status == SessionStatus.authenticated,
            );
            if (_profileImage != null) {
              try {
                final url = await UserService().uploadProfileImage(
                  _profileImage!,
                );
                if (!mounted) return;
                final user = sessionBloc.state.user;
                if (user != null) {
                  sessionBloc.add(
                    SessionUserUpdated(user.copyWith(profileImageUrl: url)),
                  );
                }
              } catch (_) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).profileImageUploadFailed)),
                );
              }
            }
            if (!mounted) return;
            navigator.pushReplacement(
              AppFadeRoute(
                child: const CongratsView(),
                settings: const RouteSettings(name: '/'),
              ),
            );
          } else if (state is ProfileCompletionRequired) {
            // New Google account — collect name + DOB before going to the app.
            if (_googleLoading) setState(() => _googleLoading = false);
            Navigator.pushReplacement(
              context,
              AppFadeRoute(
                child: CompleteProfileView(googleAuth: state.auth),
                settings: const RouteSettings(name: '/'),
              ),
            );
          } else if (state is AuthError) {
            if (_googleLoading) setState(() => _googleLoading = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: Scaffold(
          // ▸ true = Flutter auto-scrolls the focused field into view.
          resizeToAvoidBottomInset: false,
          body: AppBackground(
              // ── Scrollable form ──────────────────────────────────────────
            child: SafeArea(
                  child: Builder(
                    builder: (bloc) => buildKeyboardDismissible(
                      child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      // keyboard dismissed only on user tap-outside, NOT on scroll
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Padding(
                        padding: keyboardPadding(baseBottom: 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          // ── Back + title ─────────────────────────────────
                          Row(
                            children: [
                              const SizedBox(width: 4),
                              Text(
                                t.signUpTitle,
                                style: TextStyle(
                                  fontFamily: 'Facon',
                                  fontSize: _titleSize(context),
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Photo picker ─────────────────────────────────
                          Center(
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _pickPhoto,
                              child: Stack(
                                alignment: AlignmentDirectional.bottomEnd,
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 46,
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
                                              size: 42,
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
                          const SizedBox(height: 24),

                          // ── 1. Name ──────────────────────────────────────
                          _tf(
                            context,
                            ctrl: _nameCtrl,
                            label: t.nameLabel,
                            icon: Icons.person_outline_rounded,
                            action: TextInputAction.next,
                            focusNode: _nameFocus,
                          ),
                          const SizedBox(height: 14),

                          // ── 2. Username ──────────────────────────────────
                          _tf(
                            context,
                            ctrl: _usernameCtrl,
                            label: t.usernameOpt,
                            hint: '@username',
                            icon: Icons.alternate_email_rounded,
                            action: TextInputAction.next,
                            focusNode: _usernameFocus,
                          ),
                          const SizedBox(height: 14),

                          // ── 3. Email ─────────────────────────────────────
                          _tf(
                            context,
                            ctrl: _emailCtrl,
                            label: t.emailLabel,
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress,
                            action: TextInputAction.next,
                            focusNode: _emailFocus,
                          ),
                          const SizedBox(height: 14),

                          // ── 4. Phone ─────────────────────────────────────
                          _tf(
                            context,
                            ctrl: _phoneCtrl,
                            label: t.phoneOpt,
                            icon: Icons.phone_outlined,
                            type: TextInputType.phone,
                            action: TextInputAction.next,
                            focusNode: _phoneFocus,
                            prefixText: '$_kPhoneCountryCode ',
                            inputFormatters: const [
                              _PhoneNumberFormatter(
                                maxDigits: 10,
                                groupSizes: [3, 3, 4],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── 6. Date of birth (above password) ────────────
                          _tf(
                            context,
                            ctrl: _dobCtrl,
                            label: t.dobLabel,
                            icon: Icons.cake_outlined,
                            readOnly: true,
                            onTap: _pickDob,
                            suffix: Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),

                          // ── Clear separator before password section ───────
                          const SizedBox(height: 28),
                          Divider(
                            thickness: 0.5,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          const SizedBox(height: 20),

                          // ── 7. Password ──────────────────────────────────
                          _tf(
                            context,
                            ctrl: _passwordCtrl,
                            label: t.password,
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePass,
                            action: TextInputAction.next,
                            focusNode: _passwordFocus,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ── 8. Confirm password ──────────────────────────
                          _tf(
                            context,
                            ctrl: _confirmCtrl,
                            label: t.confirmPasswordLabel,
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscureConfirm,
                            action: TextInputAction.done,
                            focusNode: _confirmFocus,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Finish sign up ───────────────────────────────
                          // Only shows its own spinner; not affected by Google flow.
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (ctx, state) {
                              final loading =
                                  state is AuthLoading && !_googleLoading;
                              return AnimatedButton.primary(
                                child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kGreen,
                                  minimumSize: const Size(double.infinity, 52),
                                  elevation: 0,
                                ),
                                onPressed: loading
                                    ? null
                                    : () {
                                        if (_dobCtrl.text.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Please select your date of birth',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        if (_passwordCtrl.text !=
                                            _confirmCtrl.text) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Passwords do not match',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        final phoneDigits = _phoneCtrl.text
                                            .replaceAll(RegExp(r'\D'), '');
                                        if (phoneDigits.isNotEmpty &&
                                            phoneDigits.length != 10) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Phone must be 10 digits after +20',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        ctx.read<AuthBloc>().add(
                                          SignUpRequested(
                                            email: _emailCtrl.text.trim(),
                                            name: _nameCtrl.text.trim(),
                                            password: _passwordCtrl.text,
                                            dob: _dobCtrl.text,
                                            phone:
                                                _normalizedPhone(),
                                            username:
                                                _usernameCtrl.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : _usernameCtrl.text.trim(),
                                          ),
                                        );
                                      },
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
                                        t.finishSignUp,
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

                          // ── Divider ──────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            child: _divider(isDark, t.orSignUpWith),
                          ),

                          // ── Sign up with Google ──────────────────────────
                          // Uses _googleLoading only — never reacts to the
                          // "Finish sign up" button's loading state.
                          Builder(
                            builder: (ctx) => GoogleAuthButton(
                              label: t.signUpWithGoogle,
                              isLoading: _googleLoading,
                              onPressed: _googleLoading
                                  ? null
                                  : () => _googleSignUp(ctx),
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _titleSize(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return 22;
    if (w < 420) return 26;
    return 30;
  }

  Widget _divider(bool isDark, String label) => Row(
    children: [
      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ),
      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
    ],
  );

  Widget _tf(
    BuildContext context, {
    required TextEditingController ctrl,
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffix,
    bool obscure = false,
    bool readOnly = false,
    int maxLines = 1,
    int? maxLength,
    String? prefixText,
    TextInputType? type,
    TextInputAction? action,
    VoidCallback? onTap,
    FocusNode? focusNode,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderRadius = BorderRadius.circular(28);
    return TextField(
      controller: ctrl,
      focusNode: focusNode,
      obscureText: obscure,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: type,
      textInputAction: action,
      onTap: onTap,
      inputFormatters: inputFormatters,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontFamily: 'SFPro',
          color: labelColor,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          fontFamily: 'SFPro',
          color: isDark ? Colors.white24 : Colors.black26,
        ),
        prefixIcon: icon != null
            ? Icon(
                icon,
                size: 20,
                color: isDark ? Colors.white38 : Colors.black45,
              )
            : null,
        prefixText: prefixText,
        prefixStyle: TextStyle(
          fontFamily: 'SFPro',
          color: labelColor,
          fontSize: 14,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: fieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        counterStyle: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
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
      ),
    );
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  final int maxDigits;
  final List<int> groupSizes;

  const _PhoneNumberFormatter({
    required this.maxDigits,
    required this.groupSizes,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final digits = rawDigits.length > maxDigits
        ? rawDigits.substring(0, maxDigits)
        : rawDigits;

    final buffer = StringBuffer();
    var index = 0;
    for (final size in groupSizes) {
      if (index >= digits.length) break;
      final end = (index + size) > digits.length
          ? digits.length
          : index + size;
      buffer.write(digits.substring(index, end));
      if (end < digits.length) buffer.write(' ');
      index = end;
    }
    if (index < digits.length) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(digits.substring(index));
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
