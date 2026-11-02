import 'package:flutter/material.dart';
import '../../../../core/audio/unified_audio_playback_service.dart';
import '../../domain/models/pinyin_models.dart';
import '../widgets/pinyin_tone_contour_chart.dart';
import 'pinyin_practice_screen.dart';

class PinyinLessonScreen extends StatelessWidget {
  final PinyinLesson lesson;

  const PinyinLessonScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final hasTones = lesson.items.any((i) => i.type == PinyinItemType.tone);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFE),
      appBar: AppBar(
        title: Text(
          lesson.titleVi,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEDF2F7), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Lesson Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3EBF4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF478DD4)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lesson.summary,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tone visualizer if relevant
          if (hasTones) ...[
            const PinyinToneContourChart(selectedTone: 3),
            const SizedBox(height: 16),
          ],

          // Phonetic Items
          ...lesson.items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE3EBF4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.symbol,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3979C7),
                            ),
                          ),
                          if (item.ipa.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              item.ipa,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF94A3B8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          if (item.isAspirated)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFED7AA)),
                              ),
                              child: const Text(
                                'Bật hơi mạnh',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF5B9BE6), size: 28),
                            onPressed: () {
                              UnifiedAudioPlaybackService.instance.playAudio(
                                item.audioUri,
                                simulatedDuration: const Duration(milliseconds: 1500),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Articulation guide
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.fitness_center_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.articulationGuide,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Vietnamese contrast
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F6FC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.compare_arrows_rounded, size: 16, color: Color(0xFF478DD4)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'So với tiếng Việt: ${item.vietnameseContrast}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.exampleWords.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: item.exampleWords.map((ex) {
                        return Chip(
                          backgroundColor: const Color(0xFFEAF3FF),
                          label: Text(
                            ex,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF3979C7), fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 12),

          // Exercise Navigation Button
          if (lesson.exercises.isNotEmpty)
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9BE6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.assignment_turned_in_rounded),
                label: Text(
                  'Luyện tập bài học (${lesson.exercises.length} câu hỏi)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PinyinPracticeScreen(lesson: lesson),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
