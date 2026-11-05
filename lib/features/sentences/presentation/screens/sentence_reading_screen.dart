import 'package:flutter/material.dart';
import '../../data/sentence_repository.dart';
import '../../domain/models/sentence_models.dart';
import '../../domain/services/sentence_audio_manager.dart';

/// Screen for Sentence Reading & Linguistic Analysis
/// Allows tapping word tokens to see meanings, HSK levels, and grammar points.
class SentenceReadingScreen extends StatefulWidget {
  final SentenceItem sentence;
  final SentenceRepository repository;

  const SentenceReadingScreen({
    super.key,
    required this.sentence,
    required this.repository,
  });

  @override
  State<SentenceReadingScreen> createState() => _SentenceReadingScreenState();
}

class _SentenceReadingScreenState extends State<SentenceReadingScreen> {
  late final SentenceAudioManager _audioManager;
  bool _isPlaying = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _audioManager = SentenceAudioManager();
    _audioManager.isPlayingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
  }

  @override
  void dispose() {
    _audioManager.dispose();
    super.dispose();
  }

  void _onTokenTapped(SentenceToken token) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  token.word,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'HSK ${token.hskLevel}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              token.pinyin,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 12),
            Text(
              'Ý nghĩa: ${token.meaningVi.isNotEmpty ? token.meaningVi : 'Từ vựng tiếng Trung'}',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Phát âm từ này'),
                    onPressed: () => _audioManager.playTts(token.word),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sentence;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện đọc & Phân tích câu'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sentence Analysis Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Full Sentence Pinyin
                  Text(
                    s.pinyin,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Interactive Tokenized Hanzi
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: s.tokens.isNotEmpty
                        ? s.tokens.map((token) {
                            return InkWell(
                              onTap: () => _onTokenTapped(token),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50.withAlpha(80),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  token.word,
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }).toList()
                        : [
                            Text(s.chinese, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                          ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Translation
                  Text(
                    s.translationVi.isNotEmpty ? s.translationVi : s.translationEn,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                  if (s.translationEn.isNotEmpty && s.translationVi.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      s.translationEn,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Audio Playback
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: Icon(_isPlaying ? Icons.pause : Icons.volume_up),
                label: Text(_isPlaying ? 'Đang phát...' : 'Nghe phát âm'),
                onPressed: () => _audioManager.playSentence(s),
              ),
            ),

            const SizedBox(height: 24),

            // Grammar Points Card (if present)
            if (s.grammarTags.isNotEmpty) ...[
              const Text('Ngữ pháp trong câu:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: s.grammarTags.map((g) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.bookmark, size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              g,
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Vocabulary List
            if (s.tokens.isNotEmpty) ...[
              const Text('Từ vựng thành phần:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              for (final t in s.tokens)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(t.word, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${t.pinyin} • ${t.meaningVi}'),
                    trailing: Text('HSK ${t.hskLevel}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () => _onTokenTapped(t),
                  ),
                ),
            ],

            const SizedBox(height: 24),

            // Completion Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('complete_reading_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCompleted ? Colors.green : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_isCompleted ? Icons.check_circle : Icons.task_alt),
                label: Text(
                  _isCompleted ? 'Đã ghi nhận hoàn thành' : 'Hoàn thành bài đọc',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _isCompleted
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await widget.repository.recordPracticeAttempt(
                          sentenceId: widget.sentence.id,
                          practiceType: 'reading',
                          score: 100.0,
                        );
                        if (!mounted) return;
                        setState(() => _isCompleted = true);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Đã hoàn thành bài đọc câu!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
