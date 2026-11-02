import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';

class LessonDialogueView extends StatelessWidget {
  final CurriculumLesson lesson;
  final LessonSegment? segment;
  final VoidCallback onNext;

  const LessonDialogueView({
    super.key,
    required this.lesson,
    this.segment,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawLines = (segment?.contentPayload?['lines'] as List<dynamic>?) ??
        (segment?.contentPayload?['dialogue']?['lines'] as List<dynamic>?) ??
        [];
    final lines = rawLines.map((e) => e as Map<String, dynamic>).toList();

    if (lines.isEmpty) {
      return Center(
        child: Text(
          'Đang nạp bài hội thoại...',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: lines.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
                    final item = lines[index];
                    final speaker = (item['speaker'] ?? 'A') as String;
                    final hanzi = (item['hanzi'] ?? item['chinese'] ?? '') as String;
                    final pinyin = (item['pinyin'] ?? '') as String;
                    final meaning = (item['meaning'] ?? item['vietnamese'] ?? '') as String;

                    final isSpeakerA = speaker == 'A';

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:
                          isSpeakerA ? MainAxisAlignment.start : MainAxisAlignment.end,
                      children: [
                        if (isSpeakerA) ...[
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.limeGreenDark,
                            child: Text(
                              speaker,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: isSpeakerA
                                  ? AppColors.limeGreen.withAlpha(20)
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16).copyWith(
                                topLeft: isSpeakerA ? const Radius.circular(0) : const Radius.circular(16),
                                topRight: !isSpeakerA ? const Radius.circular(0) : const Radius.circular(16),
                              ),
                              border: Border.all(
                                color: isSpeakerA
                                    ? AppColors.limeGreen.withAlpha(80)
                                    : theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hanzi,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (pinyin.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    pinyin,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.limeGreenDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  meaning,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isSpeakerA) ...[
                          const SizedBox(width: AppSpacing.sm),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.limeGreen,
                            child: Text(
                              speaker,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
  }
}
