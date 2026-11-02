import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/cat_assessment_result.dart';
import '../../domain/models/cat_skill.dart';

/// Card displaying detailed breakdown across all 6 language skills with confidence,
/// unassessed handling, and sub-metric separation.
class CatSkillRadarCard extends StatelessWidget {
  final Map<CatSkill, SkillScoreEstimate> skillScores;

  const CatSkillRadarCard({
    super.key,
    required this.skillScores,
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
                Icons.analytics_outlined,
                color: AppColors.primaryBlueDark,
                size: AppDimensions.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Đánh Giá Chi Tiết 6 Kỹ Năng',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Skill items
          ...CatSkill.values.map((skill) {
            final estimate = skillScores[skill];
            return _buildSkillItem(context, skill, estimate);
          }),
        ],
      ),
    );
  }

  Widget _buildSkillItem(
    BuildContext context,
    CatSkill skill,
    SkillScoreEstimate? estimate,
  ) {
    final theme = Theme.of(context);
    final isAssessed = estimate?.isAssessed ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                skill.labelVi,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!isAssessed)
                const HiChip(
                  label: 'Chưa đánh giá',
                  status: HiChipStatus.neutral,
                )
              else ...[
                Text(
                  '${((estimate?.accuracyRate ?? 0.0) * 100).toInt()}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlueDark,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                HiChip(
                  label: 'Độ tin cậy: ${estimate?.confidenceLabel ?? "TB"}',
                  status: estimate?.confidenceLabel == 'Cao'
                      ? HiChipStatus.success
                      : HiChipStatus.neutral,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Accuracy Progress bar if assessed
          if (isAssessed) ...[
            HiLinearProgress(value: estimate?.accuracyRate ?? 0.0),
          ] else ...[
            Text(
              skill == CatSkill.speaking
                  ? 'Chưa đủ dữ liệu đánh giá phát âm qua audio'
                  : 'Kỹ năng này chưa được làm bài kiểm tra',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Distinct sub-metrics for Writing (Never mixed)
          if (skill == CatSkill.writing && isAssessed && estimate?.subMetrics != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                borderRadius: AppRadius.borderSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubMetricRow('Nhận diện chữ Hán', estimate!.subMetrics['character_recognition_accuracy']),
                  _buildSubMetricRow('Phiên âm Pinyin', estimate.subMetrics['pinyin_transcription_accuracy']),
                  _buildSubMetricRow('Thứ tự nét viết', estimate.subMetrics['stroke_order_accuracy']),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Divider(color: theme.colorScheme.outlineVariant.withAlpha(40)),
        ],
      ),
    );
  }

  Widget _buildSubMetricRow(String label, dynamic val) {
    final str = val != null ? '${((val as num) * 100).toInt()}%' : 'Chưa thi';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('• $label: ', style: const TextStyle(fontSize: 11)),
          Text(str, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
