import 'package:flutter/material.dart';
import '../../../../core/theme/components/hi_button.dart';
import '../../../../core/theme/components/hi_card.dart';
import '../../../../core/theme/tokens/app_colors.dart';
import '../../../../core/theme/tokens/app_spacing.dart';

/// A robust error boundary widget for lesson study steps.
///
/// Prevents unhandled exceptions from turning into Flutter's release-mode
/// blank white screen (SizedBox.shrink()).
///
/// If an error occurs during step rendering:
/// - Displays a clean modern card informing the user.
/// - Offers "Thử lại" to reset error state and retry building.
/// - Offers "Bỏ qua bước này" to skip to the next step, ensuring the learner
///   is never trapped or blocked.
class LessonStepErrorBoundary extends StatefulWidget {
  final Widget? child;
  final WidgetBuilder? builder;
  final String stepName;
  final VoidCallback? onSkip;
  final VoidCallback? onRetry;

  const LessonStepErrorBoundary({
    super.key,
    this.child,
    this.builder,
    required this.stepName,
    this.onSkip,
    this.onRetry,
  }) : assert(
          child != null || builder != null,
          'Either child or builder must be provided to LessonStepErrorBoundary',
        );

  @override
  State<LessonStepErrorBoundary> createState() => _LessonStepErrorBoundaryState();

  /// Static helper to build the fallback error UI directly.
  static Widget buildErrorFallback({
    required String stepName,
    VoidCallback? onSkip,
    VoidCallback? onRetry,
    Object? error,
  }) {
    return _LessonStepErrorFallback(
      stepName: stepName,
      onSkip: onSkip,
      onRetry: onRetry,
      error: error,
    );
  }

  /// Global ErrorWidget.builder callback generator to guarantee no blank white screens.
  static Widget Function(FlutterErrorDetails) createErrorWidgetBuilder({
    String stepName = 'học liệu',
    VoidCallback? onSkip,
    VoidCallback? onRetry,
  }) {
    return (FlutterErrorDetails details) {
      return buildErrorFallback(
        stepName: stepName,
        onSkip: onSkip,
        onRetry: onRetry,
        error: details.exception,
      );
    };
  }
}

class _LessonStepErrorBoundaryState extends State<LessonStepErrorBoundary> {
  Object? _caughtError;

  @override
  void didUpdateWidget(LessonStepErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepName != widget.stepName) {
      _caughtError = null;
    }
  }

  void _handleRetry() {
    setState(() {
      _caughtError = null;
    });
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_caughtError != null) {
      return LessonStepErrorBoundary.buildErrorFallback(
        stepName: widget.stepName,
        onSkip: widget.onSkip,
        onRetry: _handleRetry,
        error: _caughtError,
      );
    }

    try {
      if (widget.builder != null) {
        return widget.builder!(context);
      }
      return widget.child ?? const SizedBox.shrink();
    } catch (e) {
      debugPrint('[LessonStepErrorBoundary] Caught build exception in step "${widget.stepName}": $e');
      _caughtError = e;
      return LessonStepErrorBoundary.buildErrorFallback(
        stepName: widget.stepName,
        onSkip: widget.onSkip,
        onRetry: _handleRetry,
        error: e,
      );
    }
  }
}

class _LessonStepErrorFallback extends StatelessWidget {
  final String stepName;
  final VoidCallback? onSkip;
  final VoidCallback? onRetry;
  final Object? error;

  const _LessonStepErrorFallback({
    required this.stepName,
    this.onSkip,
    this.onRetry,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: HiCard(
          backgroundColor: AppColors.cardBackground,
          borderColor: AppColors.border,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_outlined,
                  size: 32,
                  color: AppColors.primaryBlueDark,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Bước này gặp gián đoạn dữ liệu học liệu',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Nội dung bước $stepName đang được đồng bộ hoặc gặp lỗi hiển thị.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryText,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.lg),
                HiButton(
                  text: 'Thử lại',
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  variant: HiButtonVariant.secondary,
                  isFullWidth: true,
                  onPressed: onRetry,
                ),
              ],
              if (onSkip != null) ...[
                const SizedBox(height: AppSpacing.sm),
                HiButton(
                  text: 'Bỏ qua bước này',
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  variant: HiButtonVariant.primary,
                  isFullWidth: true,
                  onPressed: onSkip,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
