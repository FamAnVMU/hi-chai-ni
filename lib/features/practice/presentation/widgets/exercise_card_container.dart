import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/practice_models.dart';

/// Reusable outer shell displaying prompt, stimulus, audio button, and feedback
class ExerciseCardContainer extends StatelessWidget {
  final ExerciseDefinition definition;
  final ScoringResult? result;
  final Widget child;

  const ExerciseCardContainer({
    super.key,
    required this.definition,
    this.result,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Type badge & HSK
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  definition.type.displayName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryBlueDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'HSK ${definition.hskLevel}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Prompt
          Text(
            definition.prompt,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),

          // Stimulus (if any)
          if (definition.stimulus != null && definition.stimulus!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    definition.stimulus!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.primaryText,
                    ),
                  ),
                  if (definition.stimulusPinyin != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      definition.stimulusPinyin!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaryBlueDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // Core exercise interactive content
          child,

          // Evaluation Result Banner (if submitted)
          if (result != null) ...[
            const SizedBox(height: AppSpacing.md),
            _buildResultBanner(context, result!),
          ],
        ],
      ),
    );
  }

  Widget _buildResultBanner(BuildContext context, ScoringResult res) {
    final theme = Theme.of(context);
    final isCorrect = res.isCorrect;
    final needsReview = res.needsHumanReview;

    final bannerColor = isCorrect
        ? AppColors.successContainerLight
        : (needsReview ? AppColors.warningContainerLight : AppColors.errorContainerLight);
    final borderColor = isCorrect
        ? AppColors.success
        : (needsReview ? AppColors.warning : AppColors.error);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : (needsReview ? Icons.help_outline_rounded : Icons.cancel_rounded),
                    size: 18,
                    color: borderColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    isCorrect
                        ? 'Chính xác (${(res.score * 100).toInt()}%)'
                        : (needsReview ? 'Cần xem lại kết quả' : 'Chưa đúng'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: borderColor,
                    ),
                  ),
                ],
              ),
              if (res.evaluatorType == EvaluatorType.rubric)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: borderColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'Độ tin cậy: ${(res.confidence * 100).toInt()}%',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: borderColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            res.feedbackVi,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
