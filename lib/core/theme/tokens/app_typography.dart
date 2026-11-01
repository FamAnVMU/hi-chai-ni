import 'package:flutter/material.dart';

/// Typography system for HI Chinese.
///
/// Designed to support:
/// 1. Vietnamese tone marks & diacritics (ơ, ư, ê, ô, ệ, ẩ, ỹ, ớ, ...)
/// 2. Chinese glyphs (Simplified & Traditional) via offline native fallbacks:
///    ['Noto Sans SC', 'PingFang SC', 'Heiti SC', 'Roboto', 'sans-serif']
/// 3. Specialized typography for Chinese learning (Hanzi display, Pinyin with tone marks).
class AppTypography {
  AppTypography._();

  /// Primary system font fallbacks ensuring crisp rendering of Vietnamese and Chinese
  static const List<String> fontFallbacks = [
    'Noto Sans SC',
    'PingFang SC',
    'Heiti SC',
    'Roboto',
    'sans-serif',
  ];

  // ==================== MATERIAL 3 TEXT THEME BUILDER ====================
  static TextTheme createTextTheme(Color textColor, Color secondaryColor) {
    return TextTheme(
      // Display
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),

      // Headline
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),

      // Title
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),

      // Body
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.5,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.45,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.4,
        color: secondaryColor,
        fontFamilyFallback: fontFallbacks,
      ),

      // Label
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor,
        fontFamilyFallback: fontFallbacks,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: secondaryColor,
        fontFamilyFallback: fontFallbacks,
      ),
    );
  }

  // ==================== SPECIALIZED CHINESE LEARNING STYLES ====================
  /// Large Hanzi for flashcards, stroke order demos, and character focus (40sp)
  static TextStyle hanziLarge({Color? color}) => TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
        fontFamilyFallback: fontFallbacks,
      );

  /// Medium Hanzi for vocabulary lists, sentence words (24sp)
  static TextStyle hanziMedium({Color? color}) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: color,
        fontFamilyFallback: fontFallbacks,
      );

  /// Small Hanzi for inline sentences and dialogues (18sp)
  static TextStyle hanziSmall({Color? color}) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: color,
        fontFamilyFallback: fontFallbacks,
      );

  /// Pinyin display text with tone mark support (14sp)
  static TextStyle pinyin({Color? color}) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.4,
        color: color,
        fontFamilyFallback: fontFallbacks,
      );

  /// Pinyin display text for large character cards (18sp)
  static TextStyle pinyinLarge({Color? color}) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.75,
        height: 1.3,
        color: color,
        fontFamilyFallback: fontFallbacks,
      );

  /// Vietnamese explanation style supporting full diacritics
  static TextStyle vietnameseMeaning({Color? color}) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: color,
        fontFamilyFallback: fontFallbacks,
      );
}
