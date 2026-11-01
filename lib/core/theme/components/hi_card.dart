import 'package:flutter/material.dart';
import '../tokens/app_dimensions.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// Semantic Card component for HI Chinese.
///
/// Automatically adopts surface styling:
/// - Light: white with subtle light outline
/// - Dark: #1A2418 (darkForestSurface) with #2E3D2B border
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
    final cardTheme = theme.cardTheme;
    final r = borderRadius ?? AppRadius.borderLg;

    final shape = RoundedRectangleBorder(
      borderRadius: r,
      side: BorderSide(
        color: borderColor ?? theme.colorScheme.outlineVariant,
        width: AppDimensions.cardBorderWidth,
      ),
    );

    return Card(
      elevation: cardTheme.elevation ?? 0,
      color: backgroundColor ?? cardTheme.color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: r,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
