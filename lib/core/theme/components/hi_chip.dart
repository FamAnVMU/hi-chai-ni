import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_dimensions.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

enum HiChipStatus {
  neutral,
  success,
  warning,
  error,
  info,
}

/// Standardized chip component for tags, filters, and status badges.
class HiChip extends StatelessWidget {
  final String label;
  final Widget? icon;
  final Widget? deleteIcon;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final bool isSelected;
  final HiChipStatus status;

  const HiChip({
    super.key,
    required this.label,
    this.icon,
    this.deleteIcon,
    this.onDeleted,
    this.onTap,
    this.isSelected = false,
    this.status = HiChipStatus.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bgColor;
    final Color textColor;
    final BorderSide borderSide;

    switch (status) {
      case HiChipStatus.success:
        bgColor = isDark
            ? AppColors.successContainerDark
            : AppColors.successContainerLight;
        textColor = isDark ? AppColors.successDark : AppColors.success;
        borderSide = BorderSide(color: textColor.withAlpha(80));
        break;
      case HiChipStatus.warning:
        bgColor = isDark
            ? AppColors.warningContainerDark
            : AppColors.warningContainerLight;
        textColor = isDark ? AppColors.warningDark : AppColors.warning;
        borderSide = BorderSide(color: textColor.withAlpha(80));
        break;
      case HiChipStatus.error:
        bgColor = isDark
            ? AppColors.errorContainerDark
            : theme.colorScheme.errorContainer;
        textColor = isDark ? AppColors.errorDark : theme.colorScheme.error;
        borderSide = BorderSide(color: textColor.withAlpha(80));
        break;
      case HiChipStatus.info:
        bgColor = isDark
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.tertiaryContainer;
        textColor = isDark
            ? theme.colorScheme.onTertiaryContainer
            : theme.colorScheme.tertiary;
        borderSide = BorderSide(color: textColor.withAlpha(80));
        break;
      case HiChipStatus.neutral:
        if (isSelected) {
          bgColor = theme.colorScheme.primaryContainer;
          textColor = theme.colorScheme.onPrimaryContainer;
          borderSide = BorderSide(color: theme.colorScheme.primary);
        } else {
          bgColor = isDark ? AppColors.darkForestSurface : Colors.white;
          textColor = theme.colorScheme.onSurface;
          borderSide = BorderSide(
            color: isDark ? AppColors.darkForestBorder : theme.colorScheme.outlineVariant,
          );
        }
        break;
    }

    final chipWidget = Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderSm,
        side: borderSide,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: textColor,
                    size: AppDimensions.iconXs,
                  ),
                  child: icon!,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              if (onDeleted != null) ...[
                const SizedBox(width: AppSpacing.xs),
                GestureDetector(
                  onTap: onDeleted,
                  child: deleteIcon ??
                      Icon(
                        Icons.close,
                        size: AppDimensions.iconXs,
                        color: textColor,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // If clickable, wrap in minimum touch target boundary
    if (onTap != null || onDeleted != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppDimensions.minTouchTarget,
        ),
        child: Center(
          widthFactor: 1.0,
          child: chipWidget,
        ),
      );
    }

    return chipWidget;
  }
}
