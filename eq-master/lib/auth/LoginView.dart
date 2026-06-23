import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../navigation/MainNavigation.dart';
import 'SignUpView.dart';
import 'ForgotPasswordView.dart';
import '../main.dart' show OnboardingView;
import '../core/app_transitions.dart';
import '../core/app_background.dart';
import '../core/animated_button.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../core/design_tokens.dart';
import '../session/session_bloc.dart';
import 'auth_bloc.dart';
import 'auth_widgets.dart';
import 'CompleteProfileView.dart';
import '../core/app_localizations.dart';
import 'google_sign_in_config.dart';
import '../core/preferences_service.dart';
import '../jointeam/JoinTeamView.dart';
import '../main.dart' show MyApp, OnboardingView;

// Brand green — matches the onboarding page buttons.
const _kGreen = Colors.green;

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with TickerProviderStateMixin, SmoothKeyboardMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final FocusNode _emailFocus;
  late final FocusNode _passwordFocus;
  final _google = createGoogleSignIn();
  bool _obscure = true;
  bool _googleLoading = false; // tracks Google flow independently

  @override
  void initState() {
    super.initState();
    _emailFocus = makeFocusNode();
    _passwordFocus = makeFocusNode();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _goBack() => Navigator.pushReplacement(
    context,
    AppFadeRoute(child: const OnboardingView(initialPage: 2)),
  );

  Future<void> _googleSignIn(BuildContext bloc) async {
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
      // _googleLoading stays true until BlocListener resolves
      authBloc.add(GoogleSignInRequested(idToken: idToken));
    } catch (e) {
      if (!mounted) return;
      setState(() => _googleLoading = false);
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).googleSignInFailed)),
      );
    }
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
        listener: (ctx, state) {
          if (state is Authenticated) {
            ctx.read<SessionBloc>().add(SessionStarted(state.auth));
            final pendingToken = PreferencesService.getPendingInviteToken();
            if (pendingToken != null) {
              PreferencesService.clearPendingInviteToken();
              Navigator.pushAndRemoveUntil(
                ctx,
                AppFadeRoute(
                  child: MainNavigation(userRole: '', userId: state.userId),
                  settings: const RouteSettings(name: '/'),
                ),
                (_) => false,
              );
              Navigator.push(
                MyApp.navigatorKey.currentContext ?? ctx,
                AppFadeRoute(child: const JoinTeamView()),
              );
            } else {
              Navigator.pushAndRemoveUntil(
                ctx,
                AppFadeRoute(
                  child: MainNavigation(userRole: '', userId: state.userId),
                  settings: const RouteSettings(name: '/'),
                ),
                (_) => false,
              );
            }
          } else if (state is ProfileCompletionRequired) {
            // New Google account — collect name + DOB before going to the app.
            if (_googleLoading) setState(() => _googleLoading = false);
            Navigator.pushReplacement(
              ctx,
              AppFadeRoute(
                child: CompleteProfileView(googleAuth: state.auth),
                settings: const RouteSettings(name: '/'),
              ),
            );
          } else if (state is AuthError) {
            // Reset google spinner if the error came from the Google flow.
            if (_googleLoading) setState(() => _googleLoading = false);
            ScaffoldMessenger.of(
              ctx,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: Scaffold(
          // ▸ true = Flutter auto-scrolls the field into view when keyboard opens.
          resizeToAvoidBottomInset: false,
          body: AppBackground(
              // ── Scrollable content ──────────────────────────────────────────
            child: SafeArea(
              child: Builder(
                builder: (bloc) => buildKeyboardDismissible(
                  child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                      // Bouncy physics so the scroll feels natural and complete.
                      physics: const BouncingScrollPhysics(),
                      // Do NOT use onDrag — it dismisses the keyboard while scrolling.
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Padding(
                        padding: keyboardPadding(),
                        child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 40,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          // ── Back + title ──────────────────────────────────
                          Row(
                            children: [
                              const SizedBox(width: 4),
                              Text(
                                t.login,
                                style: TextStyle(
                                  fontFamily: 'Facon',
                                  fontSize: _titleSize(context),
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // ── Email ────────────────────────────────────────
                          TextField(
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: _field(
                              context,
                              t.emailOrPhone,
                              icon: Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Password ─────────────────────────────────────
                          TextField(
                            controller: _passwordCtrl,
                            focusNode: _passwordFocus,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: _field(
                              context,
                              t.password,
                              icon: Icons.lock_outline_rounded,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),

                          // ── Forgot password ──────────────────────────────
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: isDark
                                    ? Colors.white60
                                    : Colors.black87,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => Navigator.of(context).push(
                                AppFadeRoute(
                                  child: ForgotPasswordView(
                                    initialEmail: _emailCtrl.text.trim().contains('@')
                                        ? _emailCtrl.text.trim()
                                        : null,
                                  ),
                                ),
                              ),
                              child: Text(
                                t.forgotPassword,
                                style: const TextStyle(
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ── Log in ───────────────────────────────────────
                          // Only shows its own spinner; Google button has its own.
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
                                    : () => ctx.read<AuthBloc>().add(
                                        LoginRequested(
                                          emailOrPhone: _emailCtrl.text.trim(),
                                          password: _passwordCtrl.text,
                                        ),
                                      ),
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
                                        t.signIn,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // ── Create account ───────────────────────────────
                          AnimatedButton.secondary(child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              side: BorderSide(
                                color: isDark ? Colors.white30 : Colors.green,
                              ),
                            ),
                            onPressed: () => Navigator.pushReplacement(
                              context,
                              AppFadeRoute(
                                child: const SignUpView(),
                                settings: const RouteSettings(name: '/'),
                              ),
                            ),
                            child: Text(
                              t.createAccount,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          )),

                          // ── Divider ──────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            child: _divider(isDark, t.orContinueWith),
                          ),

                          // ── Sign in with Google ──────────────────────────
                          // Uses _googleLoading, not the bloc state, so it
                          // never reacts to a regular email-login in progress.
                          GoogleAuthButton(
                            label: t.signInWithGoogle,
                            isLoading: _googleLoading,
                            onPressed: _googleLoading
                                ? null
                                : () => _googleSignIn(bloc),
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

  InputDecoration _field(
    BuildContext context,
    String label, {
    IconData? icon,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderRadius = BorderRadius.circular(28);
    return InputDecoration(
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
    );
  }
}
