import 'package:flutter/material.dart';

/// Elevation tokens and box shadows for HI Chinese.
class AppElevation {
  AppElevation._();

  /// 0.0 dp - flat components, buttons in ghost mode
  static const double level0 = 0.0;

  /// 1.0 dp - resting cards, chips
  static const double level1 = 1.0;

  /// 3.0 dp - raised buttons, hover/pressed state
  static const double level2 = 3.0;

  /// 6.0 dp - dropdowns, floating action buttons
  static const double level3 = 6.0;

  /// 8.0 dp - bottom navigation, banners
  static const double level4 = 8.0;

  /// 12.0 dp - dialogs, modal sheets
  static const double level5 = 12.0;

  // ==================== SHADOW DEFINITIONS ====================
  static List<BoxShadow> shadowLow(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x33000000),
          offset: Offset(0, 1),
          blurRadius: 3,
          spreadRadius: 0,
        ),
      ];
    }
    return const [
      BoxShadow(
        color: Color(0x14000000),
        offset: Offset(0, 1),
        blurRadius: 3,
        spreadRadius: 0,
      ),
    ];
  }

  static List<BoxShadow> shadowMid(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x4D000000),
          offset: Offset(0, 3),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ];
    }
    return const [
      BoxShadow(
        color: Color(0x1F000000),
        offset: Offset(0, 3),
        blurRadius: 6,
        spreadRadius: 0,
      ),
    ];
  }

  static List<BoxShadow> shadowHigh(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x66000000),
          offset: Offset(0, 8),
          blurRadius: 16,
          spreadRadius: -2,
        ),
      ];
    }
    return const [
      BoxShadow(
        color: Color(0x2E000000),
        offset: Offset(0, 8),
        blurRadius: 16,
        spreadRadius: -2,
      ),
    ];
  }
}
