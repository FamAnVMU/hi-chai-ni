import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/audio/audio.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/theme.dart';
import '../../../dictionary/data/dictionary_repository.dart';
import '../../../dictionary/presentation/widgets/dictionary_detail_sheet.dart';
import '../../data/reading_repository.dart';
import '../../domain/models/reading_models.dart';
import '../widgets/reading_mode_selector.dart';
import '../widgets/reading_questions_section.dart';

/// Interactive reading screen with multi-mode display, word tap dictionary lookup,
/// slow audio player bar with speed control, comprehension questions, and AI contextual assistance.
class ReadingDetailScreen extends StatefulWidget {
  final ReadingPassage passage;
  final ReadingRepository? repository;
  final DictionaryRepository? dictionaryRepository;
  final AudioPlayerService? audioPlayer;

  const ReadingDetailScreen({
    super.key,
    required this.passage,
    this.repository,
    this.dictionaryRepository,
    this.audioPlayer,
  });

  @override
  State<ReadingDetailScreen> createState() => _ReadingDetailScreenState();
}

class _ReadingDetailScreenState extends State<ReadingDetailScreen> {
  late final ReadingRepository _repo;
  late final DictionaryRepository _dictRepo;

  ReadingDisplayMode _displayMode = ReadingDisplayMode.full;
  late final List<RubySegment> _segments;

  Timer? _readingTimer;
  int _readingTimeSeconds = 0;
  ReadingProgress? _existingProgress;
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();

  // Audio Player State
  AudioPlayerService? _audioPlayer;
  AudioPlaybackStatus _audioStatus = AudioPlaybackStatus.idle;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  StreamSubscription<AudioPlaybackStatus>? _audioStatusSub;
  StreamSubscription<Duration>? _audioPositionSub;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DefaultReadingRepository(AppDatabase.instance.database);
    _dictRepo = widget.dictionaryRepository ?? DefaultDictionaryRepository(AppDatabase.instance.database);

