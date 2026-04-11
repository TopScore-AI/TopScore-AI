import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class AppTheme {
  // Dynamic Text Theme Generator
  static TextTheme _buildTextTheme(Brightness brightness, double baseSize, double lineHeight) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B);
    final tertiaryColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
    final mutedColor = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

    return TextTheme(
      // Headers: Bold and Friendly Poppins
      displayLarge: GoogleFonts.poppins(
          fontSize: baseSize * 2.5, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: primaryColor),
      displayMedium: GoogleFonts.poppins(
          fontSize: baseSize * 2.0, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: primaryColor),
      displaySmall: GoogleFonts.poppins(
          fontSize: baseSize * 1.5, fontWeight: FontWeight.w700, color: primaryColor),
      headlineLarge: GoogleFonts.poppins(
          fontSize: baseSize * 1.3, fontWeight: FontWeight.w700, height: 1.2, color: primaryColor),
      headlineMedium: GoogleFonts.poppins(
          fontSize: baseSize * 1.15, fontWeight: FontWeight.w600, height: 1.25, color: primaryColor),
      headlineSmall: GoogleFonts.poppins(
          fontSize: baseSize * 1.0, fontWeight: FontWeight.w600, height: 1.3, color: primaryColor),
      titleLarge: GoogleFonts.poppins(
          fontSize: baseSize * 1.1, fontWeight: FontWeight.w700, color: primaryColor),
      titleMedium: GoogleFonts.poppins(
          fontSize: baseSize * 1.0, fontWeight: FontWeight.w600, color: secondaryColor),
      titleSmall: GoogleFonts.poppins(
          fontSize: baseSize * 0.9, fontWeight: FontWeight.w600, color: secondaryColor),
      
      // Body Content: Soft and Readable Nunito
      bodyLarge: GoogleFonts.nunito(
          fontSize: baseSize * 1.15,
          fontWeight: FontWeight.w400,
          height: lineHeight,
          color: secondaryColor),
      bodyMedium: GoogleFonts.nunito(
          fontSize: baseSize,
          fontWeight: FontWeight.w400,
          height: lineHeight,
          color: tertiaryColor),
      bodySmall: GoogleFonts.nunito(
          fontSize: baseSize * 0.85,
          fontWeight: FontWeight.w400,
          height: lineHeight * 0.9,
          color: mutedColor),
      
      // Interactive Labels: Bold Poppins
      labelLarge: GoogleFonts.poppins(
          fontSize: baseSize, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      labelMedium: GoogleFonts.poppins(
          fontSize: baseSize * 0.85, fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.poppins(
          fontSize: baseSize * 0.7, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    );
  }

  // Spacing constants for a balanced layout
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2xl = 48.0;

  // Animation durations
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // Border radius constants - more rounded for a friendly feel
  static const double radiusSm = 10.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;
  static const double radiusFull = 999.0;

  // Elevation constants - subtle for premium look
  static const double elevationNone = 0.0;
  static const double elevationSm = 2.0;

  // --- PREMIUM LIGHT THEME ---
  static ThemeData lightTheme(double baseSize, double lineHeight) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // Global Rounded Geometry
    visualDensity: VisualDensity.adaptivePlatformDensity,

    // Color Scheme: Crisp & Focused
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB), // TopScore Blue
      brightness: Brightness.light,
      primary: const Color(0xFF2563EB),
      onPrimary: Colors.white,
      secondary: const Color(0xFF2D9A7C), // Friendly Teal
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF0F172A), // Slate 900
      surfaceContainerHighest: const Color(0xFFF1F5F9), // Slate 100
      error: const Color(0xFFEF4444),
      outline: const Color(0xFFE2E8F0), // Slate 200
    ),

    // Background: High Resolution "Clean" Look
    scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
    cardColor: Colors.white,

    // Typography: Poppins (Geometric/Bold) & Nunito (Soft/Friendly)
    textTheme: _buildTextTheme(Brightness.light, baseSize, lineHeight),

    // Component Styles
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'Poppins',
      ),
    ),

    iconTheme: const IconThemeData(
      color: Color(0xFF0F172A),
      size: 24,
    ),

    // Buttons: Premium Pill Shape
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        shape: const StadiumBorder(), // Pill shape
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingMd,
        ),
        minimumSize: const Size(120, 52),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2563EB),
        side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingMd,
        ),
      ),
    ),

    // Input: Modern Rounded Slate
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusFull),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusFull),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusFull),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusFull),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      hintStyle:
          GoogleFonts.nunito(fontSize: 16, color: const Color(0xFF94A3B8)),
    ),

    // Cards: Pure White with Soft Shadows
    cardTheme: CardThemeData(
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
      color: Colors.white,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF2563EB),
      unselectedItemColor: Color(0xFF94A3B8),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );

  // --- DARK THEME: ALIGNED GEOMETRY ---
  static ThemeData darkTheme(double baseSize, double lineHeight) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      error: AppColors.error,
    ),

    scaffoldBackgroundColor: AppColors.backgroundDark,
    cardColor: AppColors.surfaceElevatedDark,

    textTheme: _buildTextTheme(Brightness.dark, baseSize, lineHeight),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'Poppins',
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surfaceElevatedDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        elevation: 0,
        minimumSize: const Size(120, 52),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusFull),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusFull),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusFull),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
      ),
      hintStyle: GoogleFonts.nunito(fontSize: 16, color: const Color(0xFF64748B)),
    ),
  );

  // Helper methods for soft shadows
  static List<BoxShadow> getSoftShadow() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 24,
        offset: const Offset(0, 8),
        spreadRadius: 0,
      ),
    ];
  }

  // Legacy support for getShadow
  static List<BoxShadow> getShadow({
    double elevation = 4.0,
    Color? color,
    bool isDark = false,
  }) {
    final shadowColor = color ?? (isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.05));
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

  // --- Search Field Decoration Helper ---
  static InputDecoration searchFieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 0),
    );
  }

  // Support for localized glass containers
  static Widget buildGlassContainer(
    BuildContext context, {
    required Widget child,
    double blur = 12.0,
    double opacity = 0.05,
    double borderRadius = 24.0,
    double? width,
    double? height,
    BoxBorder? border,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: opacity)
                  : Colors.white.withValues(alpha: opacity),
              // Add a subtle background tint for better text visibility in dark mode
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.4),
                    width: 1.5,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

