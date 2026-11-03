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
      backgroundColor: AppColors.cardBackground,
      borderColor: AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'HSK ${item.hskLevel}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryBlueDark,
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
                    color: AppColors.primaryText,
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
              color: AppColors.primaryBlueLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.secondaryBlue,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cấu trúc:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.structure,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlueDark,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Meaning / Explanation
          if (item.meaningVi.isNotEmpty || item.explanationVi.isNotEmpty) ...[
            _buildDetailRow(
              context,
              icon: Icons.lightbulb_outline_rounded,
              title: 'Ý nghĩa:',
              content: item.meaningVi.isNotEmpty ? item.meaningVi : item.explanationVi,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Sentence Position
          if (item.sentencePositionVi.isNotEmpty) ...[
            _buildDetailRow(
              context,
              icon: Icons.alt_route_rounded,
              title: 'Vị trí trong câu:',
              content: item.sentencePositionVi,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Usage Conditions
          if (item.usageConditionsVi.isNotEmpty) ...[
            _buildDetailRow(
              context,
              icon: Icons.rule_rounded,
              title: 'Điều kiện sử dụng:',
              content: item.usageConditionsVi,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Source attribution
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 14,
                color: AppColors.mutedText,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Nguồn: ${item.source}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.mutedText,
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
        Icon(icon, size: 16, color: AppColors.primaryBlueDark),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primaryText),
              children: [
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText),
                ),
                TextSpan(text: content, style: const TextStyle(color: AppColors.secondaryText)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
