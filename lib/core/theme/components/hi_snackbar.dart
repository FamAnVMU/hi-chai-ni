import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_dimensions.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

enum HiSnackBarType {
  success,
  error,
  warning,
  info,
}

/// Standardized SnackBar utility for semantic feedback across HI Chinese.
class HiSnackBar {
  HiSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    HiSnackBarType type = HiSnackBarType.info,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    Color fgColor;
    IconData icon;

    switch (type) {
      case HiSnackBarType.success:
        bgColor = isDark ? AppColors.successContainerDark : AppColors.successContainerLight;
        fgColor = isDark ? AppColors.successDark : AppColors.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case HiSnackBarType.error:
        bgColor = isDark ? AppColors.errorContainerDark : theme.colorScheme.errorContainer;
        fgColor = isDark ? AppColors.errorDark : theme.colorScheme.error;
        icon = Icons.error_outline_rounded;
        break;
      case HiSnackBarType.warning:
        bgColor = isDark ? AppColors.warningContainerDark : AppColors.warningContainerLight;
        fgColor = isDark ? AppColors.warningDark : AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case HiSnackBarType.info:
        bgColor = isDark ? AppColors.darkForestCard : theme.colorScheme.inverseSurface;
        fgColor = isDark ? theme.colorScheme.onSurface : theme.colorScheme.onInverseSurface;
        icon = Icons.info_outline_rounded;
        break;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgColor,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderMd,
          side: BorderSide(color: fgColor.withAlpha(70)),
        ),
        margin: const EdgeInsets.all(AppSpacing.lg),
        content: Row(
          children: [
            Icon(
              icon,
              color: fgColor,
              size: AppDimensions.iconMd,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: action,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, type: HiSnackBarType.success);
  }

  static void showError(BuildContext context, String message) {
    show(context, message: message, type: HiSnackBarType.error);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message: message, type: HiSnackBarType.warning);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message: message, type: HiSnackBarType.info);
  }
}
