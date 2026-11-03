import 'package:flutter/material.dart';
import '../../../../core/audio/audio_models.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/audio_recorder_service.dart';
import '../../data/sentence_repository.dart';
import '../../domain/models/sentence_models.dart';
import '../../domain/services/sentence_audio_manager.dart';

/// Screen for Sentence Shadowing Practice with model audio,
/// learner voice recording, side-by-side comparison, and self-evaluation.
class SentenceShadowingScreen extends StatefulWidget {
  final SentenceItem sentence;
  final SentenceRepository repository;
  final bool autoPlay;

  const SentenceShadowingScreen({
    super.key,
    required this.sentence,
    required this.repository,
    this.autoPlay = true,
  });

  @override
  State<SentenceShadowingScreen> createState() => _SentenceShadowingScreenState();
}

class _SentenceShadowingScreenState extends State<SentenceShadowingScreen> {
  late final SentenceAudioManager _audioManager;
  late final AudioRecorderService _recorder;
  late final AudioPlayerService _userAudioPlayer;

  bool _isModelPlaying = false;
  bool _isRecording = false;
  bool _isUserAudioPlaying = false;
  String? _recordedFilePath;
  double _currentAmplitude = 0.0;
  double? _evaluatedScore;

  @override
  void initState() {
    super.initState();
    _audioManager = SentenceAudioManager();
    _recorder = DefaultAudioRecorderService();
    _userAudioPlayer = DefaultAudioPlayerService();

    _audioManager.isPlayingStream.listen((playing) {
      if (mounted) setState(() => _isModelPlaying = playing);
    });

    _recorder.statusStream.listen((status) {
      if (mounted) setState(() => _isRecording = status == AudioRecordingStatus.recording);
    });

    _recorder.amplitudeStream.listen((amp) {
      if (mounted) setState(() => _currentAmplitude = amp);
    });

    _userAudioPlayer.statusStream.listen((status) {
      if (mounted) setState(() => _isUserAudioPlaying = status == AudioPlaybackStatus.playing);
    });

    if (widget.autoPlay) {
      _playModel();
    }
  }

  @override
  void dispose() {
    _audioManager.dispose();
    _recorder.dispose();
    _userAudioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playModel() async {
    await _userAudioPlayer.stop();
    await _audioManager.playSentence(widget.sentence);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stopRecording();
      setState(() {
        _recordedFilePath = path;
      });
    } else {
      await _audioManager.stop();
      await _userAudioPlayer.stop();
      final granted = await _recorder.checkPermission();
      if (granted) {
        await _recorder.startRecording();
      }
    }
  }

  Future<void> _playUserRecording() async {
    if (_recordedFilePath == null) return;
    await _audioManager.stop();
    await _userAudioPlayer.play(_recordedFilePath!);
  }

  void _onEvaluate(double score) {
    setState(() {
      _evaluatedScore = score;
    });

    widget.repository.recordPracticeAttempt(
      sentenceId: widget.sentence.id,
      practiceType: 'shadowing',
      score: score,
      recordedAudioPath: _recordedFilePath,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã lưu kết quả Shadowing! Điểm: ${score.toInt()}%'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sentence;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện Shadowing (Nhại giọng)'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Model Sentence Card
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
                children: [
                  Text(
                    s.chinese,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.pinyin,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.translationVi.isNotEmpty ? s.translationVi : s.translationEn,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Model Playback Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              icon: Icon(_isModelPlaying ? Icons.pause : Icons.volume_up),
              label: Text(_isModelPlaying ? 'Đang phát mẫu...' : 'Nghe câu mẫu'),
              onPressed: _playModel,
            ),

            const SizedBox(height: 32),

            // Learner Recording Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isRecording ? Colors.red : Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Text(
                    _isRecording
                        ? 'Đang thu âm... Hãy đọc theo câu mẫu!'
                        : (_recordedFilePath != null ? 'Đã thu âm xong' : 'Nhấn nút mic để bắt đầu thu âm'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isRecording ? Colors.red : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Big Mic Button with waveform animation
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Colors.blueGrey.shade100,
                        shape: BoxShape.circle,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color: Colors.red.withAlpha((_currentAmplitude * 180).toInt().clamp(50, 200)),
                                  blurRadius: 16 + _currentAmplitude * 20,
                                  spreadRadius: 4 + _currentAmplitude * 10,
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: _isRecording ? Colors.white : Colors.blueGrey.shade800,
                        size: 36,
                      ),
                    ),
                  ),

                  // Side-by-side comparison (if recording exists)
                  if (_recordedFilePath != null && !_isRecording) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: Icon(_isUserAudioPlaying ? Icons.pause : Icons.play_arrow),
                          label: Text(_isUserAudioPlaying ? 'Đang phát...' : 'Nghe lại giọng bạn'),
                          onPressed: _playUserRecording,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const Text('Tự đánh giá độ tương đồng phát âm:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Rất chuẩn (100%)'),
                          selected: _evaluatedScore == 100.0,
                          onSelected: (_) => _onEvaluate(100.0),
                        ),
                        ChoiceChip(
                          label: const Text('Tương đối (75%)'),
                          selected: _evaluatedScore == 75.0,
                          onSelected: (_) => _onEvaluate(75.0),
                        ),
                        ChoiceChip(
                          label: const Text('Cần luyện lại (50%)'),
                          selected: _evaluatedScore == 50.0,
                          onSelected: (_) => _onEvaluate(50.0),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
