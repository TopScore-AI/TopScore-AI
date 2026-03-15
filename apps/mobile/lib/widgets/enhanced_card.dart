import 'package:flutter/material.dart';
import '../config/app_theme.dart';


class EnhancedCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final Gradient? gradient;
  final double? elevation;
  final double? borderRadius;
  final Border? border;
  final bool enableHoverEffect;
  final bool enablePressEffect;
  final bool isGlass;

  const EnhancedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.gradient,
    this.elevation,
    this.borderRadius,
    this.border,
    this.enableHoverEffect = true,
    this.enablePressEffect = true,
    this.isGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.cardColor;
    final radius = borderRadius ?? AppTheme.radiusLg;
    final elevationVal = elevation ?? AppTheme.elevationSm;

    final Widget cardContent = Padding(
      padding: padding ?? const EdgeInsets.all(AppTheme.spacingMd),
      child: child,
    );

    final Widget interactiveContent = onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: cardContent,
          )
        : cardContent;

    if (isGlass) {
      return Container(
        margin: margin ?? const EdgeInsets.all(AppTheme.spacingSm),
        child: AppTheme.buildGlassContainer(
          context,
          padding: EdgeInsets.zero,
          borderRadius: radius,
          border: border,
          gradient: gradient,
          child: interactiveContent,
        ),
      );
    }

    return Card(
      elevation: elevationVal,
      margin: margin ?? const EdgeInsets.all(AppTheme.spacingSm),
      color: gradient == null ? cardColor : Colors.transparent,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: border?.top ?? BorderSide.none,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: gradient,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: interactiveContent,
        ),
      ),
    );
  }
}

