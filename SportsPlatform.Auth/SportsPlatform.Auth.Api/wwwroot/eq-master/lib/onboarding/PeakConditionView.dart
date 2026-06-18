import 'package:flutter/material.dart';
import '../auth/LoginView.dart';
import '../auth/SignUpView.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/app_transitions.dart';
import '../core/responsive_system.dart';

class PeakConditionView extends StatelessWidget {
  const PeakConditionView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Back button at top left
              Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Back",
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      color: isDark ? Colors.white : null,
                    ),
                ),
              ),

              const Spacer(),

              SizedBox(
                height:
                    (ResponsiveSystem.height(context) * 0.32).clamp(200.0, 300.0),
                child: Image.asset("assets/peak.png", fit: BoxFit.contain),
              ),
              const SizedBox(height: 20),

              const Text(
                "Peak Player Condition",
                style: TextStyle(
                  fontFamily: 'Facon',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Keep your team game-ready with updated medical reports and fitness tracking.",
                  style: TextStyle(fontFamily: 'SFPro'),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(),

              // Let's Start button → navigates to LoginView
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: AnimatedButton.primary(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      AppPageRoute(child: const LoginView()),
                    );
                  },
                  child: const Text(
                    "Let's Start",
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 12),

              // Create Account button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: Colors.green, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      AppPageRoute(child: const SignUpView()),
                    );
                  },
                  child: const Text(
                    "Create Account",
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
