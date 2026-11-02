import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_dimensions.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// Clean Modern Card component for HI Chinese: White background with crisp border.
///
/// Features:
/// - Light: Clean pure white (#FFFFFF) with subtle outline (#E3EBF4).
/// - Dark: Deep navy slate (#1E293B) with subtle border (#334155).
/// - Elevation level 0 to keep UI minimal and un-cluttered.
class HiCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;

  const HiCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.cardPadding,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = borderRadius ?? AppRadius.borderLg;

    final defaultBorderColor = isDark ? AppColors.darkForestBorder : AppColors.border;
    final defaultBgColor = isDark ? AppColors.darkForestSurface : AppColors.cardBackground;

    final shape = RoundedRectangleBorder(
      borderRadius: r,
      side: BorderSide(
        color: borderColor ?? defaultBorderColor,
        width: AppDimensions.cardBorderWidth,
      ),
    );

    final cardWidget = Material(
      color: backgroundColor ?? defaultBgColor,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: r,
              splashColor: (isDark ? AppColors.accentBlue : AppColors.primaryBlue).withAlpha(15),
              highlightColor: (isDark ? AppColors.accentBlue : AppColors.primaryBlue).withAlpha(8),
              child: Padding(
                padding: padding,
                child: child,
              ),
            )
          : Padding(
              padding: padding,
              child: child,
            ),
    );

    return cardWidget;
  }
}
