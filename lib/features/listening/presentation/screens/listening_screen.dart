import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../providers/listening_providers.dart';

class ListeningScreen extends ConsumerWidget {
  const ListeningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeLesson = ref.watch(activeListeningLessonProvider);
    final playbackState = ref.watch(listeningPlaybackProvider);
    final notifier = ref.read(listeningPlaybackProvider.notifier);

    if (activeLesson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Luyện Nghe Hiểu')),
        body: const Center(child: Text('Không có bài nghe nào khả dụng.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện Nghe Hiểu (Listening)'),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            // Lesson Header
            HiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      HiChip(
                        label: 'HSK ${activeLesson.hskLevel}',
                        status: HiChipStatus.neutral,
                      ),
                      Text(
                        'Thời lượng: ${activeLesson.durationSeconds}s',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    activeLesson.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activeLesson.description,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Audio Player Controls Card
            HiCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_5_rounded),
                        onPressed: () {
                          // Replay 5 seconds
                        },
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.limeGreen,
                        child: IconButton(
                          icon: Icon(
                            playbackState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: AppColors.darkForestBg,
                            size: 32,
                          ),
                          onPressed: notifier.togglePlay,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Speed chips
                      Wrap(
                        spacing: 4,
                        children: [0.8, 1.0, 1.2].map((spd) {
                          final isSelected = (playbackState.playbackSpeed - spd).abs() < 0.05;
                          return ChoiceChip(
                            label: Text('${spd}x', style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) notifier.setPlaybackSpeed(spd);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Text('00:00', style: TextStyle(fontSize: 11)),
                      Expanded(
                        child: Slider(
                          value: 0.0,
                          onChanged: (_) {},
                        ),
                      ),
                      Text(
                        '00:${activeLesson.durationSeconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Transcript Reveal Toggle
            OutlinedButton.icon(
              icon: Icon(
                playbackState.showTranscript ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
              ),
              label: Text(playbackState.showTranscript ? 'Ẩn lời thoại (Transcript)' : 'Xem lời thoại (Transcript)'),
              onPressed: notifier.toggleTranscript,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Transcript Box (if shown)
            if (playbackState.showTranscript) ...[
              HiCard(
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lời thoại tiếng Trung (Hanzi):', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(activeLesson.transcriptZh, style: const TextStyle(fontSize: 14, height: 1.5)),
                    const Divider(height: AppSpacing.md),
                    Text('Phiên âm (Pinyin):', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(activeLesson.transcriptPinyin, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.limeGreen)),
                    const Divider(height: AppSpacing.md),
                    Text('Bản dịch tiếng Việt:', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(activeLesson.transcriptVi, style: TextStyle(fontSize: 13, height: 1.4, color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Comprehension Questions
            Text(
              'Câu Hỏi Đọc Hiểu Nội Dung',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            ...activeLesson.questions.map((q) {
              final selectedOpt = playbackState.selectedAnswers[q.id];
              final isSubmitted = playbackState.submittedQuestions[q.id] == true;
              final isCorrect = selectedOpt != null && q.isCorrect(selectedOpt);

              return HiCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.prompt,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...List.generate(q.options.length, (optIdx) {
                      final optText = q.options[optIdx];
                      final isSelected = selectedOpt == optIdx;

                      Color? optColor;
                      if (isSubmitted) {
                        if (optIdx == q.correctOptionIndex) {
                          optColor = Colors.green.withAlpha(40);
                        } else if (isSelected) {
                          optColor = Colors.red.withAlpha(40);
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: optColor,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: RadioListTile<int>(
                          dense: true,
                          title: Text(optText),
                          value: optIdx,
                          groupValue: selectedOpt,
                          onChanged: isSubmitted
                              ? null
                              : (val) {
                                  if (val != null) notifier.selectAnswer(q.id, val);
                                },
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.xs),
                    if (!isSubmitted)
                      HiButton(
                        text: 'Nộp câu trả lời',
                        variant: HiButtonVariant.secondary,
                        size: HiButtonSize.sm,
                        onPressed: selectedOpt == null ? null : () => notifier.submitQuestion(q.id),
                      )
                    else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isCorrect ? Colors.green.withAlpha(20) : Colors.red.withAlpha(20),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: isCorrect ? Colors.green : Colors.redAccent, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCorrect ? '✓ Chính xác!' : '✗ Chưa chính xác',
                              style: TextStyle(
                                color: isCorrect ? Colors.green : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              q.explanationVi,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }
}
