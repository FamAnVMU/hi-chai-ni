import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/catalog/curriculum_catalog.dart';
import '../../domain/models/roadmap_models.dart';

/// Modal bottom sheet displaying deep pedagogical details for a curriculum lesson.
class LessonDetailSheet extends StatefulWidget {
  final CurriculumLesson lesson;
  final LessonProgress? progress;
  final Map<String, LessonProgress> allProgressMap;
  final VoidCallback onStart;
  final ValueChanged<double> onComplete;
  final VoidCallback onSkip;

  const LessonDetailSheet({
    super.key,
    required this.lesson,
    required this.progress,
    required this.allProgressMap,
    required this.onStart,
    required this.onComplete,
    required this.onSkip,
  });

  static Future<void> show({
    required BuildContext context,
    required CurriculumLesson lesson,
    required LessonProgress? progress,
    required Map<String, LessonProgress> allProgressMap,
    required VoidCallback onStart,
    required ValueChanged<double> onComplete,
    required VoidCallback onSkip,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LessonDetailSheet(
        lesson: lesson,
        progress: progress,
        allProgressMap: allProgressMap,
        onStart: onStart,
        onComplete: onComplete,
        onSkip: onSkip,
      ),
    );
  }

  @override
  State<LessonDetailSheet> createState() => _LessonDetailSheetState();
}

class _LessonDetailSheetState extends State<LessonDetailSheet> {
  bool _isActionInFlight = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lesson = widget.lesson;
    final progress = widget.progress;
    final allProgressMap = widget.allProgressMap;
    final status = progress?.status ?? LessonStatus.locked;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case LessonStatus.locked:
        statusColor = theme.colorScheme.outline;
        statusText = 'Đang khóa (Chưa đạt tiên quyết)';
        statusIcon = Icons.lock_outline_rounded;
        break;
      case LessonStatus.available:
        statusColor = AppColors.primaryBlueDark;
        statusText = 'Có thể học ngay';
        statusIcon = Icons.lock_open_rounded;
        break;
      case LessonStatus.inProgress:
        statusColor = Colors.orange;
        statusText = 'Đang học dở';
        statusIcon = Icons.timelapse_rounded;
        break;
      case LessonStatus.completed:
        statusColor = AppColors.primaryBlueDark;
        statusText = 'Đã hoàn thành';
        statusIcon = Icons.check_circle_rounded;
        break;
      case LessonStatus.skipped:
        statusColor = theme.colorScheme.onSurfaceVariant;
        statusText = 'Đã bỏ qua';
        statusIcon = Icons.skip_next_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Top Status Badge
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
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
                      '~${lesson.estimatedMinutes} phút',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Lesson Title & Description
            Text(
              lesson.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              lesson.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),

            // Prerequisites Section
            if (lesson.prerequisiteLessonIds.isNotEmpty) ...[
              Text(
                'Điều kiện tiên quyết:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ...lesson.prerequisiteLessonIds.map((preId) {
                final preLesson = CurriculumCatalog.findLessonById(preId);
                final preProgress = allProgressMap[preId];
                final isDone = preProgress?.isCompleted ?? false;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: isDone ? AppColors.primaryBlueDark : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          preLesson?.title ?? preId,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDone ? null : theme.colorScheme.onSurfaceVariant,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.md),
            ],

            // Content References (if any)
            if (lesson.contentReferences.isNotEmpty) ...[
              Text(
                'Tài liệu liên quan:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: lesson.contentReferences.entries.map((entry) {
                  return Chip(
                    label: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Progress Evidence details if in-progress or completed
            if (progress != null && progress.evidenceCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_edu_rounded,
                      size: 16,
                      color: AppColors.primaryBlueDark,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Số bằng chứng ghi nhận: ${progress.evidenceCount}',
                      style: theme.textTheme.labelSmall,
                    ),
                    if (progress.completionScore != null) ...[
                      const Spacer(),
                      Text(
                        'Điểm đạt: ${(progress.completionScore! * 100).toInt()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlueDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Action Buttons
            Row(
              children: [
                if (status != LessonStatus.locked) ...[
                  Expanded(
                    child: HiButton(
                      text: status == LessonStatus.completed ? 'Ôn lại' : 'Bắt đầu học',
                      variant: HiButtonVariant.primary,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      onPressed: () {
                        if (_isActionInFlight) return;
                        setState(() => _isActionInFlight = true);
                        Navigator.of(context).pop();
                        widget.onStart();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  HiButton(
                    text: 'Bỏ qua',
                    variant: HiButtonVariant.secondary,
                    onPressed: () {
                      if (_isActionInFlight) return;
                      setState(() => _isActionInFlight = true);
                      Navigator.of(context).pop();
                      widget.onSkip();
                    },
                  ),
                ] else ...[
                  Expanded(
                    child: HiButton(
                      text: 'Bài học đang khóa',
                      variant: HiButtonVariant.secondary,
                      onPressed: () {
                        if (_isActionInFlight) return;
                        setState(() => _isActionInFlight = true);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ],
            ),
            if (status == LessonStatus.inProgress) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: HiButton(
                  text: 'Xác nhận hoàn thành bài học',
                  variant: HiButtonVariant.secondary,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  onPressed: () {
                    if (_isActionInFlight) return;
                    setState(() => _isActionInFlight = true);
                    Navigator.of(context).pop();
                    // Anti-Cheating (BUG-NEW-005): Never fabricate 0.8 score.
                    // If progress?.score is null (unassessed), default to 0.0 to prevent cheating bypass.
                    widget.onComplete(progress?.score ?? 0.0);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
