import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool authStyle;

  const AppBackground({
    super.key,
    required this.child,
    this.authStyle = false,
  });

  static const double imageOpacity = 0.08;

  static BoxDecoration decoration(BuildContext context, {bool authStyle = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: authStyle
            ? (isDark
                ? [const Color(0xFF0A0A0A), const Color(0xFF1C1C1C)]
                : [const Color(0xFF1B5E20), Colors.white])
            : (isDark
                ? [const Color(0xFF0A1F15), const Color(0xFF020806)]
                : [Colors.green, Colors.white]),
      ),
      image: const DecorationImage(
        image: AssetImage('assets/background.png'),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        opacity: imageOpacity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: decoration(context, authStyle: authStyle),
        child: child,
      ),
    );
  }
}
