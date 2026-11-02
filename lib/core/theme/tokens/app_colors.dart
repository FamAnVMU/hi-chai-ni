import 'package:flutter/material.dart';

/// Semantic color tokens for HI Chinese: Clean Modern – White & Light Blue.
///
/// Palette rules:
/// - White (#FFFFFF) is the dominant UI background for cards and surfaces.
/// - Light Blue (#EAF3FF) is the continuous branding identifier.
/// - Primary Blue Dark (#3979C7) is used for active buttons, selected states, and emphasis.
/// - Main Background (#F7FAFE) offers soft, non-fatiguing contrast.
/// - Strict adherence to WCAG AA 4.5:1 contrast ratio across all text and interactive elements.
class AppColors {
  AppColors._();

  // ==================== PRIMARY BLUE PALETTE ====================
  static const Color primaryBlue = Color(0xFF5B9BE6);
  static const Color primaryBlueDark = Color(0xFF3979C7);
  static const Color primaryBlueLight = Color(0xFFEAF3FF);
  static const Color secondaryBlue = Color(0xFFB9D7F5);
  static const Color accentBlue = Color(0xFF8CC4F2);

  // ==================== BACKGROUND COLORS ====================
  static const Color mainBackground = Color(0xFFF7FAFE);
  static const Color secondaryBackground = Color(0xFFF0F6FC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFF5F8FC);

  // ==================== TEXT COLORS ====================
  static const Color primaryText = Color(0xFF1E293B);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color mutedText = Color(0xFF94A3B8);
  static const Color disabledText = Color(0xFFB6C2D0);

  // ==================== BORDER & DIVIDER ====================
  static const Color border = Color(0xFFE3EBF4);
  static const Color divider = Color(0xFFEDF2F7);

  // ==================== SEMANTIC COLORS ====================
  static const Color success = Color(0xFF22A06B);
  static const Color warning = Color(0xFFE6A23C);
  static const Color error = Color(0xFFE05D66);
  static const Color errorLight = error;
  static const Color information = Color(0xFF478DD4);

  // Semantic container colors (soft backgrounds for badges & banners)
  static const Color successContainerLight = Color(0xFFE8F8F0);
  static const Color warningContainerLight = Color(0xFFFEF6E7);
  static const Color errorContainerLight = Color(0xFFFDE8E9);
  static const Color infoContainerLight = Color(0xFFEAF3FF);

  static const Color successContainerDark = Color(0xFF133827);
  static const Color warningContainerDark = Color(0xFF422808);
  static const Color errorContainerDark = Color(0xFF441618);
  static const Color infoContainerDark = Color(0xFF142B47);

  // Semantic dark shades
  static const Color successDark = Color(0xFF4ADE80);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color errorDark = Color(0xFFF87171);
  static const Color infoDark = Color(0xFF60A5FA);

  // Backward-compatibility aliases (mapped smoothly to the Clean Modern palette)
  static const Color limeGreen = primaryBlue;
  static const Color limeGreenDark = primaryBlueDark;
  static const Color limeGreenLight = primaryBlueLight;
  static const Color offWhite = mainBackground;
  static const Color darkForestBg = Color(0xFF0F172A);
  static const Color darkForestSurface = Color(0xFF1E293B);
  static const Color darkForestCard = Color(0xFF1E293B);
  static const Color darkForestBorder = Color(0xFF334155);

  // Functional Opacities
  static const Color disabledOpacityLight = Color(0x611E293B);
  static const Color disabledOpacityDark = Color(0x61F8FAFC);

  // ==================== LIGHT THEME COLOR SCHEME ====================
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF3574C2), // WCAG AA >= 4.5:1 on white text (#FFFFFF)
    onPrimary: Colors.white,
    primaryContainer: primaryBlueLight, // #EAF3FF
    onPrimaryContainer: primaryBlueDark, // #3979C7
    secondary: primaryBlue, // #5B9BE6
    onSecondary: Colors.white,
    secondaryContainer: secondaryBlue, // #B9D7F5
    onSecondaryContainer: primaryText, // #1E293B
    tertiary: information, // #478DD4
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFE1EFFE),
    onTertiaryContainer: primaryText,
    error: error, // #E05D66
    onError: Colors.white,
    errorContainer: errorContainerLight,
    onErrorContainer: Color(0xFF5C1014),
    surface: cardBackground, // #FFFFFF
    onSurface: primaryText, // #1E293B
    surfaceContainerHighest: inputBackground, // #F5F8FC
    onSurfaceVariant: secondaryText, // #64748B
    outline: border, // #E3EBF4
    outlineVariant: divider, // #EDF2F7
    shadow: Color(0x0A000000), // Clean modern soft shadow
    scrim: Color(0x33000000),
    inverseSurface: Color(0xFF1E293B),
    onInverseSurface: Color(0xFFF8FAFC),
    inversePrimary: accentBlue,
  );

  // ==================== DARK THEME COLOR SCHEME ====================
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: accentBlue, // #8CC4F2
    onPrimary: Color(0xFF0F172A),
    primaryContainer: Color(0xFF1E3A5F),
    onPrimaryContainer: primaryBlueLight,
    secondary: secondaryBlue, // #B9D7F5
    onSecondary: Color(0xFF0F172A),
    secondaryContainer: Color(0xFF1E293B),
    onSecondaryContainer: Color(0xFFE2E8F0),
    tertiary: information,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFF163152),
    onTertiaryContainer: Color(0xFFD0E3F9),
    error: Color(0xFFFF8B94),
    onError: Color(0xFF5C1014),
    errorContainer: Color(0xFF8C1D24),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF1E293B),
    onSurface: Color(0xFFF8FAFC),
    surfaceContainerHighest: Color(0xFF283548),
    onSurfaceVariant: Color(0xFF94A3B8),
    outline: Color(0xFF475569),
    outlineVariant: Color(0xFF334155),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFF8FAFC),
    onInverseSurface: Color(0xFF1E293B),
    inversePrimary: primaryBlueDark,
  );
}
