import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_dimensions.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

enum HiButtonVariant {
  primary,
  secondary,
  ghost,
  danger,
}

enum HiButtonSize {
  sm,
  md,
  lg,
}

/// Standardized, accessible Button component for HI Chinese.
///
/// Features:
/// - Guarantees minimum 48x48 dp touch target per WCAG 2.2 AA.
/// - Built-in loading indicator state.
/// - Supports primary (lime in dark / forest in light), secondary, ghost, danger.
class HiButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final HiButtonVariant variant;
  final HiButtonSize size;
  final Widget? icon;
  final Widget? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;

  const HiButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = HiButtonVariant.primary,
    this.size = HiButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = onPressed != null && !isLoading;

    // Height & Text styling by size
    final double buttonHeight;
    final TextStyle textStyle;
    final double iconSize;

    switch (size) {
      case HiButtonSize.sm:
        buttonHeight = AppDimensions.buttonHeightSm;
        textStyle = theme.textTheme.labelMedium!.copyWith(
          fontWeight: FontWeight.w600,
        );
        iconSize = AppDimensions.iconXs;
        break;
      case HiButtonSize.md:
        buttonHeight = AppDimensions.buttonHeightMd;
        textStyle = theme.textTheme.labelLarge!.copyWith(
          fontWeight: FontWeight.w600,
        );
        iconSize = AppDimensions.iconSm;
        break;
      case HiButtonSize.lg:
        buttonHeight = AppDimensions.buttonHeightLg;
        textStyle = theme.textTheme.titleSmall!.copyWith(
          fontWeight: FontWeight.w700,
        );
        iconSize = AppDimensions.iconMd;
        break;
    }

    // Color resolution by variant
    Color backgroundColor;
    Color foregroundColor;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case HiButtonVariant.primary:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
      case HiButtonVariant.secondary:
        backgroundColor = isDark
            ? AppColors.darkForestSurface
            : colorScheme.surfaceContainerHighest;
        foregroundColor = colorScheme.onSurface;
        borderSide = BorderSide(
          color: isDark ? AppColors.darkForestBorder : colorScheme.outlineVariant,
          width: 1,
        );
        break;
      case HiButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = colorScheme.primary;
        break;
      case HiButtonVariant.danger:
        backgroundColor = isDark ? const Color(0xFF93000A) : colorScheme.error;
        foregroundColor = Colors.white;
        break;
    }

    if (!isEnabled) {
      backgroundColor = isDark
          ? AppColors.darkForestCard.withAlpha(128)
          : colorScheme.surfaceContainerHighest.withAlpha(150);
      foregroundColor = isDark
          ? Colors.white38
          : colorScheme.onSurface.withAlpha(90);
      borderSide = BorderSide.none;
    }

    Widget content;
    if (isLoading) {
      content = SizedBox(
        height: iconSize,
        width: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(
                color: foregroundColor,
                size: iconSize,
              ),
              child: icon!,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              text,
              style: textStyle.copyWith(color: foregroundColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconTheme(
              data: IconThemeData(
                color: foregroundColor,
                size: iconSize,
              ),
              child: trailingIcon!,
            ),
          ],
        ],
      );
    }

    // Enforce minimum 48x48dp touch target standard
    Widget buttonWidget = Material(
      color: backgroundColor,
      borderRadius: AppRadius.borderMd,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: AppRadius.borderMd,
        child: Container(
          height: buttonHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderMd,
            border: borderSide != BorderSide.none
                ? Border.fromBorderSide(borderSide)
                : null,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    // If button height is less than 48dp, ensure hit area is wrapped in minimum touch target
    if (buttonHeight < AppDimensions.minTouchTarget) {
      buttonWidget = ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppDimensions.minTouchTarget,
          minWidth: AppDimensions.minTouchTarget,
        ),
        child: Center(
          child: buttonWidget,
        ),
      );
    }

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}
