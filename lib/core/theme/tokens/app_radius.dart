import 'package:flutter/material.dart';

/// Corner radius tokens for HI Chinese components.
class AppRadius {
  AppRadius._();

  /// 0.0 dp - sharp corners
  static const double none = 0.0;

  /// 4.0 dp - extra small for badges, small tags
  static const double xs = 4.0;

  /// 8.0 dp - small for chips, small buttons
  static const double sm = 8.0;

  /// 12.0 dp - medium standard for input fields, buttons, small cards
  static const double md = 12.0;

  /// 16.0 dp - large standard for cards, modals
  static const double lg = 16.0;

  /// 24.0 dp - extra large for bottom sheets, large dialogs
  static const double xl = 24.0;

  /// 999.0 dp - fully rounded / pill shapes
  static const double full = 999.0;

  // ==================== RADIUS CONSTANTS ====================
  static const Radius rXs = Radius.circular(xs);
  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
  static const Radius rXl = Radius.circular(xl);
  static const Radius rFull = Radius.circular(full);

  // ==================== BORDERRADIUS CONSTANTS ====================
  static const BorderRadius borderNone = BorderRadius.zero;
  static const BorderRadius borderXs = BorderRadius.all(rXs);
  static const BorderRadius borderSm = BorderRadius.all(rSm);
  static const BorderRadius borderMd = BorderRadius.all(rMd);
  static const BorderRadius borderLg = BorderRadius.all(rLg);
  static const BorderRadius borderXl = BorderRadius.all(rXl);
  static const BorderRadius borderFull = BorderRadius.all(rFull);

  // Bottom Sheet top rounded
  static const BorderRadius bottomSheetBorder = BorderRadius.vertical(
    top: rXl,
  );
}
