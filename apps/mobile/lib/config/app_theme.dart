import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

@immutable
class DesignTokens extends ThemeExtension<DesignTokens> {
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> glowShadow;
  final double glassOpacity;
  final double glassBlur;
  final List<Shadow> glassTextShadow;

  const DesignTokens({
    required this.shadowSm,
    required this.shadowMd,
    required this.glowShadow,
    required this.glassOpacity,
    required this.glassBlur,
    required this.glassTextShadow,
  });

  @override
  DesignTokens copyWith({
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? glowShadow,
    double? glassOpacity,
    double? glassBlur,
    List<Shadow>? glassTextShadow,
  }) {
    return DesignTokens(
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      glowShadow: glowShadow ?? this.glowShadow,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      glassBlur: glassBlur ?? this.glassBlur,
      glassTextShadow: glassTextShadow ?? this.glassTextShadow,
    );
  }

  @override
  DesignTokens lerp(ThemeExtension<DesignTokens>? other, double t) {
    if (other is! DesignTokens) return this;
    return DesignTokens(
      shadowSm: shadowSm, // Simplified for now
      shadowMd: shadowMd,
      glowShadow: glowShadow,
      glassOpacity: lerpDouble(glassOpacity, other.glassOpacity, t) ?? glassOpacity,
      glassBlur: lerpDouble(glassBlur, other.glassBlur, t) ?? glassBlur,
      glassTextShadow: glassTextShadow, // Simplified
    );
  }
}

class AppTheme {
  // Breakpoints for responsive design
  static const double breakpointMobile = 600;
  static const double breakpointTablet = 1024;

  // Max width for content on large screens to prevent excessive stretching
  static const double maxContentWidth = 1200;

  // Spacing system
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2xl = 48.0;

