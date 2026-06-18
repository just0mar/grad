import 'package:eqq/core/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A friendly, on-brand fallback that replaces Flutter's raw red error screen
/// whenever a widget fails to build.
///
/// Install once at startup (before `runApp`) via [installFriendlyErrorWidget].
/// In debug builds the underlying exception is still shown so developers can
/// diagnose the problem; in release builds users only see a calm, branded
/// message that matches the rest of the app (green gradient, SFPro type).
void installFriendlyErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Still report the error through the normal channel so it shows up in
    // logs / crash reporting.
    FlutterError.presentError(details);
    return AppErrorView(details: details);
  };
}

class AppErrorView extends StatelessWidget {
  /// Optional Flutter error details. When provided (and in debug mode) the
  /// raw exception text is surfaced to help with diagnosis.
  final FlutterErrorDetails? details;

  /// Optional callback wired to the "Try again" button. When null the button
  /// is hidden (used for build-time [ErrorWidget.builder] failures where there
  /// is nothing sensible to retry).
  final VoidCallback? onRetry;

  const AppErrorView({super.key, this.details, this.onRetry});

  @override
  Widget build(BuildContext context) {
    // ErrorWidget.builder can run outside a MaterialApp (no Theme /
    // Directionality), so this widget is fully self-contained.
    final bool isDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;

    final Color cardColor =
        isDark ? const Color(0xFF10251C) : Colors.white;
    final Color titleColor = isDark ? Colors.white : Colors.black87;
    final Color bodyColor = isDark ? Colors.white70 : Colors.black54;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF0A1F15), const Color(0xFF020806)]
                  : [Colors.green, Colors.white],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.green,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Something went wrong',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "We hit an unexpected problem while loading this "
                        "screen. Please try again — if it keeps happening, "
                        "restarting the app usually helps.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'SFPro',
                          fontSize: 15,
                          height: 1.4,
                          color: bodyColor,
                        ),
                      ),
                      if (kDebugMode && details != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            details!.exceptionAsString(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                      if (onRetry != null) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.green,
                              minimumSize: const Size(64, 50),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: onRetry,
                            child: Text(AppLocalizations.of(context).tryAgain),
                          ),
                        ),
                      ],
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
}
