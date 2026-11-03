import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/sentence_repository.dart';
import '../../domain/models/sentence_models.dart';
import '../../domain/services/sentence_audio_manager.dart';

/// Screen for Sentence Listening Practice with speed control,
/// text/pinyin visibility toggles, audio source badge, and comprehension quiz.
class SentenceListeningScreen extends StatefulWidget {
  final SentenceItem sentence;
  final List<SentenceItem> sentenceList;
  final SentenceRepository repository;
  final bool autoPlay;

  const SentenceListeningScreen({
    super.key,
    required this.sentence,
    this.sentenceList = const [],
    required this.repository,
    this.autoPlay = true,
  });

  @override
  State<SentenceListeningScreen> createState() => _SentenceListeningScreenState();
}

class _SentenceListeningScreenState extends State<SentenceListeningScreen> {
  late SentenceItem _currentSentence;
  late int _currentIndex;
  late final SentenceAudioManager _audioManager;

  bool _showChinese = false;
  bool _showPinyin = false;
  double _speed = 1.0;
  bool _isPlaying = false;
  AudioType _audioType = AudioType.unknown;

  // Quiz state
  List<String> _quizOptions = [];
  String? _selectedOption;

  @override
  void initState() {
    super.initState();
    _currentSentence = widget.sentence;
    _currentIndex = widget.sentenceList.indexOf(widget.sentence);
    if (_currentIndex < 0) _currentIndex = 0;

    _audioManager = SentenceAudioManager();

    _audioManager.isPlayingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    _audioManager.audioTypeStream.listen((type) {
      if (mounted) setState(() => _audioType = type);
    });

    _setupQuiz();
    if (widget.autoPlay) {
      _playCurrent();
    }
  }

  @override
  void dispose() {
    _audioManager.dispose();
    super.dispose();
  }

  void _setupQuiz() {
    _selectedOption = null;

    final correct = _currentSentence.translationVi.isNotEmpty
        ? _currentSentence.translationVi
        : _currentSentence.translationEn;

    final distractors = <String>[];
    for (final s in widget.sentenceList) {
      if (s.id != _currentSentence.id) {
        final t = s.translationVi.isNotEmpty ? s.translationVi : s.translationEn;
        if (t.isNotEmpty && t != correct && !distractors.contains(t)) {
          distractors.add(t);
        }
      }
      if (distractors.length >= 3) break;
    }

    while (distractors.length < 3) {
      distractors.add('Nghĩa khác mẫu ${distractors.length + 1}');
    }

    final all = [correct, ...distractors.take(3)]..shuffle(Random());
    setState(() {
      _quizOptions = all;
    });
  }

  Future<void> _playCurrent({double? speed}) async {
    await _audioManager.playSentence(_currentSentence, speed: speed ?? _speed);
  }

  void _onOptionSelected(String option) {
    if (_selectedOption != null) return; // Already answered

    final correct = _currentSentence.translationVi.isNotEmpty
        ? _currentSentence.translationVi
        : _currentSentence.translationEn;

    final isRight = option == correct;
    setState(() {
      _selectedOption = option;
      _showChinese = true;
      _showPinyin = true;
    });

    widget.repository.recordPracticeAttempt(
      sentenceId: _currentSentence.id,
      practiceType: 'listening',
      score: isRight ? 100.0 : 40.0,
    );
  }

  void _nextSentence() {
    if (widget.sentenceList.isNotEmpty && _currentIndex < widget.sentenceList.length - 1) {
      setState(() {
        _currentIndex++;
        _currentSentence = widget.sentenceList[_currentIndex];
        _showChinese = false;
        _showPinyin = false;
      });
      _setupQuiz();
      _playCurrent();
    }
  }

