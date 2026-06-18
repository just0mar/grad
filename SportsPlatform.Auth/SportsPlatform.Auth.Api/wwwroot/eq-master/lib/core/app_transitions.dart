import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// ─── Smooth page route ───────────────────────────────────────────────────────
/// Mimics the iOS navigation feel:
///   • Incoming page slides in from 22 % off-screen (not full width).
///   • Outgoing page drifts 8 % to the left as it's covered (secondaryAnimation).
///   • No harsh fade — a very subtle opacity lift (0.94 → 1.0) removes any
///     "flash" on low-brightness screens without being distracting.
///   • fastOutSlowIn on enter gives a snappy, responsive feel.
///   • easeInCubic on reverse makes the pop feel natural, not mechanical.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  AppPageRoute({required this.child, RouteSettings? settings})
      : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // ── Incoming page ──────────────────────────────────────────────
            final enterSlide = Tween<Offset>(
              begin: const Offset(0.15, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutExpo,
              reverseCurve: Curves.easeInCubic,
            ));

            // Subtle "materialize" — fade in over the first 40% of the anim
            final enterFade = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
            ));

            // ── Outgoing page — gently dims + slides left ──────────────────
            final exitSlide = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.06, 0.0),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeInCubic,
            ));

            final exitFade = Tween<double>(
              begin: 1.0,
              end: 0.85,
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeInCubic,
            ));

            return SlideTransition(
              position: exitSlide,
              child: FadeTransition(
                opacity: exitFade,
                child: FadeTransition(
                  opacity: enterFade,
                  child: SlideTransition(
                    position: enterSlide,
                    child: child,
                  ),
                ),
              ),
            );
          },
        );

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  TickerFuture didPush() {
    _dismissKeyboard();
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    _dismissKeyboard();
    return super.didPop(result);
  }
}

/// Fade-only route – good for root transitions (splash → home, login → home).
class AppFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  AppFadeRoute({required this.child, RouteSettings? settings})
      : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            );
            // Subtle scale from 0.97→1.0 prevents the "flat pop-in" feeling
            final scale = Tween<double>(begin: 0.97, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(scale: scale, child: child),
            );
          },
        );

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  TickerFuture didPush() {
    _dismissKeyboard();
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    _dismissKeyboard();
    return super.didPop(result);
  }
}

/// ─── Animated button wrapper ────────────────────────────────────────────────
/// Wraps any child widget and adds a subtle scale-down + bounce on tap.
/// Usage:  AnimatedPressable(onTap: () {}, child: YourWidget())
class AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  const AnimatedPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
  });

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// ─── Staggered List Item ────────────────────────────────────────────────────
/// Wraps a list item with a slide-up + fade entrance animation.
/// Each item's delay is based on its [index], creating a cascading effect.
///
/// Usage in ListView.builder:
///   itemBuilder: (_, i) => StaggeredListItem(
///     index: i,
///     child: YourCard(...),
///   )
class StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final Duration staggerDelay;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.staggerDelay = const Duration(milliseconds: 50),
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Cap the stagger at 8 items so items far down the list don't wait too long
    final clampedIndex = widget.index.clamp(0, 8);
    final delay = widget.staggerDelay * clampedIndex;

    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}

/// ─── Default page transitions theme (applied at MaterialApp level) ──────────
/// Makes every route that doesn't use AppPageRoute still get a smooth
/// zoom + fade transition on all platforms.
PageTransitionsTheme get appPageTransitionsTheme => const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      },
    );
