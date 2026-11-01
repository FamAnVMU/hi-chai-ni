import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_dimensions.dart';
import 'tokens/app_elevation.dart';
import 'tokens/app_radius.dart';
import 'tokens/app_spacing.dart';
import 'tokens/app_typography.dart';

/// AppTheme builds Material 3 ThemeData for Light and Dark modes
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
      scaffoldBackgroundColor: AppColors.offWhite,
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: AppElevation.level0,
        scrolledUnderElevation: AppElevation.level1,
        backgroundColor: Colors.white,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
          size: AppDimensions.iconMd,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: AppElevation.level0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderLg,
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: AppDimensions.cardBorderWidth,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppElevation.level0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.buttonHeightMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: textTheme.labelLarge,
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
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
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
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderXl,
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: textTheme.bodyMedium,
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        elevation: AppElevation.level4,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.bottomSheetBorder,
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.surfaceContainerHighest.withAlpha(128),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        labelStyle: textTheme.labelMedium!,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withAlpha(128),
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
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.primary, // Lime green icon accent
          size: AppDimensions.iconMd,
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
          backgroundColor: colorScheme.primary, // Lime Green
          foregroundColor: colorScheme.onPrimary, // #121811 dark forest text
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.buttonHeightMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
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
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
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
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkForestSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withAlpha(140),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(
            color: AppColors.darkForestBorder,
            width: AppDimensions.inputBorderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(
            color: AppColors.darkForestBorder,
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
          color: colorScheme.onSurface,
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
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.surfaceContainerHighest.withAlpha(128),
        side: const BorderSide(color: AppColors.darkForestBorder),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        labelStyle: textTheme.labelMedium!,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkForestCard,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
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
    return ThemeMode.dark; // HI Chinese default signature dark theme
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
