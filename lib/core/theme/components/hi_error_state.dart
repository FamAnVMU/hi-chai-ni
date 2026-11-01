import 'package:flutter/material.dart';
import '../tokens/app_dimensions.dart';
import '../tokens/app_spacing.dart';
import 'hi_button.dart';

/// Reusable error state view with retry capability.
class HiErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final String retryText;
  final VoidCallback? onRetry;
  final IconData icon;

  const HiErrorState({
    super.key,
    this.title = 'Đã có lỗi xảy ra',
    this.message,
    this.retryText = 'Thử lại',
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconHuge,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              HiButton(
                text: retryText,
                variant: HiButtonVariant.primary,
                size: HiButtonSize.md,
                icon: const Icon(Icons.refresh_rounded),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
