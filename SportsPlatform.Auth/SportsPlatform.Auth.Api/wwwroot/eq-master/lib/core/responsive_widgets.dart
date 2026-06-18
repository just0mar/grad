import 'package:flutter/material.dart';

import 'responsive_system.dart';

class ResponsivePrimaryButton extends StatelessWidget {
  final BuildContext context;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  const ResponsivePrimaryButton({
    super.key,
    required this.context,
    required this.label,
    required this.onPressed,
    this.backgroundColor = Colors.green,
    this.foregroundColor = Colors.white,
  }) : _icon = null;

  const ResponsivePrimaryButton.icon({
    super.key,
    required this.context,
    required this.label,
    required this.onPressed,
    required IconData icon,
    this.backgroundColor = Colors.green,
    this.foregroundColor = Colors.white,
  }) : _icon = icon;

  final IconData? _icon;

  @override
  Widget build(BuildContext _) {
    final Widget child = _icon == null
        ? Text(label, style: const TextStyle(fontFamily: 'SFPro'))
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontFamily: 'SFPro')),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: ResponsiveSystem.buttonHeight(context),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
