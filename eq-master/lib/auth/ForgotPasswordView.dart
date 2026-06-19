import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

import '../core/app_background.dart';
import '../core/app_localizations.dart';
import '../core/design_tokens.dart';
import '../core/animated_button.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

/// Forgot-password flow:
///   Step 1 - enter the account email; the server emails a 6-digit code.
///   Step 2 - enter the code; a valid code opens the new-password step.
///   Step 3 - choose and submit the new password.
class ForgotPasswordView extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordView({super.key, this.initialEmail});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView>
    with TickerProviderStateMixin, SmoothKeyboardMixin {
  static const int _resendCooldownSeconds = 60;

  final AuthService _auth = AuthService();

  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  late final FocusNode _emailFocus;
  late final FocusNode _codeFocus;
  late final FocusNode _passwordFocus;
  late final FocusNode _confirmFocus;

  // 0 = enter email, 1 = enter code, 2 = enter new password.
  int _step = 0;
  bool _busy = false;
  bool _obscure = true;
  String _verifiedCode = '';
  int _resendSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _emailFocus = makeFocusNode();
    _codeFocus = makeFocusNode();
    _passwordFocus = makeFocusNode();
    _confirmFocus = makeFocusNode();

    final initialEmail = widget.initialEmail ?? '';
    if (initialEmail.isNotEmpty) {
      _emailCtrl.text = initialEmail;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _hasValidEmail() {
    final email = _emailCtrl.text.trim();
    return email.isNotEmpty && email.contains('@');
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendSeconds = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!_hasValidEmail()) {
      _toast('Please enter a valid email address.');
      return;
    }

    setState(() => _busy = true);
    try {
      await _auth.forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = 1;
        _verifiedCode = '';
        _codeCtrl.clear();
        _passwordCtrl.clear();
        _confirmCtrl.clear();
      });
      _startResendCooldown();
      _toast('If an account exists for that email, a reset code has been sent.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(friendlyErrorText(e, fallback: 'Could not send the reset code.'));
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    if (code.length != 6) {
      _toast('Enter the 6-digit code from your email.');
      return;
    }

    setState(() => _busy = true);
    try {
      await _auth.verifyResetCode(email, code);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = 2;
        _verifiedCode = code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(friendlyErrorText(e,
          fallback: 'Invalid or expired code. Please try again.'));
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (_verifiedCode.isEmpty) {
      setState(() => _step = 1);
      _toast('Please verify the code first.');
      return;
    }
    if (password.length < 8) {
      _toast('Password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      _toast('Passwords do not match.');
      return;
    }

    setState(() => _busy = true);
    try {
      await _auth.resetPassword(
        email: email,
        newPassword: password,
        code: _verifiedCode,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Your password has been reset. Please log in.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(friendlyErrorText(e,
          fallback: 'Could not reset your password. The code may have expired.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final t = AppLocalizations.of(context);
    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;
    updateKeyboardHeight(keyboardH);

    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight + 16;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: AnimatedButton.icon(
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
        titleSpacing: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              t.resetPassword.toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Facon',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
      body: AppBackground(
        child: LayoutBuilder(
          builder: (context, constraints) => buildKeyboardDismissible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.fromLTRB(24, topPadding, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - topPadding - 24,
                ),
                child: Padding(
                  padding: keyboardPadding(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hintText(t),
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_step == 0) ..._buildEmailStep(isDark, textColor)
                    else if (_step == 1) ..._buildCodeStep(isDark, textColor)
                    else ..._buildResetStep(isDark, textColor),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  String _hintText(AppLocalizations t) {
    if (_step == 0) return t.resetPasswordEmailHint;
    if (_step == 1) return t.resetPasswordCodeHint;
    return t.chooseNewPasswordFor(_emailCtrl.text.trim());
  }

  List<Widget> _buildEmailStep(bool isDark, Color textColor) {
    final t = AppLocalizations.of(context);
    return [
      TextField(
        controller: _emailCtrl,
        focusNode: _emailFocus,
        keyboardType: TextInputType.emailAddress,
        style: TextStyle(color: textColor),
        decoration: _field(isDark, t.email, icon: Icons.mail_outline_rounded),
      ),
      const SizedBox(height: 24),
      _primaryButton(t.sendCode, _busy ? null : _sendCode),
    ];
  }

  List<Widget> _buildCodeStep(bool isDark, Color textColor) {
    final t = AppLocalizations.of(context);
    final canResend = !_busy && _resendSeconds == 0;
    final resendLabel = _resendSeconds > 0
        ? '${t.resendCode} (${_resendSeconds}s)'
        : t.resendCode;

    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: TextStyle(fontSize: 20, color: textColor, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B3A2D) : Colors.white,
        border: Border.all(color: isDark ? Colors.white24 : AppColors.primary),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.green, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    return [
      Center(
        child: Pinput(
          length: 6,
          controller: _codeCtrl,
          focusNode: _codeFocus,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: focusedPinTheme,
          onCompleted: (_) => _busy ? null : _verifyCode(),
        ),
      ),
      const SizedBox(height: 32),
      _primaryButton(t.verifyCode, _busy ? null : _verifyCode),
      const SizedBox(height: 16),
      Center(
        child: TextButton(
          onPressed: canResend ? _sendCode : null,
          child: Text(
            resendLabel,
            style: TextStyle(
              color: canResend
                  ? (isDark ? Colors.white70 : Colors.green)
                  : (isDark ? Colors.white38 : Colors.black38),
              decoration: canResend ? TextDecoration.underline : null,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildResetStep(bool isDark, Color textColor) {
    final t = AppLocalizations.of(context);
    return [
      TextField(
        controller: _passwordCtrl,
        focusNode: _passwordFocus,
        obscureText: _obscure,
        style: TextStyle(color: textColor),
        decoration: _field(
          isDark,
          t.newPassword,
          icon: Icons.lock_outline_rounded,
          suffix: IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _confirmCtrl,
        focusNode: _confirmFocus,
        obscureText: _obscure,
        style: TextStyle(color: textColor),
        decoration:
            _field(isDark, t.confirmNewPassword, icon: Icons.lock_outline_rounded),
      ),
      const SizedBox(height: 24),
      _primaryButton(t.resetPassword, _busy ? null : _resetPassword),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _step = 1;
                    _verifiedCode = '';
                    _passwordCtrl.clear();
                    _confirmCtrl.clear();
                  }),
          child: Text(
            t.useDifferentCode,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.green,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return AnimatedButton.primary(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: onPressed,
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'SFPro',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  InputDecoration _field(bool isDark, String label,
      {IconData? icon, Widget? suffix}) {
    final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderRadius = BorderRadius.circular(28);
    return InputDecoration(
      labelText: label,
      counterText: '',
      labelStyle: TextStyle(fontFamily: 'SFPro', color: labelColor, fontSize: 14),
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: isDark ? Colors.white38 : Colors.black45)
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
        borderSide: BorderSide(color: isDark ? Colors.white24 : AppColors.primary),
        borderRadius: borderRadius,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.green, width: 2),
        borderRadius: borderRadius,
      ),
    );
  }
}
