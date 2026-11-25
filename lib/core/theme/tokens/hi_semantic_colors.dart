import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Semantic Light/Dark theme colors registered as a [ThemeExtension].
/// Ensures WCAG AA (>= 4.5:1) contrast in both Light Mode and Dark Mode.
@immutable
class HiSemanticColors extends ThemeExtension<HiSemanticColors> {
  final Color cardSurface;
  final Color mainBackground;
  final Color secondarySurface;
  final Color inputSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color borderColor;
  final Color accentColor;
  final Color accentBg;
  final Color successBg;
  final Color successFg;
  final Color warningBg;
  final Color warningFg;
  final Color errorBg;
  final Color errorFg;
  final Color infoBg;
  final Color infoFg;

  const HiSemanticColors({
    required this.cardSurface,
    required this.mainBackground,
    required this.secondarySurface,
    required this.inputSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.borderColor,
    required this.accentColor,
    required this.accentBg,
    required this.successBg,
    required this.successFg,
    required this.warningBg,
    required this.warningFg,
    required this.errorBg,
    required this.errorFg,
    required this.infoBg,
    required this.infoFg,
  });

  static const HiSemanticColors light = HiSemanticColors(
    cardSurface: AppColors.cardBackground,
    mainBackground: AppColors.mainBackground,
    secondarySurface: AppColors.secondaryBackground,
    inputSurface: AppColors.inputBackground,
    primaryText: AppColors.primaryText,
    secondaryText: AppColors.secondaryText,
    borderColor: AppColors.border,
    accentColor: Color(0xFF2661A8),
    accentBg: AppColors.primaryBlueLight,
    successBg: AppColors.successContainerLight,
    successFg: Color(0xFF13724A),
    warningBg: AppColors.warningContainerLight,
    warningFg: Color(0xFF9A6700),
    errorBg: AppColors.errorContainerLight,
    errorFg: Color(0xFFB3261E),
    infoBg: AppColors.infoContainerLight,
    infoFg: Color(0xFF2563A8),
  );

  static const HiSemanticColors dark = HiSemanticColors(
    cardSurface: AppColors.darkForestCard,
    mainBackground: AppColors.darkForestBg,
    secondarySurface: AppColors.darkInputSurface,
    inputSurface: AppColors.darkInputSurface,
    primaryText: AppColors.darkTextPrimary,
    secondaryText: AppColors.darkTextSecondary,
    borderColor: AppColors.darkForestBorder,
    accentColor: AppColors.accentBlue,
    accentBg: Color(0xFF1E3A5F),
    successBg: AppColors.successContainerDark,
    successFg: AppColors.successDark,
    warningBg: AppColors.warningContainerDark,
    warningFg: AppColors.warningDark,
    errorBg: AppColors.errorContainerDark,
    errorFg: AppColors.errorDark,
    infoBg: AppColors.infoContainerDark,
    infoFg: AppColors.infoDark,
  );

  @override
  HiSemanticColors copyWith({
    Color? cardSurface,
    Color? mainBackground,
    Color? secondarySurface,
    Color? inputSurface,
    Color? primaryText,
    Color? secondaryText,
    Color? borderColor,
    Color? accentColor,
    Color? accentBg,
    Color? successBg,
    Color? successFg,
    Color? warningBg,
    Color? warningFg,
    Color? errorBg,
    Color? errorFg,
    Color? infoBg,
    Color? infoFg,
  }) {
    return HiSemanticColors(
      cardSurface: cardSurface ?? this.cardSurface,
      mainBackground: mainBackground ?? this.mainBackground,
      secondarySurface: secondarySurface ?? this.secondarySurface,
      inputSurface: inputSurface ?? this.inputSurface,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      borderColor: borderColor ?? this.borderColor,
      accentColor: accentColor ?? this.accentColor,
      accentBg: accentBg ?? this.accentBg,
      successBg: successBg ?? this.successBg,
      successFg: successFg ?? this.successFg,
      warningBg: warningBg ?? this.warningBg,
      warningFg: warningFg ?? this.warningFg,
      errorBg: errorBg ?? this.errorBg,
      errorFg: errorFg ?? this.errorFg,
      infoBg: infoBg ?? this.infoBg,
      infoFg: infoFg ?? this.infoFg,
    );
  }

  @override
  HiSemanticColors lerp(covariant ThemeExtension<HiSemanticColors>? other, double t) {
    if (other is! HiSemanticColors) return this;
    return HiSemanticColors(
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      mainBackground: Color.lerp(mainBackground, other.mainBackground, t)!,
      secondarySurface: Color.lerp(secondarySurface, other.secondarySurface, t)!,
      inputSurface: Color.lerp(inputSurface, other.inputSurface, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      accentBg: Color.lerp(accentBg, other.accentBg, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      successFg: Color.lerp(successFg, other.successFg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      errorFg: Color.lerp(errorFg, other.errorFg, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      infoFg: Color.lerp(infoFg, other.infoFg, t)!,
    );
  }
}

/// Convenient semantic color getters on [BuildContext] for Light/Dark adaptation.
extension HiThemeContextX on BuildContext {
  HiSemanticColors get hiColors {
    final theme = Theme.of(this);
    return theme.extension<HiSemanticColors>() ??
        (theme.brightness == Brightness.dark
            ? HiSemanticColors.dark
            : HiSemanticColors.light);
  }

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get hiCardSurface => hiColors.cardSurface;
  Color get hiMainBackground => hiColors.mainBackground;
  Color get hiSecondarySurface => hiColors.secondarySurface;
  Color get hiInputSurface => hiColors.inputSurface;
  Color get hiPrimaryText => hiColors.primaryText;
  Color get hiSecondaryText => hiColors.secondaryText;
  Color get hiBorderColor => hiColors.borderColor;
  Color get hiAccentColor => hiColors.accentColor;
  Color get hiAccentBg => hiColors.accentBg;
  Color get hiSuccessBg => hiColors.successBg;
  Color get hiSuccessFg => hiColors.successFg;
  Color get hiWarningBg => hiColors.warningBg;
  Color get hiWarningFg => hiColors.warningFg;
  Color get hiErrorBg => hiColors.errorBg;
  Color get hiErrorFg => hiColors.errorFg;
  Color get hiInfoBg => hiColors.infoBg;
  Color get hiInfoFg => hiColors.infoFg;
}