  // Kid-friendly larger radii
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 40.0;
  static const double radiusFull = 999.0;

  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 16.0;

  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: GoogleFonts.quicksand().fontFamily,
    extensions: [
      DesignTokens(
        shadowSm: _getShadow(elevation: elevationSm, isDark: false),
        shadowMd: _getShadow(elevation: elevationMd, isDark: false),
        glowShadow: getGlowShadow(AppColors.primary, intensity: 0.2),
        glassOpacity: 0.15,
        glassBlur: 25.0,
        glassTextShadow: [
          const Shadow(
            color: Colors.black12,
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
    ],
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.kidBlue,
      brightness: Brightness.light,
      primary: AppColors.kidBlue,
      onPrimary: Colors.white,
      secondary: AppColors.kidTeal,
      onSecondary: Colors.white,
      tertiary: AppColors.kidPink,
      onTertiary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainer: AppColors.surfaceVariant,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.border,
    ),
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.surface,
    textTheme: _textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: AppColors.text),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        fontFamily: GoogleFonts.quicksand().fontFamily,
        color: AppColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.text),
    elevatedButtonTheme: _elevatedButtonTheme,
    textButtonTheme: _textButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    inputDecorationTheme: _inputDecorationTheme,
    cardTheme: _cardTheme,
    chipTheme: _chipTheme,
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: spacingMd,
    ),
    navigationBarTheme: _navigationBarTheme,
    bottomNavigationBarTheme: _bottomNavigationBarTheme,
    snackBarTheme: _snackBarTheme,
    dialogTheme: _dialogTheme,
    bottomSheetTheme: _bottomSheetTheme,
    floatingActionButtonTheme: _fabTheme,
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.kidBlue,
      linearTrackColor: AppColors.surfaceVariant,
    ),
    switchTheme: _switchTheme,
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: GoogleFonts.quicksand().fontFamily,
    extensions: [
      DesignTokens(
        shadowSm: _getShadow(elevation: elevationSm, isDark: true),
        shadowMd: _getShadow(elevation: elevationMd, isDark: true),
        glowShadow: getGlowShadow(AppColors.kidCyan, intensity: 0.3),
        glassOpacity: 0.2,
        glassBlur: 35.0,
        glassTextShadow: [
          const Shadow(
            color: Colors.black26,
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
    ],
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.kidPurple,
      brightness: Brightness.dark,
      primary: AppColors.kidPurple,
      onPrimary: Colors.white,
      secondary: AppColors.kidLavender,
      onSecondary: Colors.white,
      tertiary: AppColors.kidPink,
      onTertiary: Colors.white,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDark,
      surfaceContainer: AppColors.surfaceVariantDark,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.borderDark,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDark,
    cardColor: AppColors.surfaceElevatedDark,
    textTheme: _textTheme.apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: AppColors.textDark),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        fontFamily: GoogleFonts.quicksand().fontFamily,
        color: AppColors.textDark,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.textDark),
    elevatedButtonTheme: _elevatedButtonTheme,
    textButtonTheme: _textButtonThemeDark,
    outlinedButtonTheme: _outlinedButtonThemeDark,
    inputDecorationTheme: _inputDecorationThemeDark,
    cardTheme: _cardThemeDark,
    chipTheme: _chipThemeDark,
    dividerTheme: const DividerThemeData(
      color: AppColors.borderDark,
      thickness: 1,
      space: spacingMd,
    ),
    snackBarTheme: _snackBarThemeDark,
    navigationBarTheme: _navigationBarThemeDark,
    dialogTheme: _dialogThemeDark,
    bottomSheetTheme: _bottomSheetThemeDark,
    floatingActionButtonTheme: _fabThemeDark,
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.kidCyan,
      linearTrackColor: AppColors.surfaceVariantDark,
    ),
    switchTheme: _switchThemeDark,
  );

  static List<BoxShadow> _getShadow({
    double elevation = elevationMd,
    required bool isDark,
  }) {
    final shadowColor = isDark ? Colors.black54 : Colors.black12;
    return [
      BoxShadow(
        color: shadowColor,
        blurRadius: elevation * 2,
        offset: Offset(0, elevation / 2),
        spreadRadius: 0,
      ),
    ];
  }

  static List<BoxShadow> getGlowShadow(Color color, {double intensity = 0.4}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: intensity),
        blurRadius: 20,
        offset: const Offset(0, 8),
        spreadRadius: 0,
      ),
    ];
  }

  static Widget buildGlassContainer(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry? padding,
    double? borderRadius,
    double? opacity,
    double? blur,
    BoxBorder? border,
    Gradient? gradient,
  }) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? radiusLg),
      child: RepaintBoundary(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur ?? tokens.glassBlur,
            sigmaY: blur ?? tokens.glassBlur,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surface
                  .withValues(alpha: opacity ?? tokens.glassOpacity),
              gradient: gradient ?? (isDark 
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.15), // Increased from 0.1
                      Colors.white.withValues(alpha: 0.05), // Increased from 0.03
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.75),
                      Colors.white.withValues(alpha: 0.45),
                    ],
                  )),
              borderRadius: BorderRadius.circular(borderRadius ?? radiusLg),
              border: border ??
                  Border.all(
                    color: (isDark ? Colors.white : Colors.white).withValues(alpha: 0.2),
                    width: 1.5,
                  ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.black12).withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  static TextStyle applyGlassShadow(BuildContext context, TextStyle style) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    return style.copyWith(
      shadows: [...(style.shadows ?? []), ...tokens.glassTextShadow],
    );
  }

  static InputDecoration searchFieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search, size: 20),
      filled: true,
      fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // Private theme definitions to keep things concise
  static final _textTheme = GoogleFonts.quicksandTextTheme().copyWith(
    displayLarge: const TextStyle(fontWeight: FontWeight.w700),
    displayMedium: const TextStyle(fontWeight: FontWeight.w700),
    displaySmall: const TextStyle(fontWeight: FontWeight.w600),
    headlineLarge: const TextStyle(fontWeight: FontWeight.w700),
    headlineMedium: const TextStyle(fontWeight: FontWeight.w700),
    headlineSmall: const TextStyle(fontWeight: FontWeight.w600),
    titleLarge: const TextStyle(fontWeight: FontWeight.w700),
    titleMedium: const TextStyle(fontWeight: FontWeight.w600),
    titleSmall: const TextStyle(fontWeight: FontWeight.w600),
    bodyLarge: const TextStyle(fontWeight: FontWeight.w500),
    bodyMedium: const TextStyle(fontWeight: FontWeight.w500),
    bodySmall: const TextStyle(fontWeight: FontWeight.w500),
    labelLarge: const TextStyle(fontWeight: FontWeight.w600),
    labelMedium: const TextStyle(fontWeight: FontWeight.w600),
    labelSmall: const TextStyle(fontWeight: FontWeight.w600),
  );

  static final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.kidBlue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        horizontal: spacingLg,
        vertical: spacingMd,
      ),
      minimumSize: const Size(120, 48),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  static final _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.kidBlue,
      padding: const EdgeInsets.symmetric(
        horizontal: spacingMd,
        vertical: spacingSm,
      ),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  static final _textButtonThemeDark = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.kidCyan,
      padding: const EdgeInsets.symmetric(
        horizontal: spacingMd,
        vertical: spacingSm,
      ),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  static final _outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.kidBlue,
      side: const BorderSide(color: AppColors.kidBlue, width: 2.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: spacingLg,
        vertical: spacingMd,
      ),
      minimumSize: const Size(120, 48),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );

  static final _outlinedButtonThemeDark = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.kidCyan,
      side: const BorderSide(color: AppColors.kidCyan, width: 2.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: spacingLg,
        vertical: spacingMd,
      ),
      minimumSize: const Size(120, 48),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );

  static final _inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: const BorderSide(color: AppColors.border, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: const BorderSide(color: AppColors.border, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: const BorderSide(color: AppColors.kidBlue, width: 2.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: spacingMd,
      vertical: spacingMd,
    ),
  );

  static final _inputDecorationThemeDark = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceElevatedDark,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: const BorderSide(color: AppColors.borderDark, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: const BorderSide(color: AppColors.borderDark, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: const BorderSide(color: AppColors.kidCyan, width: 2.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: spacingMd,
      vertical: spacingMd,
    ),
  );

  static final _cardTheme = CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusLg),
      side: const BorderSide(color: AppColors.border, width: 1),
    ),
    color: AppColors.surface,
    margin: const EdgeInsets.all(spacingSm),
  );

  static final _cardThemeDark = CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusLg),
      side: const BorderSide(color: AppColors.borderDark, width: 1),
    ),
    color: AppColors.surfaceElevatedDark,
    margin: const EdgeInsets.all(spacingSm),
  );

  static final _chipTheme = ChipThemeData(
    backgroundColor: AppColors.surfaceVariant,
    labelStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: spacingMd,
      vertical: spacingSm,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusFull),
    ),
  );

  static final _chipThemeDark = ChipThemeData(
    backgroundColor: AppColors.surfaceVariantDark,
    labelStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.textDark,
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: spacingMd,
      vertical: spacingSm,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusFull),
    ),
  );

  static final _snackBarTheme = SnackBarThemeData(
    backgroundColor: AppColors.primaryDark,
    contentTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    behavior: SnackBarBehavior.floating,
  );

  static final _snackBarThemeDark = SnackBarThemeData(
    backgroundColor: AppColors.surfaceElevatedDark,
    contentTextStyle: const TextStyle(
      color: AppColors.textDark,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    behavior: SnackBarBehavior.floating,
  );

  static final _navigationBarTheme = NavigationBarThemeData(
    backgroundColor: Colors.transparent,
    elevation: 0,
    indicatorColor: AppColors.kidBlue.withValues(alpha: 0.2),
    indicatorShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.kidBlue,
        );
      }
      return const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: AppColors.kidBlue, size: 28);
      }
      return const IconThemeData(color: AppColors.textSecondary, size: 24);
    }),
  );

  static final _bottomNavigationBarTheme = BottomNavigationBarThemeData(
    backgroundColor: Colors.transparent,
    elevation: 0,
    selectedItemColor: AppColors.kidBlue,
    unselectedItemColor: AppColors.textSecondary,
    selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
    type: BottomNavigationBarType.fixed,
    selectedIconTheme: const IconThemeData(size: 28),
  );

  static final _navigationBarThemeDark = NavigationBarThemeData(
    backgroundColor: Colors.transparent,
    elevation: 0,
    indicatorColor: AppColors.kidCyan.withValues(alpha: 0.25),
    indicatorShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.kidCyan,
        );
      }
      return const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondaryDark,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: AppColors.kidCyan, size: 28);
      }
      return const IconThemeData(color: AppColors.textSecondaryDark, size: 24);
    }),
  );

  static final _dialogTheme = DialogThemeData(
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusLg),
    ),
    titleTextStyle: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
    ),
    contentTextStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
  );

  static final _dialogThemeDark = DialogThemeData(
    backgroundColor: AppColors.surfaceElevatedDark,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusLg),
    ),
    titleTextStyle: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: AppColors.textDark,
    ),
    contentTextStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondaryDark,
    ),
  );

  static final _bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    dragHandleColor: AppColors.textSecondary.withValues(alpha: 0.4),
    dragHandleSize: const Size(48, 6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
    ),
  );

  static final _bottomSheetThemeDark = BottomSheetThemeData(
    backgroundColor: AppColors.surfaceElevatedDark,
    dragHandleColor: AppColors.textSecondaryDark.withValues(alpha: 0.4),
    dragHandleSize: const Size(48, 6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
    ),
  );

  static final _fabTheme = FloatingActionButtonThemeData(
    backgroundColor: AppColors.kidBlue,
    foregroundColor: Colors.white,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusLg),
    ),
  );

  static final _fabThemeDark = FloatingActionButtonThemeData(
    backgroundColor: AppColors.kidCyan,
    foregroundColor: Colors.white,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusLg),
    ),
  );

  static final _switchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.kidBlue;
      return AppColors.textSecondary;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.kidBlue.withValues(alpha: 0.5);
      }
      return AppColors.surfaceVariant;
    }),
  );

  static final _switchThemeDark = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.kidCyan;
      return AppColors.textSecondaryDark;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.kidCyan.withValues(alpha: 0.5);
      }
      return AppColors.surfaceVariantDark;
    }),
  );
}
