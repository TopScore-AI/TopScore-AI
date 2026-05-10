import 'package:flutter/material.dart';

/// Standard branded spinner for the TopScore AI app.
///
/// Use [AppSpinner] everywhere a loading indicator is needed.
/// It uses the theme's primary color and a consistent stroke width.
///
/// For full-screen loading, wrap in [AppSpinner.center].
/// For list pagination footers, use [AppSpinner.paginate].
class AppSpinner extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const AppSpinner({
    super.key,
    this.size = 28,
    this.strokeWidth = 2.5,
    this.color,
  });

  /// Centered full-area spinner — drop-in for `Center(child: CircularProgressIndicator())`.
  static Widget center(
      {double size = 28, double strokeWidth = 2.5, Color? color}) {
    return Center(
      child: AppSpinner(size: size, strokeWidth: strokeWidth, color: color),
    );
  }

  /// Small inline spinner for pagination footers.
  static Widget paginate() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: AppSpinner(size: 22, strokeWidth: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spinnerColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
        strokeCap: StrokeCap.round,
      ),
    );
  }
}
