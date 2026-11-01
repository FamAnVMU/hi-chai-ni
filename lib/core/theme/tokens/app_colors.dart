import 'package:flutter/material.dart';

/// Semantic color roles for HI Chinese.
///
/// Palette rules:
/// - Lime Green: `#A3D635` used as vibrant primary accent in Dark theme.
/// - Off-white: `#F6FAF2` used as background in Light theme.
/// - Dark Forest: `#121811` (scaffold background) and `#1A2418` (cards/surfaces) in Dark theme.
/// - Never use raw lime as a background for everything; all roles are strictly semantic.
class AppColors {
  AppColors._();

  // ==================== BASE BRAND PALETTE ====================
  static const Color limeGreen = Color(0xFFA3D635);
  static const Color limeGreenLight = Color(0xFFDCF59C);
  static const Color limeGreenDark = Color(0xFF5C8009);

  static const Color offWhite = Color(0xFFF6FAF2);
  static const Color darkForestBg = Color(0xFF121811);
  static const Color darkForestSurface = Color(0xFF1A2418);
  static const Color darkForestCard = Color(0xFF243022);
  static const Color darkForestBorder = Color(0xFF2E3D2B);

  // ==================== LIGHT THEME COLOR SCHEME ====================
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF53740A), // WCAG AA compliant on light backgrounds
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD6F392),
    onPrimaryContainer: Color(0xFF162400),
    secondary: Color(0xFF4A6438),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFCCE8B6),
    onSecondaryContainer: Color(0xFF0F1F04),
    tertiary: Color(0xFF386568),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFBCEBEF),
    onTertiaryContainer: Color(0xFF002022),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Colors.white,
    onSurface: Color(0xFF191D17),
    surfaceContainerHighest: Color(0xFFE0E5DA),
    onSurfaceVariant: Color(0xFF44483E),
    outline: Color(0xFF74796D),
    outlineVariant: Color(0xFFC4C8BA),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF2E312B),
    onInverseSurface: Color(0xFFF0F2E9),
    inversePrimary: Color(0xFFA3D635),
  );

  // ==================== DARK THEME COLOR SCHEME ====================
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: limeGreen, // #A3D635
    onPrimary: darkForestBg, // #121811 for sharp contrast
    primaryContainer: Color(0xFF3B5405),
    onPrimaryContainer: Color(0xFFD6F392),
    secondary: Color(0xFFB1CC9C),
    onSecondary: Color(0xFF1D350E),
    secondaryContainer: Color(0xFF334C22),
    onSecondaryContainer: Color(0xFFCCE8B6),
    tertiary: Color(0xFFA0CFD2),
    onTertiary: Color(0xFF003639),
    tertiaryContainer: Color(0xFF1F4D50),
    onTertiaryContainer: Color(0xFFBCEBEF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: darkForestSurface, // #1A2418
    onSurface: Color(0xFFE2E4DC),
    surfaceContainerHighest: darkForestCard, // #243022
    onSurfaceVariant: Color(0xFFC4C8BA),
    outline: Color(0xFF8E9286),
    outlineVariant: darkForestBorder, // #2E3D2B
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFE2E4DC),
    onInverseSurface: Color(0xFF191D17),
    inversePrimary: Color(0xFF53740A),
  );

  // ==================== SEMANTIC FUNCTIONAL COLORS ====================
  // Success
  static const Color success = Color(0xFF2E7D32);
  static const Color successDark = Color(0xFF81C784);
  static const Color successContainerLight = Color(0xFFD7F5D9);
  static const Color successContainerDark = Color(0xFF1B381A);

  // Warning
  static const Color warning = Color(0xFFB26A00);
  static const Color warningDark = Color(0xFFFFB74D);
  static const Color warningContainerLight = Color(0xFFFFE1B8);
  static const Color warningContainerDark = Color(0xFF3B2E15);

  // Error
  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color errorDark = Color(0xFFFFB4AB);
  static const Color errorContainerDark = Color(0xFF3B1A1A);

  // Disabled
  static const Color disabledOpacityLight = Color(0x61000000);
  static const Color disabledOpacityDark = Color(0x61FFFFFF);
}
