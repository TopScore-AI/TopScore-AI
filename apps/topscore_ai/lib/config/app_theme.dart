import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // Theme cache: avoids rebuilding ThemeData on every SettingsProvider notify.
  // Keys are (brightness, baseSize, lineHeight).
  // ---------------------------------------------------------------------------
  static final Map<String, ThemeData> _themeCache = {};

  static ThemeData lightTheme(double baseSize, double lineHeight) {
    final key = 'light_${baseSize}_$lineHeight';
    return _themeCache.putIfAbsent(
        key, () => _buildLightTheme(baseSize, lineHeight));
  }

  static ThemeData darkTheme(double baseSize, double lineHeight) {
    final key = 'dark_${baseSize}_$lineHeight';
    return _themeCache.putIfAbsent(
        key, () => _buildDarkTheme(baseSize, lineHeight));
  }

  /// Call this when user changes theme settings so stale entries are evicted.
  static void clearCache() => _themeCache.clear();

  // Dynamic Text Theme Generator
  static TextTheme _buildTextTheme(
      Brightness brightness, double baseSize, double lineHeight) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : AppColors.backgroundDark;
    final secondaryColor =
        isDark ? const Color(0xFFCBD5E1) : AppColors.surfaceElevatedDark;
    final tertiaryColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
    final mutedColor =
        isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

    const emojiFallbacks = [
      'Noto Color Emoji',
      'Apple Color Emoji',
      'Segoe UI Emoji',
      'Symbola'
    ];

    return TextTheme(
      // Headers: Bold and Friendly Poppins
      displayLarge: GoogleFonts.poppins(
        fontSize: baseSize * 2.5,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: primaryColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      displayMedium: GoogleFonts.poppins(
        fontSize: baseSize * 2.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: primaryColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      displaySmall: GoogleFonts.poppins(
        fontSize: baseSize * 1.5,
        fontWeight: FontWeight.w700,
        color: primaryColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      headlineLarge: GoogleFonts.poppins(
        fontSize: baseSize * 1.3,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: primaryColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      headlineMedium: GoogleFonts.poppins(
        fontSize: baseSize * 1.15,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: primaryColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      headlineSmall: GoogleFonts.poppins(
        fontSize: baseSize * 1.0,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: primaryColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      titleLarge: GoogleFonts.poppins(
        fontSize: baseSize * 1.1,
        fontWeight: FontWeight.w700,
        color: primaryColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      titleMedium: GoogleFonts.poppins(
        fontSize: baseSize * 1.0,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      titleSmall: GoogleFonts.poppins(
        fontSize: baseSize * 0.9,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),

      // Body Content: Soft and Readable Nunito
      bodyLarge: GoogleFonts.nunito(
        fontSize: baseSize * 1.15,
        fontWeight: FontWeight.w400,
        height: lineHeight,
        color: secondaryColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      bodyMedium: GoogleFonts.nunito(
        fontSize: baseSize,
        fontWeight: FontWeight.w400,
        height: lineHeight,
        color: tertiaryColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      bodySmall: GoogleFonts.nunito(
        fontSize: baseSize * 0.85,
        fontWeight: FontWeight.w400,
        height: lineHeight * 0.9,
        color: mutedColor,
      ).copyWith(fontFamilyFallback: emojiFallbacks),

      // Interactive Labels: Bold Poppins
      labelLarge: GoogleFonts.poppins(
        fontSize: baseSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      labelMedium: GoogleFonts.poppins(
        fontSize: baseSize * 0.85,
        fontWeight: FontWeight.w600,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
      labelSmall: GoogleFonts.poppins(
        fontSize: baseSize * 0.7,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ).copyWith(fontFamilyFallback: emojiFallbacks),
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

  // --- PREMIUM LIGHT THEME (Home Screen Style) ---
  static ThemeData _buildLightTheme(double baseSize, double lineHeight) =>
      ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,

        // Global Rounded Geometry
        visualDensity: VisualDensity.adaptivePlatformDensity,

        // Color Scheme: Crisp & Focused (matching Home Screen)
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary, // Premium Blue #2563EB
          brightness: Brightness.light,
          primary: AppColors.primary, // #2563EB
          onPrimary: Colors.white,
          secondary: AppColors.secondary, // Teal #2D9A7C
          onSecondary: Colors.white,
          surface: Colors.white, // Pure white cards
          onSurface: AppColors.text, // Slate 900 #0F172A
          surfaceContainerHighest: const Color(0xFFF1F5F9), // Slate 100
          error: AppColors.error, // #EF4444
          outline: const Color(0xFFE2E8F0), // Slate 200
        ),

        // Background: High Resolution "Clean" Look (Home Screen)
        scaffoldBackgroundColor: AppColors.background, // Slate 50 #F8FAFC
        cardColor: Colors.white,

        // Typography: Poppins (Geometric/Bold) & Nunito (Soft/Friendly)
        textTheme: _buildTextTheme(Brightness.light, baseSize, lineHeight),

        // Component Styles (Home Screen aesthetic)
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: AppColors.text),
          titleTextStyle: GoogleFonts.poppins(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),

        iconTheme: IconThemeData(
          color: AppColors.text,
          size: 24,
        ),

        // Buttons: Premium Rounded Style (Home Screen)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, // Premium Blue
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd), // 16px rounded
            ),
            elevation: 0,
            shadowColor: AppColors.primary.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(
              horizontal: spacingLg,
              vertical: spacingMd,
            ),
            minimumSize: const Size(120, 52),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700, // Bold like Home Screen
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: spacingLg,
              vertical: spacingMd,
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Input: Modern Rounded Style (Home Screen)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd), // 16px rounded
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          hintStyle: GoogleFonts.nunito(
            fontSize: 16,
            color: AppColors.textLight,
            fontWeight: FontWeight.w400,
          ),
          labelStyle: GoogleFonts.nunito(
            fontSize: 16,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Cards: Pure White with Soft Shadows (Home Screen style)
        cardTheme: CardThemeData(
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg), // 24px rounded
          ),
          color: Colors.white,
          margin: const EdgeInsets.all(0),
        ),

        // Chips: Rounded style (for subject chips like Home Screen)
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceVariant,
          selectedColor: AppColors.primary,
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),

        // Bottom Navigation: Clean and modern (Home Screen)
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textLight,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),

        // Floating Action Button: Premium Blue (Home Screen)
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),

        // Dialogs: Rounded and modern
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
          contentTextStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),

        // Snackbar: Modern rounded style
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.text,
          contentTextStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        // Progress Indicators: Premium Blue (Home Screen)
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
          circularTrackColor: Color(0xFFE2E8F0),
        ),

        // Switch: Premium Blue (Home Screen)
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return const Color(0xFFE2E8F0);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return const Color(0xFFCBD5E1);
          }),
        ),

        // Slider: Premium Blue (Home Screen)
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: const Color(0xFFE2E8F0),
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primary.withValues(alpha: 0.2),
        ),
      );

  // --- DARK THEME: ALIGNED WITH HOME SCREEN ---
  static ThemeData _buildDarkTheme(double baseSize, double lineHeight) =>
      ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          primary: AppColors.primary, // Premium Blue
          onPrimary: Colors.white,
          secondary: AppColors.secondary, // Teal
          onSecondary: Colors.white,
          surface: AppColors.surfaceElevatedDark,
          onSurface: AppColors.textDark,
          surfaceContainerHighest: AppColors.surfaceVariantDark,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
        cardColor: AppColors.surfaceElevatedDark,
        textTheme: _buildTextTheme(Brightness.dark, baseSize, lineHeight),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.backgroundDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surfaceElevatedDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            elevation: 0,
            shadowColor: AppColors.primaryGlow.withValues(alpha: 0.4),
            minimumSize: const Size(120, 52),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceDark,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide:
                const BorderSide(color: AppColors.primaryGlow, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          hintStyle: GoogleFonts.nunito(
            fontSize: 16,
            color: AppColors.textSecondaryDark,
            fontWeight: FontWeight.w400,
          ),
          labelStyle: GoogleFonts.nunito(
            fontSize: 16,
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceVariantDark,
          selectedColor: AppColors.primary,
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceElevatedDark,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondaryDark,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceElevatedDark,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          contentTextStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondaryDark,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceElevatedDark,
          contentTextStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        // Progress Indicators: Premium Blue with glow (Dark Mode)
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primaryGlow,
          circularTrackColor: Color(0xFF1E293B),
        ),

        // Switch: Premium Blue with glow (Dark Mode)
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return const Color(0xFF475569);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryGlow;
            }
            return const Color(0xFF334155);
          }),
        ),

        // Slider: Premium Blue with glow (Dark Mode)
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.primaryGlow,
          inactiveTrackColor: const Color(0xFF334155),
          thumbColor: AppColors.primaryGlow,
          overlayColor: AppColors.primaryGlow.withValues(alpha: 0.3),
        ),
      );

  // Helper methods for soft shadows (Home Screen style)
  static List<BoxShadow> getSoftShadow({bool isDark = false}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
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
    final shadowColor = color ??
        (isDark
            ? AppColors.textSecondary
            : Colors.black.withValues(alpha: 0.05));
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

  // --- Search Field Decoration Helper (Home Screen style) ---
  static InputDecoration searchFieldDecoration({
    required String hint,
    bool isDark = false,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        Icons.search,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textLight,
      ),
      filled: true,
      fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceVariant,
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
        borderSide: BorderSide(
          color: isDark ? AppColors.primaryGlow : AppColors.primary,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      hintStyle: GoogleFonts.nunito(
        fontSize: 16,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textLight,
        fontWeight: FontWeight.w400,
      ),
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
                  ? Colors.white.withValues(alpha: opacity * 1.5)
                  : Colors.white.withValues(alpha: opacity),
              // Add a subtle background tint for better text visibility in dark mode
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.4),
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
