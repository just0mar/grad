import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// ─── Smooth Keyboard Mixin ──────────────────────────────────────────────────
/// A reusable mixin for any StatefulWidget that contains text fields.
///
/// Provides:
///   • Smooth animated keyboard padding (200ms easeOutCubic)
///   • Auto-scroll focused field into view (300ms easeOutCubic)
///   • Tap-outside-to-dismiss keyboard
///   • Consistent behavior across all 14+ form pages
///
/// Usage:
///   1. Add `with SmoothKeyboardMixin` to your State class
///   2. In your Scaffold, set `resizeToAvoidBottomInset: false`
///   3. Wrap scrollable content with `buildKeyboardDismissible(child:)`
///   4. Use `keyboardPadding()` at the bottom of your scroll content
///   5. For each TextField, call `attachFocusNode(node, scrollContext)` or
///      use `makeFocusNode()` which auto-registers scroll behavior
mixin SmoothKeyboardMixin<T extends StatefulWidget> on State<T>,
    TickerProviderStateMixin<T> {
  late final AnimationController _kbAnimController;
  late final Animation<double> _kbAnimation;
  double _targetKeyboardHeight = 0;
  double _currentKeyboardHeight = 0;

  /// All focus nodes created via [makeFocusNode]. Disposed automatically.
  final List<FocusNode> _managedFocusNodes = [];

  /// ScrollController to use for auto-scrolling. Set this in initState if
  /// you have a custom one; otherwise the mixin finds the nearest Scrollable.
  ScrollController? keyboardScrollController;

  @override
  void initState() {
    super.initState();
    _kbAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _kbAnimation = CurvedAnimation(
      parent: _kbAnimController,
      curve: Curves.easeOutCubic,
    );
    _kbAnimController.addListener(_onKbAnimTick);
  }

  @override
  void dispose() {
    _kbAnimController.removeListener(_onKbAnimTick);
    _kbAnimController.dispose();
    for (final node in _managedFocusNodes) {
      node.dispose();
    }
    _managedFocusNodes.clear();
    super.dispose();
  }

  void _onKbAnimTick() {
    // Interpolate between old and new keyboard heights
    final oldH = _currentKeyboardHeight;
    final newH = _targetKeyboardHeight;
    final val = oldH + (newH - oldH) * _kbAnimation.value;
    if (mounted) setState(() => _currentKeyboardHeight = val);
  }

  /// Call this in build() to get the current smoothly-animated keyboard height.
  double get smoothKeyboardHeight => _currentKeyboardHeight;

  /// Update keyboard height from MediaQuery. Call this at the top of build():
  ///   `updateKeyboardHeight(MediaQuery.viewInsetsOf(context).bottom);`
  void updateKeyboardHeight(double rawHeight) {
    if (rawHeight != _targetKeyboardHeight) {
      _targetKeyboardHeight = rawHeight;
      _kbAnimController.forward(from: 0);
    }
  }

  /// Creates a FocusNode that auto-scrolls its field into view when focused.
  /// The node is automatically disposed when the State is disposed.
  FocusNode makeFocusNode() {
    final node = FocusNode();
    _managedFocusNodes.add(node);
    node.addListener(() {
      if (node.hasFocus && node.context != null) {
        _scrollToFocused(node.context!);
      }
    });
    return node;
  }

  /// Scrolls the focused field's context into view smoothly.
  void _scrollToFocused(BuildContext fieldContext) {
    // Wait one frame so the keyboard height is applied
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scrollable = Scrollable.maybeOf(fieldContext);
      if (scrollable == null) return;
      final renderObj = fieldContext.findRenderObject();
      if (renderObj == null) return;
      scrollable.position.ensureVisible(
        renderObj,
        alignment: 0.3, // position field ~30% from top
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Wraps content with a tap-to-dismiss gesture.
  /// Use as the outermost widget inside Scaffold body.
  Widget buildKeyboardDismissible({required Widget child}) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }

  /// Returns an EdgeInsets for the bottom padding that smoothly animates
  /// with the keyboard. Use inside your scroll content:
  ///   `Padding(padding: keyboardPadding(baseBottom: 32), child: ...)`
  EdgeInsets keyboardPadding({double baseBottom = 32}) {
    return EdgeInsets.only(bottom: baseBottom + smoothKeyboardHeight);
  }
}
