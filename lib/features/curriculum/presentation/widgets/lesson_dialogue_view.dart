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
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
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
                radius: 16,
                backgroundColor: AppColors.primaryBlueDark,
                child: Text(
                  speaker,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isSpeakerA
                      ? AppColors.primaryBlueLight
                      : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    topLeft: isSpeakerA ? const Radius.circular(2) : const Radius.circular(16),
                    topRight: !isSpeakerA ? const Radius.circular(2) : const Radius.circular(16),
                  ),
                  border: Border.all(
                    color: isSpeakerA
                        ? AppColors.secondaryBlue
                        : AppColors.border,
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
                        color: AppColors.primaryText,
                      ),
                    ),
                    if (pinyin.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        pinyin,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryBlueDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      meaning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isSpeakerA) ...[
              const SizedBox(width: AppSpacing.sm),
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryBlue,
                child: Text(
                  speaker,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
