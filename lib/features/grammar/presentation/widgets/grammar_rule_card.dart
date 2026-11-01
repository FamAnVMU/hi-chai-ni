import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/grammar_models.dart';

/// Card rendering grammatical structure, usage conditions, and sentence placement.
class GrammarRuleCard extends StatelessWidget {
  final GrammarItem item;

  const GrammarRuleCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.limeGreen.withAlpha(30),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'HSK ${item.hskLevel}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.limeGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Structure Formula Pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.limeGreen.withAlpha(80),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cấu trúc:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.structure,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.limeGreen,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Meaning
          _buildDetailRow(
            context,
            icon: Icons.lightbulb_outline_rounded,
            title: 'Ý nghĩa:',
            content: item.meaningVi,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Sentence Position
          _buildDetailRow(
            context,
            icon: Icons.alt_route_rounded,
            title: 'Vị trí trong câu:',
            content: item.sentencePositionVi,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Usage Conditions
          _buildDetailRow(
            context,
            icon: Icons.rule_rounded,
            title: 'Điều kiện sử dụng:',
            content: item.usageConditionsVi,
          ),
          const SizedBox(height: AppSpacing.md),

          // Source attribution
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 14,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Nguồn: ${item.source}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: content),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
