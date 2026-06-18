import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoogleAuthButton
// Full-width white Google sign-in / sign-up button.
// ─────────────────────────────────────────────────────────────────────────────
class GoogleAuthButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const GoogleAuthButton({
    super.key,
    required this.label,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDDDDDD)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/google.svg',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    semanticsLabel: 'Google logo',
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3C3C3C),
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GoogleGLogo
//
// Renders the Google "G" mark as filled annular sectors + a horizontal leg.
//
// Flutter canvas angles (clockwise, 0° = east / right):
//   0°  = right   (3 o'clock)
//   90° = down    (6 o'clock)   ← y-axis is DOWN in Flutter
//  180° = left    (9 o'clock)
//  270° = up      (12 o'clock)
//
// Ring layout  ─  60° gap centred on 0° (east):
//   gap       330° → 30°   (right side, the C-opening)
//   Green      30° → 90°   lower-right
//   Yellow     90° → 150°  lower-left
//   Red       150° → 285°  left + upper-left
//   Blue      285° → 330°  upper-right
//
// A filled blue rectangle forms the horizontal leg of the G.
// ─────────────────────────────────────────────────────────────────────────────
class GoogleGLogo extends StatelessWidget {
  final double size;
  const GoogleGLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const double _d = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    // outer / inner radii of the ring
    final double ro = size.width * 0.46;
    final double ri = size.width * 0.27;

    // Draws a filled annular sector (donut slice) between [ro] and [ri].
    void sector(double startDeg, double sweepDeg, Color color) {
      final double s = startDeg * _d;
      final double w = sweepDeg * _d;
      final path = Path()
        // start at outer arc beginning
        ..moveTo(cx + ro * math.cos(s), cy + ro * math.sin(s))
        // outer arc (clockwise)
        ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: ro),
            s, w, false)
        // line inward to inner arc end
        ..lineTo(cx + ri * math.cos(s + w), cy + ri * math.sin(s + w))
        // inner arc (counter-clockwise back to start)
        ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: ri),
            s + w, -w, false)
        ..close();
      canvas.drawPath(
          path, Paint()..color = color..style = PaintingStyle.fill);
    }

    // ── Coloured ring sectors ─────────────────────────────────────────────
    sector(30,  60,  const Color(0xFF34A853)); // Green
    sector(90,  60,  const Color(0xFFFBBC05)); // Yellow
    sector(150, 135, const Color(0xFFEA4335)); // Red
    sector(285, 45,  const Color(0xFF4285F4)); // Blue

    // ── Horizontal leg of the G ───────────────────────────────────────────
    // Height = ring width; centred vertically; left = cx, right = outer edge.
    final double barH = (ro - ri) * 1.05;
    canvas.drawRect(
      Rect.fromLTRB(cx, cy - barH / 2, cx + ro, cy + barH / 2),
      Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
