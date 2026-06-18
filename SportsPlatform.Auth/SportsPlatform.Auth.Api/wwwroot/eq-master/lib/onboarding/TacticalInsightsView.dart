import 'package:flutter/material.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/app_transitions.dart';
import '../core/design_tokens.dart';
import '../core/responsive_system.dart';
import 'PeakConditionView.dart';

class TacticalInsightsView extends StatelessWidget {
  const TacticalInsightsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top row with Back + Skip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Back",
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        AppFadeRoute(child: const PeakConditionView()),
                      );
                    },
                    child: Text(
                      "Skip",
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              SizedBox(
                height:
                    (ResponsiveSystem.height(context) * 0.32).clamp(200.0, 300.0),
                child: Image.asset("assets/tactical.png", fit: BoxFit.contain),
              ),
              const SizedBox(height: 20),

              const Text(
                "Tactical Insights",
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
                  "Empower your analysts and coaches with deep insights and real-time report exchange.",
                  style: TextStyle(fontFamily: 'SFPro'),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(),

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
                      AppPageRoute(child: const PeakConditionView()),
                    );
                  },
                  child: const Text(
                    "Next",
                    style: TextStyle(fontFamily: 'SFPro', color: Colors.white),
                  ),
                )),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
