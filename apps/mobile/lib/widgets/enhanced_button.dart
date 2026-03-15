import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


enum ButtonVariant { primary, secondary, outline, ghost, danger }
enum ButtonSize { small, medium, large }

class EnhancedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final Color? customColor;

  const EnhancedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null && !isLoading;

    final (double fontSize, double iconSize) = switch (size) {
      ButtonSize.small => (13.0, 16.0),
      ButtonSize.medium => (15.0, 20.0),
      ButtonSize.large => (18.0, 24.0),
    };

    final textColor = _getTextColor(theme);

    final Widget buttonChild = isLoading
        ? SizedBox(
            height: iconSize,
            width: iconSize,
            child: CircularProgressIndicator.adaptive(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: _ButtonLayout(
        variant: variant,
        isEnabled: isEnabled,
        onPressed: onPressed,
        customColor: customColor,
        child: buttonChild,
      ),
    );
  }

  Color _getTextColor(ThemeData theme) {
    return switch (variant) {
      ButtonVariant.primary => theme.colorScheme.onPrimary,
      ButtonVariant.secondary => theme.colorScheme.onSecondaryContainer,
      ButtonVariant.outline || ButtonVariant.ghost =>
        customColor ?? theme.colorScheme.primary,
      ButtonVariant.danger => theme.colorScheme.onError,
    };
  }
}

class _ButtonLayout extends StatelessWidget {
  final ButtonVariant variant;
  final bool isEnabled;
  final VoidCallback? onPressed;
  final Color? customColor;
  final Widget child;

  const _ButtonLayout({
    required this.variant,
    required this.isEnabled,
    this.onPressed,
    this.customColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return switch (variant) {
      ButtonVariant.primary => FilledButton(
          onPressed: isEnabled ? onPressed : null,
          style: customColor != null
              ? FilledButton.styleFrom(backgroundColor: customColor)
              : null,
          child: child,
        ),
      ButtonVariant.secondary => FilledButton.tonal(
          onPressed: isEnabled ? onPressed : null,
          child: child,
        ),
      ButtonVariant.outline => OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: customColor != null
              ? OutlinedButton.styleFrom(
                  foregroundColor: customColor,
                  side: BorderSide(color: customColor!),
                )
              : null,
          child: child,
        ),
      ButtonVariant.ghost => TextButton(
          onPressed: isEnabled ? onPressed : null,
          style: customColor != null
              ? TextButton.styleFrom(foregroundColor: customColor)
              : null,
          child: child,
        ),
      ButtonVariant.danger => FilledButton(
          onPressed: isEnabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: child,
        ),
    };
  }
}

