import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/roadmap_models.dart';

/// Card rendering top adaptive recommendations with transparent pedagogical rationale.
class RoadmapRecommendationCard extends StatelessWidget {
  final List<RoadmapRecommendation> recommendations;
  final ValueChanged<CurriculumLesson> onSelectLesson;
  final ValueChanged<CurriculumLesson> onSkipLesson;

  const RoadmapRecommendationCard({
    super.key,
    required this.recommendations,
    required this.onSelectLesson,
    required this.onSkipLesson,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (recommendations.isEmpty) {
      return HiCard(
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.limeGreen,
              size: AppDimensions.iconLg,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đã hoàn thành xuất sắc!',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bạn đã hoàn thành các đề xuất cốt lõi. Hãy chọn bài tiếp theo hoặc nâng mục tiêu HSK.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.limeGreen,
              size: AppDimensions.iconMd,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Đề Xuất Cho Bạn (Thích Ứng)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Dựa trên Placement Test, kết quả luyện tập gần đây và kiến thức tiên quyết.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...recommendations.map((rec) => _buildRecommendationItem(context, rec)),
      ],
    );
  }

  Widget _buildRecommendationItem(
    BuildContext context,
    RoadmapRecommendation rec,
  ) {
    final theme = Theme.of(context);
    final lesson = rec.lesson;

    Color priorityColor;
    String priorityLabel;
    IconData priorityIcon;

    switch (rec.priority) {
      case RecommendationPriority.urgent:
        priorityColor = AppColors.errorLight;
        priorityLabel = 'Cần củng cố';
        priorityIcon = Icons.warning_amber_rounded;
        break;
      case RecommendationPriority.recommended:
        priorityColor = AppColors.limeGreen;
        priorityLabel = 'Đề xuất tiếp theo';
        priorityIcon = Icons.trending_up_rounded;
        break;
      case RecommendationPriority.enrichment:
        priorityColor = Colors.teal;
        priorityLabel = 'Mở rộng nâng cao';
        priorityIcon = Icons.stars_rounded;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: HiCard(
        borderColor: priorityColor.withAlpha(120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(priorityIcon, size: 14, color: priorityColor),
                      const SizedBox(width: 4),
                      Text(
                        priorityLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: priorityColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HiChip(
                      label: lesson.primarySkill.displayName,
                      status: HiChipStatus.neutral,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '~${lesson.estimatedMinutes}p',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              lesson.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lesson.description,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Rationale explanation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Lý do đề xuất:',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (rec.supportingEvidence.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...rec.supportingEvidence.map(
                      (ev) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(' • ', style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Text(
                                ev,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: HiButton(
                    text: 'Học ngay',
                    size: HiButtonSize.sm,
                    variant: HiButtonVariant.primary,
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    onPressed: () => onSelectLesson(lesson),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                HiButton(
                  text: 'Bỏ qua',
                  size: HiButtonSize.sm,
                  variant: HiButtonVariant.secondary,
                  onPressed: () => onSkipLesson(lesson),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
