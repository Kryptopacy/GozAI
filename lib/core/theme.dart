import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GozAI Design System
/// Upgraded to Premium Web Interface Guidelines (Vercel-like aesthetic).
/// Focus states, typography (Inter), tabular numbers, and glass-like elevations.
class GozAITheme {
  // --- Premium Dark Palette ---
  static const Color backgroundBlack = Color(0xFF000000); // True black
  static const Color surfacePure = Color(0xFF0A0A0A);     // Slightly elevated
  static const Color surfaceElevated = Color(0xFF141414); // Cards
  static const Color borderSubtle = Color(0xFF2E2E2E);    // 1px borders
  static const Color borderHover = Color(0xFF4A4A4A);
  
  static const Color textPrimary = Color(0xFFEDEDED);     // Not pure white to reduce eye strain
  static const Color textSecondary = Color(0xFFA1A1AA);   // Zinc-400
  static const Color primaryBlue = Color(0xFF0070F3);     // Vercel blue
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color success = Color(0xFF10B981);
  static const Color hazardAlert = Color(0xFFEF4444);

  // Semantic
  static const Color listeningPulse = primaryBlue;
  static const Color speakingPulse = accentCyan;

  static ThemeData get darkTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundBlack,
      splashFactory: NoSplash.splashFactory, // Removes material ripples for a cleaner web feel
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentCyan,
        surface: surfacePure,
        error: hazardAlert,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
    );

    // Apply strict, elegant Google Font typography (Inter)
    final textTheme = GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
      displayLarge: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.02, // Tighter tracking for large headers
      ),
      headlineMedium: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.01,
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.6, // Excellent readability
      ),
      bodyMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.5,
      ),
      // Tabular numbers for dashboards/data grids
      labelLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      focusColor: primaryBlue.withValues(alpha: 0.5), // Custom focus rings
      // Premium flat buttons with subtle borders instead of heavy shadows
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: backgroundBlack,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return Colors.white12;
            return null;
          }),
        ),
      ),
      // Clean, un-shadowed cards using 1px borders
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfacePure,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        shape: Border(bottom: BorderSide(color: borderSubtle, width: 1)),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
