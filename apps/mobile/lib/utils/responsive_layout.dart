import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// A utility widget that builds different layouts based on screen width.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppTheme.breakpointMobile;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppTheme.breakpointMobile &&
      MediaQuery.sizeOf(context).width < AppTheme.breakpointTablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppTheme.breakpointTablet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppTheme.breakpointTablet) {
          return desktop;
        }
        if (constraints.maxWidth >= AppTheme.breakpointMobile) {
          return tablet ?? desktop;
        }
        return mobile;
      },
    );
  }
}

/// A wrapper that limits the width of its child on large screens.
class CenterContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const CenterContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppTheme.maxContentWidth,
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// A SliverGridDelegate that automatically adjusts the crossAxisCount
/// based on the available width.
class ResponsiveGridDelegate extends SliverGridDelegateWithMaxCrossAxisExtent {
  const ResponsiveGridDelegate({
    required super.maxCrossAxisExtent,
    super.mainAxisSpacing = 0.0,
    super.crossAxisSpacing = 0.0,
    super.childAspectRatio = 1.0,
    super.mainAxisExtent,
  });

  static int getCrossAxisCount(BuildContext context, {double itemWidth = 300}) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < AppTheme.breakpointMobile) return 1;
    if (width < AppTheme.breakpointTablet) return 2;
    return (width / itemWidth).floor().clamp(2, 4);
  }
}
