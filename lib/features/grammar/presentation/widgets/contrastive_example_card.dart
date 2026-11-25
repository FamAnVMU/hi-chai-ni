import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/grammar_models.dart';

/// Card contrasting correct usage with common learner mistakes and explaining L1 transfer errors.
class ContrastiveExampleCard extends StatelessWidget {
  final ContrastiveExample example;

  const ContrastiveExampleCard({super.key, required this.example});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.hiCardSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: context.hiBorderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Incorrect sentence
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.cancel_rounded,
                  color: context.hiErrorFg,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    example.incorrectSentence,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.hiErrorFg,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Correct sentence
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: context.hiSuccessFg,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    example.correctSentence,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.hiSuccessFg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Explanation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.hiInputSurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: context.hiBorderColor),
              ),
              child: Text(
                example.explanationVi,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: context.hiSecondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
