import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? opacity;
  final double? blur;
  final BoxBorder? border;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.opacity,
    this.blur,
    this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.all(AppTheme.spacingSm),
      child: AppTheme.buildGlassContainer(
        context,
        borderRadius: borderRadius ?? AppTheme.radiusLg,
        padding: padding ?? const EdgeInsets.all(AppTheme.spacingMd),
        opacity: opacity,
        blur: blur,
        border: border,
        gradient: gradient,
        child: child,
      ),
    );
  }
}
