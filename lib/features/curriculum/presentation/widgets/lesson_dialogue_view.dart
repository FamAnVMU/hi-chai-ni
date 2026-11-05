import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';
import 'lesson_content_empty_state.dart';

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
    final rawLines = segment?.contentPayload?['lines'] ??
        segment?.contentPayload?['dialogue']?['lines'] ??
        segment?.contentPayload?['dialogue'] ??
        segment?.contentPayload?['dialogues'] ??
        [];
    final lines = (rawLines is List)
        ? rawLines.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];

    if (lines.isEmpty) {
      return LessonContentEmptyState(
        title: 'Nội dung hội thoại đang được chuẩn bị',
        message: 'Chưa tìm thấy đoạn hội thoại cho phần học này trong cơ sở dữ liệu hiện tại.',
        icon: Icons.chat_bubble_outline_rounded,
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
      itemCount: lines.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final item = lines[index];
        final speaker = (item['speaker'] ?? item['role'] ?? 'A').toString();
        final hanzi = (item['text_zh'] ?? item['hanzi'] ?? item['chinese'] ?? item['text'] ?? '').toString();
        final pinyin = (item['pinyin'] ?? item['transcription'] ?? '').toString();
        final meaning = (item['text_vi'] ?? item['meaning'] ?? item['vietnamese'] ?? item['translation'] ?? '').toString();

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
