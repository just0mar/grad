import 'package:eqq/navigation/MainNavigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/app_background.dart';
import '../core/animated_button.dart';
import '../core/app_transitions.dart';
import '../session/session_bloc.dart';
import '../core/app_localizations.dart';

class CongratsView extends StatelessWidget {
  const CongratsView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF10251C).withValues(alpha: 0.7)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/congrats.png',
                      height: MediaQuery.of(context).size.height * 0.3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      t.homeWelcome,
                      style: TextStyle(
                        fontFamily: 'Facon',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t.congratsDesc,
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    AnimatedButton.primary(child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: () {
                        final session = context.read<SessionBloc>().state;
                        Navigator.pushReplacement(
                          context,
                          AppFadeRoute(
                            child: MainNavigation(
                              userRole: session.currentRole ?? '',
                              userId: session.user?.userId ?? '',
                            ),
                            settings: const RouteSettings(name: '/'),
                          ),
                        );
                      },
                      child: Text(
                        t.obLetsStart,
                        style: const TextStyle(fontFamily: 'SFPro'),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
