import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/audio/audio_models.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/tts_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../hanzi_writing/presentation/screens/hanzi_writing_screen.dart';
import '../../domain/models/curriculum_models.dart';
import 'lesson_content_empty_state.dart';

class LessonVocabView extends StatefulWidget {
  final CurriculumLesson lesson;
  final LessonSegment? segment;
  final VoidCallback onNext;
  final AudioPlayerService? audioPlayerOverride;
  final TtsService? ttsServiceOverride;

  const LessonVocabView({
    super.key,
    required this.lesson,
    this.segment,
    required this.onNext,
    this.audioPlayerOverride,
    this.ttsServiceOverride,
  });

  @override
  State<LessonVocabView> createState() => _LessonVocabViewState();
}

class _LessonVocabViewState extends State<LessonVocabView> {
  late final AudioPlayerService _audioPlayer;
  late final TtsService _ttsService;
  late final bool _ownsAudioPlayer;
  late final bool _ownsTts;

  String? _currentlyPlayingHanzi;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _ownsAudioPlayer = widget.audioPlayerOverride == null;
    _ownsTts = widget.ttsServiceOverride == null;

    _audioPlayer = widget.audioPlayerOverride ?? DefaultAudioPlayerService();
    _ttsService = widget.ttsServiceOverride ?? DefaultTtsService();

    _audioPlayer.statusStream.listen((status) {
      if (mounted) {
        if (status == AudioPlaybackStatus.completed ||
            status == AudioPlaybackStatus.stopped ||
            status == AudioPlaybackStatus.error) {
          setState(() {
            _currentlyPlayingHanzi = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _audioPlayer.stop();
    _ttsService.stop();
    if (_ownsAudioPlayer) {
      _audioPlayer.dispose();
    }
    if (_ownsTts) {
      _ttsService.dispose();
    }
    super.dispose();
  }

  Future<void> _handlePlayAudio({
    required String hanzi,
    required String pinyin,
    String? audioUri,
  }) async {
    _highlightTimer?.cancel();
    await _audioPlayer.stop();
    await _ttsService.stop();

    setState(() {
      _currentlyPlayingHanzi = hanzi;
    });

    bool playedWithAudio = false;

    if (audioUri != null && audioUri.isNotEmpty) {
      final isLocalFile = !audioUri.startsWith('http') && !audioUri.startsWith('assets/');
      final fileExists = isLocalFile ? File(audioUri).existsSync() : true;

      if (fileExists) {
        try {
          await _audioPlayer.play(audioUri);
          playedWithAudio = true;
        } catch (_) {
          playedWithAudio = false;
        }
      }
    }

    if (!playedWithAudio) {
      try {
        final isZhAvailable = await _ttsService.isLanguageAvailable('zh-CN');
        if (isZhAvailable) {
          await _ttsService.speak(hanzi, language: 'zh-CN');
          if (mounted) {
            _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
              if (mounted && _currentlyPlayingHanzi == hanzi) {
                setState(() {
                  _currentlyPlayingHanzi = null;
                });
              }
            });
          }
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _currentlyPlayingHanzi = null;
        });
        HiSnackBar.showWarning(
          context,
          'Chưa có file âm thanh hoặc giọng đọc tiếng Trung cho từ "$hanzi".',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawWords = (widget.segment?.contentPayload?['words'] as List<dynamic>?) ?? [];
    final words = rawWords
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    if (words.isEmpty) {
      return LessonContentEmptyState(
        title: 'Nội dung từ vựng đang được chuẩn bị',
        message:
            'Chưa tìm thấy danh sách từ vựng cho phần học này trong cơ sở dữ liệu hiện tại.',
        icon: Icons.menu_book_outlined,
        buttonText: 'Tiếp tục bài học',
        onAction: widget.onNext,
        segmentId: widget.segment?.id,
        contentRefId: widget.segment?.contentRefId,
        segmentType: widget.segment?.segmentType,
        lessonId: widget.lesson.id,
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
        final audioUri = (w['audio_uri'] ?? w['audio_path'] ?? w['audio_url']) as String?;
        final isPlaying = _currentlyPlayingHanzi == hanzi;

        return HiCard(
          backgroundColor: AppColors.cardBackground,
          borderColor: isPlaying ? AppColors.primaryBlueDark : AppColors.border,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isPlaying ? AppColors.secondaryBlue : AppColors.primaryBlueLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPlaying
                        ? AppColors.primaryBlueDark
                        : AppColors.secondaryBlue,
                    width: isPlaying ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    hanzi,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlueDark,
                      fontFamilyFallback: const ['Noto Sans SC', 'Heiti SC'],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
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
              IconButton(
                icon: Icon(
                  isPlaying
                      ? Icons.volume_up_rounded
                      : Icons.volume_up_outlined,
                  color: isPlaying
                      ? AppColors.primaryBlue
                      : AppColors.primaryBlueDark,
                ),
                tooltip: 'Nghe phát âm chuẩn',
                onPressed: () => _handlePlayAudio(
                  hanzi: hanzi,
                  pinyin: pinyin,
                  audioUri: audioUri,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.primaryBlue,
                ),
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