  void _previousSentence() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _currentSentence = widget.sentenceList[_currentIndex];
        _showChinese = false;
        _showPinyin = false;
      });
      _setupQuiz();
      _playCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _currentSentence;

    return Scaffold(
      appBar: AppBar(
        title: Text('Luyện nghe HSK ${s.hskLevel}'),
        elevation: 0,
        actions: [
          // Speed dropdown
          PopupMenuButton<double>(
            initialValue: _speed,
            tooltip: 'Tốc độ đọc',
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speed, size: 20),
                const SizedBox(width: 4),
                Text('${_speed}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            onSelected: (val) {
              setState(() => _speed = val);
              _audioManager.setSpeed(val);
              _playCurrent(speed: val);
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 0.5, child: Text('0.5x (Rất chậm)')),
              PopupMenuItem(value: 0.75, child: Text('0.75x (Chậm)')),
              PopupMenuItem(value: 1.0, child: Text('1.0x (Chuẩn)')),
              PopupMenuItem(value: 1.25, child: Text('1.25x (Nhanh)')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Audio Source Badge (Mandatory transparency!)
            _buildAudioSourceBadge(),

            const SizedBox(height: 20),

            // Big Play Button Container
            GestureDetector(
              onTap: () => _playCurrent(),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2563EB), width: 2),
                ),
                child: Center(
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                    size: 50,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isPlaying ? 'Đang phát...' : 'Nhấn để nghe lại',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),

            const SizedBox(height: 24),

            // Sentence Card with reveal toggles
            _buildSentenceCard(),

            const SizedBox(height: 24),

            // Quiz Section (Meaning Selection)
            _buildQuizSection(),

            const SizedBox(height: 20),

            // Navigation Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: _currentIndex > 0 ? _previousSentence : null,
                  tooltip: 'Câu trước',
                ),
                Text(
                  'Câu ${_currentIndex + 1} / ${widget.sentenceList.isNotEmpty ? widget.sentenceList.length : 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.skip_next),
                  onPressed: widget.sentenceList.isNotEmpty && _currentIndex < widget.sentenceList.length - 1
                      ? _nextSentence
                      : null,
                  tooltip: 'Câu sau',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioSourceBadge() {
    final effectiveType = _audioType != AudioType.unknown
        ? _audioType
        : (_currentSentence.hasHumanAudio ? AudioType.humanRecording : AudioType.nativeOsTts);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveType.badgeColor.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: effectiveType.badgeColor.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            effectiveType.isHumanVoice ? Icons.record_voice_over : Icons.smart_toy_outlined,
            size: 16,
            color: effectiveType.badgeColor,
          ),
          const SizedBox(width: 6),
          Text(
            effectiveType.displayLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: effectiveType.badgeColor,
            ),
          ),
          if (_audioManager.currentSpeaker.isNotEmpty && effectiveType.isHumanVoice) ...[
            const SizedBox(width: 4),
            Text(
              '• ${_audioManager.currentSpeaker}',
              style: TextStyle(fontSize: 11, color: effectiveType.badgeColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSentenceCard() {
    final s = _currentSentence;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chinese Text with blur/hide option
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showChinese
                ? Text(
                    s.chinese,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.visibility_off_outlined, color: Colors.grey, size: 20),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => setState(() => _showChinese = true),
                        child: const Text('Hiện chữ Hán'),
                      ),
                    ],
                  ),
          ),

          if (_showChinese) const SizedBox(height: 8),

          // Pinyin with blur/hide option
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showPinyin
                ? Text(
                    s.pinyin,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                  )
                : (_showChinese
                    ? TextButton(
                        onPressed: () => setState(() => _showPinyin = true),
                        child: const Text('Hiện Pinyin', style: TextStyle(fontSize: 12)),
                      )
                    : const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizSection() {
    final correct = _currentSentence.translationVi.isNotEmpty
        ? _currentSentence.translationVi
        : _currentSentence.translationEn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn ý nghĩa đúng của câu bạn vừa nghe:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        for (final opt in _quizOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _onOptionSelected(opt),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedOption == opt
                      ? (opt == correct ? Colors.green.shade50 : Colors.red.shade50)
                      : (_selectedOption != null && opt == correct ? Colors.green.shade50 : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedOption == opt
                        ? (opt == correct ? Colors.green : Colors.red)
                        : (_selectedOption != null && opt == correct ? Colors.green : Colors.grey.shade300),
                    width: _selectedOption != null && (opt == correct || _selectedOption == opt) ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedOption == opt ? FontWeight.bold : FontWeight.normal,
                          color: _selectedOption == opt
                              ? (opt == correct ? Colors.green.shade900 : Colors.red.shade900)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (_selectedOption != null && opt == correct)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    if (_selectedOption == opt && opt != correct)
                      const Icon(Icons.cancel, color: Colors.red, size: 20),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
