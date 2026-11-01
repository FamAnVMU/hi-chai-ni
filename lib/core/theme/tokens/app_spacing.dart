import 'package:flutter/material.dart';

/// Spacing tokens for HI Chinese layout and components.
/// Standard 4pt / 8pt grid system.
class AppSpacing {
  AppSpacing._();

  /// 0.0 dp
  static const double none = 0.0;

  /// 2.0 dp - micro spacing for borders, tags
  static const double xxs = 2.0;

  /// 4.0 dp - tight spacing between related elements
  static const double xs = 4.0;

  /// 8.0 dp - standard small spacing
  static const double sm = 8.0;

  /// 12.0 dp - medium-small spacing
  static const double md = 12.0;

  /// 16.0 dp - standard medium spacing, default screen padding
  static const double lg = 16.0;

  /// 20.0 dp - large spacing between content groups
  static const double xl = 20.0;

  /// 24.0 dp - extra large spacing
  static const double xxl = 24.0;

  /// 32.0 dp - section spacing
  static const double xxxl = 32.0;

  /// 48.0 dp - huge spacing, screen divisions
  static const double huge = 48.0;

  // ==================== EDGE INSETS PRESETS ====================
  static const EdgeInsets edgeInsetsNone = EdgeInsets.zero;
  static const EdgeInsets edgeInsetsXxs = EdgeInsets.all(xxs);
  static const EdgeInsets edgeInsetsXs = EdgeInsets.all(xs);
  static const EdgeInsets edgeInsetsSm = EdgeInsets.all(sm);
  static const EdgeInsets edgeInsetsMd = EdgeInsets.all(md);
  static const EdgeInsets edgeInsetsLg = EdgeInsets.all(lg);
  static const EdgeInsets edgeInsetsXl = EdgeInsets.all(xl);
  static const EdgeInsets edgeInsetsXxl = EdgeInsets.all(xxl);

  // Screen padding standard
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets dialogPadding = EdgeInsets.all(xxl);
  static const EdgeInsets bottomSheetPadding = EdgeInsets.all(xl);

  // ==================== SIZEDBOX SPACER HELPERS ====================
  // Vertical spacers
  static const SizedBox verticalXxs = SizedBox(height: xxs);
  static const SizedBox verticalXs = SizedBox(height: xs);
  static const SizedBox verticalSm = SizedBox(height: sm);
  static const SizedBox verticalMd = SizedBox(height: md);
  static const SizedBox verticalLg = SizedBox(height: lg);
  static const SizedBox verticalXl = SizedBox(height: xl);
  static const SizedBox verticalXxl = SizedBox(height: xxl);
  static const SizedBox verticalXxxl = SizedBox(height: xxxl);
  static const SizedBox verticalHuge = SizedBox(height: huge);

  // Horizontal spacers
  static const SizedBox horizontalXxs = SizedBox(width: xxs);
  static const SizedBox horizontalXs = SizedBox(width: xs);
  static const SizedBox horizontalSm = SizedBox(width: sm);
  static const SizedBox horizontalMd = SizedBox(width: md);
  static const SizedBox horizontalLg = SizedBox(width: lg);
  static const SizedBox horizontalXl = SizedBox(width: xl);
  static const SizedBox horizontalXxl = SizedBox(width: xxl);
  static const SizedBox horizontalXxxl = SizedBox(width: xxxl);
}
