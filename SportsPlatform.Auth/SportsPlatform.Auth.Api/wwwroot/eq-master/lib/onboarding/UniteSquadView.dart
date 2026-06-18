import 'package:flutter/material.dart';
import 'PeakConditionView.dart';
import 'TacticalInsightsView.dart';
import '../core/animated_button.dart';
import '../core/app_background.dart';
import '../core/app_transitions.dart';
import '../core/design_tokens.dart';
import '../core/responsive_system.dart';

class UniteSquadView extends StatelessWidget {
  const UniteSquadView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                child: Image.asset("assets/unite.png", fit: BoxFit.contain),
              ),
              const SizedBox(height: 20),

              const Text(
                "Unite Your Entire Squad",
                style: TextStyle(
                  fontFamily: 'Facon',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "Seamlessly connect Coaches, Players, Doctors, and Analysts in one centralized hub.",
                  style: TextStyle(
                    fontFamily: 'SFPro',
                    fontSize: 16,
                    color: Colors.black54,
                  ),
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
                      AppPageRoute(child: const TacticalInsightsView()),
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
