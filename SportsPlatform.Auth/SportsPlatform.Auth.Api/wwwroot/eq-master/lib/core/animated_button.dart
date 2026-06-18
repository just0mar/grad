import 'package:flutter/material.dart';

/// ─── AnimatedButton ─────────────────────────────────────────────────────────
/// Universal press-feedback wrapper. Adds a subtle scale animation on tap
/// without changing any visual style of the child widget.
///
/// Three presets via factory constructors:
///   • AnimatedButton.primary  — for ElevatedButton / FilledButton (scale 0.95)
///   • AnimatedButton.secondary — for OutlinedButton / TextButton (scale 0.96)
///   • AnimatedButton.icon     — for IconButton (scale 0.85, with opacity)
///
/// Or use the default constructor with custom parameters.
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final Duration downDuration;
  final Duration upDuration;
  final Curve downCurve;
  final Curve upCurve;
  final bool withOpacity;

  const AnimatedButton({
    super.key,
    required this.child,
    this.pressedScale = 0.95,
    this.downDuration = const Duration(milliseconds: 80),
    this.upDuration = const Duration(milliseconds: 160),
    this.downCurve = Curves.easeOutCubic,
    this.upCurve = Curves.easeOutBack,
    this.withOpacity = false,
  });

  /// For primary action buttons (ElevatedButton, FilledButton).
  /// Scale: 1.0 → 0.95 on press. Bouncy spring-back.
  const AnimatedButton.primary({
    super.key,
    required this.child,
  })  : pressedScale = 0.95,
        downDuration = const Duration(milliseconds: 80),
        upDuration = const Duration(milliseconds: 160),
        downCurve = Curves.easeOutCubic,
        upCurve = Curves.easeOutBack,
        withOpacity = false;

  /// For secondary buttons (OutlinedButton, TextButton).
  /// Scale: 1.0 → 0.96 on press. Slightly subtler.
  const AnimatedButton.secondary({
    super.key,
    required this.child,
  })  : pressedScale = 0.96,
        downDuration = const Duration(milliseconds: 60),
        upDuration = const Duration(milliseconds: 140),
        downCurve = Curves.easeOutCubic,
        upCurve = Curves.easeOutBack,
        withOpacity = false;

  /// For icon buttons. Scale: 1.0 → 0.85. Includes opacity dim.
  const AnimatedButton.icon({
    super.key,
    required this.child,
  })  : pressedScale = 0.85,
        downDuration = const Duration(milliseconds: 50),
        upDuration = const Duration(milliseconds: 120),
        downCurve = Curves.easeOutCubic,
        upCurve = Curves.easeOutCubic,
        withOpacity = true;

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.downDuration,
      reverseDuration: widget.upDuration,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.downCurve,
      reverseCurve: widget.upCurve,
    ));
    _opacityAnim = Tween<double>(
      begin: 1.0,
      end: widget.withOpacity ? 0.6 : 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.downCurve,
      reverseCurve: widget.upCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      behavior: HitTestBehavior.translucent,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: widget.withOpacity
            ? FadeTransition(opacity: _opacityAnim, child: widget.child)
            : widget.child,
      ),
    );
  }
}
