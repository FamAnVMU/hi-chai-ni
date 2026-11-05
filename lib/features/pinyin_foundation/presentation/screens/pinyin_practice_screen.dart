import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/unified_audio_playback_service.dart';
import '../../domain/engine/pinyin_exercise_engine.dart';
import '../../domain/models/pinyin_models.dart';
import '../providers/pinyin_providers.dart';

class PinyinPracticeScreen extends ConsumerStatefulWidget {
  final PinyinLesson lesson;

  const PinyinPracticeScreen({super.key, required this.lesson});

  @override
  ConsumerState<PinyinPracticeScreen> createState() => _PinyinPracticeScreenState();
}

class _PinyinPracticeScreenState extends ConsumerState<PinyinPracticeScreen> {
  int _currentIndex = 0;
  String? _selectedOption;
  final TextEditingController _textController = TextEditingController();
  bool _isAnswered = false;
  PinyinExerciseEvaluationResult? _lastResult;
  final List<PinyinExerciseEvaluationResult> _results = [];
  final _engine = const PinyinExerciseEngine();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitAnswer() async {
    final ex = widget.lesson.exercises[_currentIndex];
    final answer = _selectedOption ?? _textController.text;
    if (answer.trim().isEmpty) return;

    final eval = _engine.evaluate(exercise: ex, submission: answer);
    setState(() {
      _lastResult = eval;
      _isAnswered = true;
      _results.add(eval);
    });

    // Save item progress in repository matching the exercise target item
    PinyinItem? matchedItem;
    if (ex.metadata.containsKey('item_id')) {
      final refId = ex.metadata['item_id'];
      matchedItem = widget.lesson.items.where((it) => it.id == refId).firstOrNull;
    }
    matchedItem ??= widget.lesson.items.where((it) {
      final sym = it.symbol.trim().toLowerCase();
      final ans = ex.correctAnswer.trim().toLowerCase();
      return ans == sym || ans.startsWith('$sym ') || ans.startsWith('$sym(') || ans.startsWith('$sym/');
    }).firstOrNull;
    matchedItem ??= widget.lesson.items.where((it) => it.audioUri == ex.audioUri).firstOrNull;
    if (matchedItem == null && widget.lesson.items.isNotEmpty) {
      final fallbackIndex = _currentIndex % widget.lesson.items.length;
      matchedItem = widget.lesson.items[fallbackIndex];
    }

    final itemId = matchedItem?.id ?? ex.id;
    final itemType = matchedItem?.type.name ?? 'syllable';

    await ref.read(pinyinRepositoryProvider).recordItemAttempt(
      itemId: itemId,
      itemType: itemType,
      isCorrect: eval.isCorrect,
      score: eval.score,
    );
  }

  void _nextQuestion() {
    if (_currentIndex + 1 < widget.lesson.exercises.length) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _selectedOption = null;
        _textController.clear();
        _lastResult = null;
      });
    } else {
      // Completed full session
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final finalScore = _engine.calculateLessonScore(_results);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hoàn thành luyện tập! 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Điểm số của bạn: ${(finalScore * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3979C7)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tiến độ phát âm của bạn đã được ghi nhận vào hệ thống học tập ngoại tuyến.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Về bài học', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.lesson.exercises;
    if (exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Luyện tập')),
        body: const Center(child: Text('Bài học chưa có câu hỏi luyện tập.')),
      );
    }

    final currentEx = exercises[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFE),
      appBar: AppBar(
        title: Text(
          'Luyện tập (${_currentIndex + 1}/${exercises.length})',
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / exercises.length,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5B9BE6)),
            ),
          ),
          const SizedBox(height: 20),

          // Exercise Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE3EBF4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentEx.prompt,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 16),

                // Audio Play button if exercise contains audio
                if (currentEx.audioUri.isNotEmpty)
                  Center(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3979C7),
                        side: const BorderSide(color: Color(0xFFB9D7F5)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('Nghe âm thanh mẫu', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        UnifiedAudioPlaybackService.instance.playAudio(
                          currentEx.audioUri,
                          simulatedDuration: const Duration(milliseconds: 1600),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),

                // Options (Multiple choice or Text Input)
                if (currentEx.options.isNotEmpty) ...[
                  ...currentEx.options.map((option) {
                    final isSelected = _selectedOption == option;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEAF3FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF5B9BE6) : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        title: Text(
                          option,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF5B9BE6))
                            : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1)),
                        onTap: _isAnswered
                            ? null
                            : () {
                                setState(() {
                                  _selectedOption = option;
                                });
                              },
                      ),
                    );
                  }),
                ] else ...[
                  TextField(
                    controller: _textController,
                    enabled: !_isAnswered,
                    decoration: InputDecoration(
                      hintText: 'Nhập Pinyin (ví dụ: xièxie)...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ],

                // Feedback section
                if (_isAnswered && _lastResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _lastResult!.isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _lastResult!.isCorrect ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _lastResult!.isCorrect ? Icons.check_circle : Icons.cancel,
                              color: _lastResult!.isCorrect ? const Color(0xFF22A06B) : const Color(0xFFE05D66),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _lastResult!.feedback,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _lastResult!.isCorrect ? const Color(0xFF166534) : const Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _lastResult!.explanation,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B9BE6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _isAnswered ? _nextQuestion : _submitAnswer,
              child: Text(
                _isAnswered ? (_currentIndex + 1 == exercises.length ? 'Xem kết quả' : 'Câu tiếp theo') : 'Kiểm tra',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