    _segments = widget.passage.buildRubySegments();
    _startTimer();
    _loadProgress();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayer = widget.audioPlayer ?? DefaultAudioPlayerService();
    _audioStatusSub = _audioPlayer!.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _audioStatus = status;
          if (_audioPlayer!.totalDuration > Duration.zero) {
            _totalDuration = _audioPlayer!.totalDuration;
          }
        });
      }
    });

    _audioPositionSub = _audioPlayer!.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          if (_audioPlayer!.totalDuration > Duration.zero) {
            _totalDuration = _audioPlayer!.totalDuration;
          }
        });
      }
    });
  }

  void _startTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _readingTimeSeconds++;
        });
      }
    });
  }

  Future<void> _loadProgress() async {
    final progress = await _repo.getProgress(widget.passage.id);
    if (mounted) {
      setState(() {
        _existingProgress = progress;
        if (progress != null) {
          _readingTimeSeconds = progress.readingTimeSeconds;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _saveProgress(isCompleted: _existingProgress?.isCompleted ?? false);
    _scrollController.dispose();
    _audioStatusSub?.cancel();
    _audioPositionSub?.cancel();
    _audioPlayer?.stop();
    if (widget.audioPlayer == null) {
      _audioPlayer?.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProgress({
    required bool isCompleted,
    Map<String, int>? answers,
    double? score,
  }) async {
    final currentOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    await _repo.saveReadingSession(
      passageId: widget.passage.id,
      readingTimeSeconds: _readingTimeSeconds,
      lastScrollOffset: currentOffset,
      answers: answers ?? _existingProgress?.answers ?? {},
      isCompleted: isCompleted,
      score: score ?? _existingProgress?.score,
    );
  }

  Future<void> _togglePlayAudio() async {
    final uri = widget.passage.audioUri ?? 'tts:${widget.passage.contentCn}';
    if (_audioStatus == AudioPlaybackStatus.playing) {
      await _audioPlayer?.pause();
    } else if (_audioStatus == AudioPlaybackStatus.paused) {
      await _audioPlayer?.resume();
    } else {
      await _audioPlayer?.play(uri, speed: _playbackSpeed);
    }
  }

  Future<void> _rewind5Seconds() async {
    final target = _currentPosition - const Duration(seconds: 5);
    await _audioPlayer?.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> _toggleSpeed() async {
    final newSpeed = _playbackSpeed == 1.0 ? 0.75 : 1.0;
    setState(() => _playbackSpeed = newSpeed);
    await _audioPlayer?.setPlaybackSpeed(newSpeed);
  }

  Future<void> _seekAudio(double value) async {
    await _audioPlayer?.seek(Duration(milliseconds: value.toInt()));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _handleWordTap(RubySegment segment) async {
    final hanzi = segment.text.trim();
    if (hanzi.isEmpty || segment.isPunctuation) return;

    // Search dictionary by word
    var entry = await _dictRepo.getWordByExactHanzi(hanzi);
    if (entry == null) {
      final searchList = await _dictRepo.search(hanzi, limit: 1);
      if (searchList.isNotEmpty) {
        entry = searchList.first;
      }
    }

    if (!mounted) return;

    if (entry != null) {
      DictionaryDetailSheet.show(
        context,
        entry: entry,
        repository: _dictRepo,
        contextSentence: widget.passage.contentCn,
      );
    } else {
      _showQuickLookupSheet(context, segment);
    }
  }

  void _showQuickLookupSheet(BuildContext context, RubySegment segment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlueLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      segment.text,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlueDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (segment.pinyin != null && segment.pinyin!.isNotEmpty)
                    Text(
                      segment.pinyin!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Ký tự này chưa có định nghĩa độc lập trong từ điển chính. Bạn có thể hỏi AI Tutor để giải thích nghĩa theo ngữ cảnh bài đọc.',
                style: TextStyle(color: AppColors.secondaryText, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.md),
              HiButton(
                text: 'Hỏi AI giải thích từ "${segment.text}"',
                icon: const Icon(Icons.smart_toy_outlined, size: 16),
                isFullWidth: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _askAiAboutSpecificWord(segment.text);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _askAiAboutSpecificWord(String word) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final explanation = await _repo.askAiAboutPassage(
      passageText: widget.passage.contentCn,
      userQuestion: 'Giải thích ý nghĩa và cách dùng của từ "$word" trong ngữ cảnh bài đọc này.',
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.smart_toy_outlined, color: AppColors.primaryBlueDark),
            const SizedBox(width: 8),
            Text('Giải thích từ "$word"'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(explanation, style: const TextStyle(height: 1.4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAskAi() async {
    final controller = TextEditingController();
    final question = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlueDark),
                const SizedBox(width: 8),
                Text(
                  'Hỏi AI về Bài Đọc',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Đặt câu hỏi về từ vựng, ngữ pháp hoặc văn hóa trong bài...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Giải thích cấu trúc ngữ pháp'),
                  onPressed: () => controller.text = 'Giải thích cấu trúc ngữ pháp tiêu biểu trong bài đọc này.',
                ),
                ActionChip(
                  label: const Text('Từ vựng khó cần lưu ý'),
                  onPressed: () => controller.text = 'Những từ vựng quan trọng nhất trong bài đọc này là gì?',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              icon: const Icon(Icons.send_rounded),
              label: const Text('Gửi câu hỏi'),
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );

    if (question != null && question.isNotEmpty && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final explanation = await _repo.askAiAboutPassage(
        passageText: widget.passage.contentCn,
        userQuestion: question,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlueDark),
              SizedBox(width: 8),
              Text('Phản Hồi Từ AI Tutor'),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(explanation),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final showPinyin = _displayMode == ReadingDisplayMode.full ||
        _displayMode == ReadingDisplayMode.hanziAndPinyin;
    final showTranslation = _displayMode == ReadingDisplayMode.full ||
        _displayMode == ReadingDisplayMode.hanziAndTranslation;

    final minutes = _readingTimeSeconds ~/ 60;
    final seconds = _readingTimeSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.passage.titleCn),
        actions: [
          // Reading Timer Chip
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: AppSpacing.md),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Floating Reading Mode Bar
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: AppElevation.shadowLow(theme.brightness),
                  ),
                  child: ReadingModeSelector(
                    currentMode: _displayMode,
                    onModeChanged: (mode) {
                      setState(() => _displayMode = mode);
                    },
                  ),
                ),

                // Slow Audio Player Bar (Trình phát Audio Đọc chậm)
                _buildAudioPlayerBar(theme),

                const Divider(height: 1, color: AppColors.divider),

                // Main Reading & Comprehension Scroll View
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: AppSpacing.screenPadding,
                    children: [
                      // Passage Header Metadata
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlueLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.secondaryBlue, width: 0.8),
                            ),
                            child: Text(
                              'HSK ${widget.passage.hskLevel}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlueDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Chip(
                            label: Text(widget.passage.topic),
                            visualDensity: VisualDensity.compact,
                          ),
                          const Spacer(),
                          Text(
                            '${widget.passage.wordCount} chữ Hán',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Interactive Reading Content Card
                      HiCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RubyText(
                              segments: _segments,
                              showPinyin: showPinyin,
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.md,
                              hanziStyle: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                              pinyinStyle: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onSegmentTap: _handleWordTap,
                            ),

                            // Vietnamese Translation (if enabled in current mode)
                            if (showTranslation && widget.passage.translationVi.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              const Divider(height: 1),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  const Icon(Icons.translate_rounded, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Bản dịch tiếng Việt',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.passage.translationVi,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // C3 Comprehension Questions Section
                      ReadingQuestionsSection(
                        questions: widget.passage.questions,
                        initialAnswers: _existingProgress?.answers ?? {},
                        isSubmitted: _existingProgress?.isCompleted ?? false,
                        onSubmitted: (answers, score) async {
                          await _saveProgress(
                            isCompleted: true,
                            answers: answers,
                            score: score,
                          );
                          setState(() {
                            _existingProgress = ReadingProgress(
                              id: 'updated',
                              passageId: widget.passage.id,
                              isCompleted: true,
                              readingTimeSeconds: _readingTimeSeconds,
                              answers: answers,
                              score: score,
                              updatedAt: DateTime.now(),
                            );
                          });

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã hoàn thành bài đọc! Điểm: ${score.toStringAsFixed(0)}%'),
                              backgroundColor: score >= 70 ? Colors.green : Colors.orange,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Hỏi AI về bài đọc'),
        onPressed: _handleAskAi,
      ),
    );
  }

  Widget _buildAudioPlayerBar(ThemeData theme) {
    final isPlaying = _audioStatus == AudioPlaybackStatus.playing;
    final maxMs = _totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds.toDouble() : 1.0;
    final curMs = _currentPosition.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlueLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.secondaryBlue),
      ),
      child: Row(
        children: [
          // Rewind 5s Button
          IconButton(
            icon: const Icon(Icons.replay_5_rounded),
            iconSize: 22,
            color: AppColors.primaryBlueDark,
            tooltip: 'Tua lại 5 giây',
            onPressed: _rewind5Seconds,
          ),

          // Play / Pause Button
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
            ),
            iconSize: 34,
            color: AppColors.primaryBlueDark,
            tooltip: isPlaying ? 'Tạm dừng' : 'Phát audio',
            onPressed: _togglePlayAudio,
          ),

          // Time slider & labels
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: AppColors.primaryBlueDark,
                    inactiveTrackColor: AppColors.secondaryBlue,
                    thumbColor: AppColors.primaryBlueDark,
                    overlayColor: AppColors.primaryBlueDark.withAlpha(30),
                  ),
                  child: Slider(
                    value: curMs,
                    min: 0.0,
                    max: maxMs,
                    onChanged: (val) {
                      _seekAudio(val);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlueDark,
                        ),
                      ),
                      Text(
                        _formatDuration(_totalDuration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.xs),

          // Speed Toggle: 0.75x vs 1.0x
          InkWell(
            onTap: _toggleSpeed,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _playbackSpeed == 0.75 ? AppColors.warningContainerLight : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: _playbackSpeed == 0.75 ? AppColors.warning : AppColors.primaryBlueDark,
                ),
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _playbackSpeed == 0.75 ? AppColors.warning : AppColors.primaryBlueDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
