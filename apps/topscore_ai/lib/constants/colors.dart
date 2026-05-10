import 'package:flutter/material.dart';

class AppColors {
  // TopScore brand colors
  static const Color topscoreBlue = Color(0xFF2B4E9A); // Primary Blue
  static const Color topscoreTeal = Color(0xFF2D9A7C); // Secondary/Accent Teal
  static const Color topscoreDark = Color(0xFF1F2633); // Footer/Dark

  // AI Tutor accent — used for quiz/flashcard highlights and AI-generated content
  static const Color aiAccent = Color(0xFF6C63FF); // Purple accent

  // Paystack checkout bar colour
  static const Color paystackBlue = Color(0xFF09A5DB);

  // Primary Colors (Mapped to TopScore)
  static const Color primaryBlue = topscoreBlue;
  // keeping primaryPurple for backward compatibility strictly as an alias for migration
  static const Color primaryPurple = topscoreBlue;
  static const Color primaryDark = topscoreDark;

  // Accent Colors
  static const Color accentTeal = topscoreTeal;
  static const Color accentGreen =
      Color(0xFF2D9A7C); // Match TopScore Teal/Green
  static const Color accentEmerald = Color(0xFF10b981);

  // Secondary Colors
  static const Color secondaryBlue = Color(0xFF3498db);
  // These might still be used for secondary elements, keeping them distinct but complementary
  static const Color secondaryViolet = Color(0xFF8b5cf6);
  static const Color secondaryPink = Color(0xFFec4899);

  static const Color black = Color(0xFF0f0f23);
  static const Color white = Color(0xFFFFFFFF);

  // App Theme Aliases - This is what main.dart uses (matching Home Screen)
  static const Color primary =
      Color(0xFF2563EB); // Premium Blue (Home Screen primary)
  static const Color secondary =
      topscoreTeal; // Teal accent (Home Screen secondary)
  static const Color accent = topscoreTeal; // Teal accent

  // Enhanced UI Colors
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);
  static const Color shimmerBase = Color(0xFFF5F5F5);
  static const Color shimmerHighlight = white;
  static const Color shimmerBaseDark = Color(0xFF252525);
  static const Color shimmerHighlightDark = Color(0xFF2C2C2C);

  // Light Mode Backgrounds - Crisp and modern (Home Screen style)
  static const Color background =
      Color(0xFFF8FAFC); // Slate 50 - matches Home Screen
  static const Color surface = white; // Pure white cards
  static const Color surfaceVariant =
      Color(0xFFF1F5F9); // Slate 100 - subtle backgrounds
  static const Color surfaceElevated = white; // Elevated cards

  // Dark Mode Colors - Deep Navy EdTech palette (not pure black)
  static const Color backgroundDark = Color(0xFF0D1B2A); // Deep Navy
  static const Color surfaceDark = Color(0xFF112240); // Navy surface
  static const Color surfaceVariantDark = Color(0xFF1A2F4A); // Elevated variant
  static const Color surfaceElevatedDark = Color(0xFF162035); // Cards & modals
  static const Color textDark = Color(0xFFF0F4FF); // Soft blue-white
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Glow Colors (for dark mode luminous borders & shadows)
  static const Color primaryGlow = Color(0xFF3B82F6);
  static const Color successGlow = Color(0xFF22C55E);
  static const Color warningGlow = Color(0xFFFBBF24);
  static const Color accentGlow = Color(0xFF8B5CF6);

  // Text colors (Light mode) - Premium Slate (Home Screen hierarchy)
  static const Color text = Color(0xFF0F172A); // Slate 900 - primary text
  static const Color textSecondary =
      Color(0xFF64748B); // Slate 500 - secondary text (Home Screen)
  static const Color textLight = Color(0xFF94A3B8); // Slate 400 - muted text
  static const Color textInverse = white;

  // Border colors - Softer, more subtle
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF1E1E2E); // Richer than pure gray

  // Status colors
  static const Color success = Color(0xFF10b981);
  static const Color warning = Color(0xFFf59e0b);
  static const Color error = Color(0xFFef4444);
  static const Color info = Color(0xFF3b82f6);

  // Feature Card Colors - Updated to respect the new palette where appropriate
  static const Color cardBlue = topscoreBlue;
  static const Color cardGreen = topscoreTeal;
  static const Color cardPurple = Color(0xFF8b5cf6);
  static const Color cardPink = Color(0xFFec4899);
  static const Color cardOrange = Color(0xFFf97316);
  static const Color cardTeal = Color(0xFF14b8a6);

  // Legacy Google Colors (for compatibility)
  static const Color googleBlue = secondaryBlue;
  static const Color googleRed = error;
  static const Color googleYellow = warning;
  static const Color googleGreen = accentGreen;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [topscoreBlue, Color(0xFF3B5EAA)], // Blue gradient
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [topscoreBlue, Color(0xFF203A75), topscoreTeal],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [topscoreTeal, Color(0xFF3DBFA0)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D1B2A), Color(0xFF112240)],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x30FFFFFF), Color(0x10FFFFFF)],
  );

  // Backward compatibility aliases
  static const LinearGradient secondaryGradient = accentGradient;
  static const LinearGradient googleGradient = heroGradient;
  static const LinearGradient blackGradient = darkGradient;
}
