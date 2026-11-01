import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/cat_skill.dart';

/// Header displaying current skill badge, question counter, and skip action.
class CatProgressHeader extends StatelessWidget {
  final CatSkill skill;
  final int stepIndex;
  final int maxEstimatedSteps;
  final VoidCallback onSkip;

  const CatProgressHeader({
    super.key,
    required this.skill,
    required this.stepIndex,
    this.maxEstimatedSteps = 20,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (stepIndex / maxEstimatedSteps).clamp(0.05, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            HiChip(
              label: skill.labelVi,
              status: HiChipStatus.info,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Câu ${stepIndex + 1}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onSkip,
              child: const Text('Bỏ qua'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        HiLinearProgress(value: progress),
      ],
    );
  }
}
