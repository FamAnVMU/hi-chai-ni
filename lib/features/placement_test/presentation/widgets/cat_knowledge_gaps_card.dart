import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/cat_assessment_result.dart';

/// Card listing specific pedagogical weaknesses detected and targeted consolidation advice.
class CatKnowledgeGapsCard extends StatelessWidget {
  final List<KnowledgeGapItem> knowledgeGaps;

  const CatKnowledgeGapsCard({
    super.key,
    required this.knowledgeGaps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HiCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: Colors.amber,
                size: AppDimensions.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Lỗ Hổng Trọng Tâm Cần Củng Cố',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (knowledgeGaps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.primaryBlueDark),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Rất tốt! Không phát hiện lỗ hổng kiến thức nghiêm trọng trong bài làm.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: knowledgeGaps.length,
              separatorBuilder: (_, _) => Divider(
                height: AppSpacing.md,
                color: theme.colorScheme.outlineVariant.withAlpha(40),
              ),
              itemBuilder: (context, index) {
                final gap = knowledgeGaps[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HiChip(
                          label: gap.skill.labelVi,
                          status: HiChipStatus.warning,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            gap.labelVi,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      gap.suggestedRemediationVi,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
