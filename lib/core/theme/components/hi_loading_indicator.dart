import 'package:flutter/material.dart';
import '../tokens/app_dimensions.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// Themed loading indicators for HI Chinese.
class HiLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final String? message;

  const HiLoadingIndicator({
    super.key,
    this.size = AppDimensions.iconLg,
    this.strokeWidth = 3.0,
    this.color,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.colorScheme.primary;

    final spinner = SizedBox(
      height: size,
      width: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
      ),
    );

    if (message == null) {
      return spinner;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        spinner,
        const SizedBox(height: AppSpacing.md),
        Text(
          message!,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Linear progress bar indicator with rounded corners.
class HiLinearProgress extends StatelessWidget {
  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double height;

  const HiLinearProgress({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.height = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: AppRadius.borderFull,
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? theme.colorScheme.primary,
          ),
          backgroundColor: backgroundColor ??
              theme.colorScheme.surfaceContainerHighest.withAlpha(128),
        ),
      ),
    );
  }
}
