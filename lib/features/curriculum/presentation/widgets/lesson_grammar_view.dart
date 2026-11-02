import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';

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
    final points = rawPoints.map((e) => e as Map<String, dynamic>).toList();

    if (points.isEmpty) {
      return Center(
        child: Text(
          'Đang nạp các điểm ngữ pháp...',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: points.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
                    final p = points[index];
                    final title = (p['title'] ?? '') as String;
                    final structure = (p['structure'] ?? '') as String;
                    final explanation = (p['explanation'] ?? p['explanation_vi'] ?? '') as String;
                    final rawExamples = (p['examples'] as List<dynamic>?) ?? [];
                    final examples = rawExamples.map((e) => e as Map<String, dynamic>).toList();

                    return HiCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.limeGreenDark,
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
                                color: AppColors.limeGreen.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.limeGreen.withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.code_rounded, size: 16, color: AppColors.limeGreenDark),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cấu trúc: $structure',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.limeGreenDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            explanation,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                          ),
                          if (examples.isNotEmpty) ...[
                            const Divider(height: 24),
                            Text(
                              'Ví dụ minh họa:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
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
                                        color: AppColors.limeGreenDark,
                                      ),
                                    ),
                                    Text(
                                      '→ $vi',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: onAskAi,
                              icon: const Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.limeGreenDark),
                              label: const Text(
                                'Hỏi AI giải thích thêm',
                                style: TextStyle(color: AppColors.limeGreenDark),
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
