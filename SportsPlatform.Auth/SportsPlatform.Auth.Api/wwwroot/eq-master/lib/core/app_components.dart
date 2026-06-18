import 'package:flutter/material.dart';

import 'animated_button.dart';
import 'design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppCard
// Flat card surface (NO gradient) at 75% opacity. Single source of truth for
// every card in the app. Resolves:
//   • "Cards overall app 75% opacity background (all pages)"
//   • "team card gradient removal"
// ─────────────────────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? radius;
  final Color? color;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.radius,
    this.color,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius ?? AppRadius.lg);
    final card = Container(
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color ?? AppColors.cardFill(context),
        borderRadius: br,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: br,
        onTap: onTap,
        child: card,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppInput
// Shared text field. Strokeless, filled with the card color @ 75% opacity,
// consistent radius. Resolves:
//   • "remove all strokes of inputs in all screens"
//   • "all app input fields should be the same as cards colors with opacity 75%"
//   • "make the message input like app input fields"
//   • "inputs of adding medical are not like the app theme"
//
// Pass a [validator] to switch to a TextFormField (for Form-based screens).
// ─────────────────────────────────────────────────────────────────────────────
class AppInput extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final String? Function(String?)? validator;
  final EdgeInsetsGeometry contentPadding;

  const AppInput({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.validator,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  });

  InputDecoration _decoration(BuildContext context) {
    // Strokeless: every border state is BorderSide.none.
    final noStroke = OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: AppRadius.input,
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
      hintStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppColors.textSecondary(context))
          : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.inputFill(context),
      contentPadding: contentPadding,
      border: noStroke,
      enabledBorder: noStroke,
      focusedBorder: noStroke,
      errorBorder: noStroke,
      focusedErrorBorder: noStroke,
      disabledBorder: noStroke,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: AppColors.textPrimary(context));
    if (validator != null) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        maxLines: obscureText ? 1 : maxLines,
        minLines: minLines,
        enabled: enabled,
        validator: validator,
        style: style,
        decoration: _decoration(context),
      );
    }
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      enabled: enabled,
      style: style,
      decoration: _decoration(context),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppButton
// Consistent rounded buttons. Resolves:
//   • "inconsistent roundness through app buttons"
//   • "outlined button stroke should be green"
//   • "in coach add plan button should be rounded"
// ─────────────────────────────────────────────────────────────────────────────
enum _AppButtonKind { primary, outlined }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;
  final double height;
  final _AppButtonKind _kind;

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    this.height = 52,
  }) : _kind = _AppButtonKind.primary;

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    this.height = 52,
  }) : _kind = _AppButtonKind.outlined;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: AppRadius.button);
    final isPrimary = _kind == _AppButtonKind.primary;
    final minSize = Size(expand ? double.infinity : 0, height);

    final Widget content = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: isPrimary ? Colors.white : AppColors.brand,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          );

    if (isPrimary) {
      return AnimatedButton.primary(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            minimumSize: minSize,
            elevation: 0,
            shape: shape,
          ),
          onPressed: isLoading ? null : onPressed,
          child: content,
        ),
      );
    }

    return AnimatedButton.secondary(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          minimumSize: minSize,
          side: const BorderSide(color: AppColors.outline, width: 1.5),
          shape: shape,
        ),
        onPressed: isLoading ? null : onPressed,
        child: content,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppEmptyState
// Friendly placeholder for empty lists. Resolves:
//   • "in Game stats page add no files yet no videos yet and so on in all app"
//   • "don't leave it empty"
//   • "no members message yet should be centered"
// ─────────────────────────────────────────────────────────────────────────────
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.action,
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary(context)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppOptionsMenu
// Reusable ⋮ menu with Edit / Delete. Resolves:
//   • "add ⋮ (options) for editing and deleting (in all edit delete in app)"
// ─────────────────────────────────────────────────────────────────────────────
class AppOptionsMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Color? iconColor;
  final List<PopupMenuEntry<String>> extraItems;
  final void Function(String value)? onExtraSelected;

  const AppOptionsMenu({
    super.key,
    this.onEdit,
    this.onDelete,
    this.iconColor,
    this.extraItems = const [],
    this.onExtraSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: iconColor ?? AppColors.textSecondary(context)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
          default:
            onExtraSelected?.call(value);
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 20),
                SizedBox(width: 12),
                Text(AppLocalizations.of(context).edit),
              ],
            ),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                SizedBox(width: 12),
                Text(AppLocalizations.of(context).delete, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ...extraItems,
      ],
    );
  }
}
