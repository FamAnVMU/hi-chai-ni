import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_dimensions.dart';
import 'tokens/app_elevation.dart';
import 'tokens/app_radius.dart';
import 'tokens/app_spacing.dart';
import 'tokens/app_typography.dart';

/// AppTheme builds Material 3 ThemeData for Clean Modern White & Light Blue aesthetic
/// adhering strictly to the HI Chinese design language.
class AppTheme {
  AppTheme._();

  // ==================== LIGHT THEME ====================
  static ThemeData get lightTheme {
    final colorScheme = AppColors.lightColorScheme;
    final textTheme = AppTypography.createTextTheme(
      colorScheme.onSurface,
      colorScheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.mainBackground,
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: AppElevation.level0,
        scrolledUnderElevation: AppElevation.level1,
        backgroundColor: AppColors.cardBackground,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.primaryText,
          fontSize: 18,
        ),
        iconTheme: IconThemeData(
          color: AppColors.primaryText,
          size: AppDimensions.iconMd,
        ),
        shape: const Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1.0,
          ),
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: AppElevation.level0,
        color: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderLg,
          side: const BorderSide(
            color: AppColors.border,
            width: AppDimensions.cardBorderWidth,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppElevation.level0,
          backgroundColor: AppColors.primaryBlueDark,
          foregroundColor: Colors.white,
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.buttonHeightMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlueDark,
          backgroundColor: AppColors.cardBackground,
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.buttonHeightMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: const BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlueDark,
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.buttonHeightMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.mutedText,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.secondaryText,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(
            color: AppColors.border,
            width: AppDimensions.inputBorderWidth,
          ),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(
            color: AppColors.border,
            width: AppDimensions.inputBorderWidth,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(
            color: AppColors.primaryBlueDark,
            width: AppDimensions.inputFocusedBorderWidth,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(
            color: AppColors.error,
            width: AppDimensions.inputBorderWidth,
          ),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(
            color: AppColors.error,
            width: AppDimensions.inputFocusedBorderWidth,
          ),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        elevation: AppElevation.level4,
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderXl,
          side: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primaryText,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.secondaryText,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: AppElevation.level4,
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.bottomSheetBorder,
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardBackground,
        selectedColor: AppColors.primaryBlueLight,
        disabledColor: AppColors.secondaryBackground,
        side: const BorderSide(color: AppColors.border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        labelStyle: textTheme.labelMedium!.copyWith(
          color: AppColors.primaryText,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryText,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ==================== DARK THEME ====================
  static ThemeData get darkTheme {
    final colorScheme = AppColors.darkColorScheme;
    final textTheme = AppTypography.createTextTheme(
      colorScheme.onSurface,
      colorScheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkForestBg,
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: AppElevation.level0,
        scrolledUnderElevation: AppElevation.level1,
        backgroundColor: AppColors.darkForestSurface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontSize: 18,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.primary,
          size: AppDimensions.iconMd,
        ),
        shape: const Border(
          bottom: BorderSide(
            color: AppColors.darkForestBorder,
            width: 1.0,
          ),
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: AppElevation.level0,
        color: AppColors.darkForestSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderLg,
          side: BorderSide(
            color: AppColors.darkForestBorder,
            width: AppDimensions.cardBorderWidth,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppElevation.level0,
          backgroundColor: AppColors.accentBlue,
          foregroundColor: AppColors.darkForestBg,
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.buttonHeightMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.buttonHeightMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.buttonHeightMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withAlpha(160),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
            width: AppDimensions.inputBorderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
            width: AppDimensions.inputBorderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: AppDimensions.inputFocusedBorderWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(
            color: colorScheme.error,
            width: AppDimensions.inputBorderWidth,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(
            color: colorScheme.error,
            width: AppDimensions.inputFocusedBorderWidth,
          ),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        elevation: AppElevation.level5,
        backgroundColor: AppColors.darkForestSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderXl,
          side: BorderSide(
            color: AppColors.darkForestBorder,
            width: 1,
          ),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: AppElevation.level4,
        backgroundColor: AppColors.darkForestSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.darkForestSurface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.bottomSheetBorder,
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkForestSurface,
        selectedColor: AppColors.primaryBlueDark.withAlpha(120),
        disabledColor: colorScheme.surfaceContainerHighest.withAlpha(128),
        side: const BorderSide(color: AppColors.darkForestBorder),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        labelStyle: textTheme.labelMedium!,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.darkForestBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

// ==================== THEME MODE PROVIDER ====================
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Clean Modern White & Light Blue is the signature default theme
    return ThemeMode.light;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
