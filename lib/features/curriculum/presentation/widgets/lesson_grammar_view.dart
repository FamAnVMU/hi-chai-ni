import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';
import 'lesson_content_empty_state.dart';

class LessonGrammarView extends StatelessWidget {
  final CurriculumLesson lesson;
  final LessonSegment? segment;
  final VoidCallback onNext;
  final VoidCallback? onAskAi;

  const LessonGrammarView({
    super.key,
    required this.lesson,
    this.segment,
    required this.onNext,
    this.onAskAi,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawPoints = (segment?.contentPayload?['points'] as List<dynamic>?) ??
        (segment?.contentPayload?['grammar_points'] as List<dynamic>?) ??
        [];
    final points = rawPoints.whereType<Map<String, dynamic>>().toList();

    if (points.isEmpty) {
      return LessonContentEmptyState(
        title: 'Nội dung ngữ pháp đang được chuẩn bị',
        message: 'Chưa tìm thấy các điểm ngữ pháp cho phần học này trong cơ sở dữ liệu hiện tại.',
        icon: Icons.auto_stories_outlined,
        buttonText: 'Tiếp tục bài học',
        onAction: onNext,
        segmentId: segment?.id,
        contentRefId: segment?.contentRefId,
        segmentType: segment?.segmentType,
        lessonId: lesson.id,
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: points.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final point = GrammarPoint.fromMap(points[index]);
        final title = point.title;
        final structure = point.structure;
        final explanation = point.explanation;
        final examples = point.examples;
        final positiveExample = point.positiveExample ?? '';
        final contrastiveExample = point.contrastiveExample ?? '';

        return HiCard(
          backgroundColor: AppColors.cardBackground,
          borderColor: AppColors.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlueDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              if (structure.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlueLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.secondaryBlue),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.code_rounded, size: 16, color: AppColors.primaryBlueDark),
                      const SizedBox(width: 6),
                      Text(
                        'Cấu trúc: $structure',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlueDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                explanation,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  color: AppColors.primaryText,
                ),
              ),
              if (examples.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.divider),
                ),
                Text(
                  'Ví dụ minh họa:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                ...examples.map((ex) {
                  final zh = (ex['chinese'] ?? ex['zh'] ?? '') as String;
                  final py = (ex['pinyin'] ?? ex['py'] ?? '') as String;
                  final vi = (ex['vietnamese'] ?? ex['vi'] ?? '') as String;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$zh ($py)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlueDark,
                          ),
                        ),
                        Text(
                          '→ $vi',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (positiveExample.isNotEmpty || contrastiveExample.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.divider),
                ),
                if (positiveExample.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.successContainerLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withAlpha(80)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ví dụ đúng:',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                positiveExample,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (contrastiveExample.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningContainerLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withAlpha(80)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lưu ý / Phản ví dụ:',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                contrastiveExample,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAskAi,
                  icon: const Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.primaryBlueDark),
                  label: const Text(
                    'Hỏi AI giải thích thêm',
                    style: TextStyle(color: AppColors.primaryBlueDark, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
