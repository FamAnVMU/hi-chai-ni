import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class LessonContentEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String buttonText;
  final VoidCallback? onAction;
  final String? segmentId;
  final String? contentRefId;
  final String? segmentType;
  final String? lessonId;

  LessonContentEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.hourglass_empty_rounded,
    this.buttonText = 'Tiếp tục bài học',
    this.onAction,
    this.segmentId,
    this.contentRefId,
    this.segmentType,
    this.lessonId,
  }) {
    // Log technical diagnostics without exposing learner PII
    debugPrint(
      '[CurriculumUI] Missing/empty content payload: '
      'lessonId=$lessonId, segmentId=$segmentId, '
      'contentRefId=$contentRefId, segmentType=$segmentType',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
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
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: AppColors.primaryBlueDark,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryText,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                RepaintBoundary(
                  child: HiButton(
                    text: buttonText,
                    icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    variant: HiButtonVariant.primary,
                    isFullWidth: true,
                    onPressed: onAction,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
