import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../hanzi_writing/presentation/screens/hanzi_writing_screen.dart';
import '../../domain/models/curriculum_models.dart';

class LessonVocabView extends StatelessWidget {
  final CurriculumLesson lesson;
  final LessonSegment? segment;
  final VoidCallback onNext;

  const LessonVocabView({
    super.key,
    required this.lesson,
    this.segment,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawWords = (segment?.contentPayload?['words'] as List<dynamic>?) ?? [];
    final words = rawWords.map((e) => e as Map<String, dynamic>).toList();

    if (words.isEmpty) {
      return Center(
        child: Text(
          'Đang nạp dữ liệu từ vựng...',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
        ),
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: words.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final w = words[index];
        final hanzi = (w['hanzi'] ?? w['simplified'] ?? '') as String;
        final pinyin = (w['pinyin'] ?? '') as String;
        final meaning = (w['meaning'] ?? w['meaning_vi'] ?? '') as String;
        final type = (w['type'] ?? w['part_of_speech'] ?? '') as String;

        return HiCard(
          backgroundColor: AppColors.cardBackground,
          borderColor: AppColors.border,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Character avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondaryBlue,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    hanzi,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlueDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Pinyin, Meaning & Type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pinyin,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlueDark,
                          ),
                        ),
                        if (type.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              type,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meaning,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons: Audio & Writing
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryBlueDark),
                tooltip: 'Nghe phát âm chuẩn',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Phát âm chuẩn: $hanzi [$pinyin]'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue),
                tooltip: 'Luyện viết nét bút thuận',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HanziWritingScreen(
                        initialCharacter: hanzi.isNotEmpty ? hanzi : '你',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
