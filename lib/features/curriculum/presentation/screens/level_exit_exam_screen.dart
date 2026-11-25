import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio_models.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/tts_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../roadmap/presentation/providers/roadmap_providers.dart';
import '../../../vocabulary_srs/presentation/providers/srs_providers.dart';
import '../../data/curriculum_repository.dart';
import '../providers/curriculum_providers.dart';

class LevelExitExamScreen extends ConsumerStatefulWidget {
  final String level;
  final Map<String, dynamic>? examPayload;
  final Map<String, dynamic>? examData;
  final CurriculumRepository? repository;
  final AudioPlayerService? audioPlayer;
  final TtsService? ttsService;

  const LevelExitExamScreen({
    super.key,
    this.level = '1',
    this.examPayload,
    this.examData,
    this.repository,
    this.audioPlayer,
    this.ttsService,
  });

  @override
  ConsumerState<LevelExitExamScreen> createState() => _LevelExitExamScreenState();
}

class _LevelExitExamScreenState extends ConsumerState<LevelExitExamScreen> {
  final Map<String, String> _userAnswers = {};
  bool _isLoading = true;
  bool _isSubmitted = false;
  bool _isSubmitting = false;
  bool _hasListeningSection = true;
  int _score = 0;
  int _listenScore = 0;
  int _readScore = 0;

  static const int _totalScore = 200;
  int _passingScore = 120; // 60% standard
  int _durationMinutes = 35;
  String _title = '';

  List<Map<String, dynamic>> _questions = [];
  String? _playingQuestionId;
  AudioPlayerService? _audioPlayer;
  late final bool _ownsAudioPlayer;
  TtsService? _ttsService;
  bool _ownsTtsService = false;
  StreamSubscription<AudioPlaybackStatus>? _playerStatusSub;

  Timer? _countdownTimer;
  late final ValueNotifier<int> _remainingSecondsNotifier;
  final Stopwatch _examStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _title = 'Đề Thi Tốt Nghiệp HSK ${widget.level}';
    _ownsAudioPlayer = widget.audioPlayer == null;
    if (widget.ttsService != null) {
      _ttsService = widget.ttsService;
      _ownsTtsService = false;
    }
    _remainingSecondsNotifier = ValueNotifier<int>(_durationMinutes * 60);

    final directPayload = widget.examData ?? widget.examPayload;
    if (directPayload != null) {
      _parseAndSetExam(directPayload);
      _isLoading = false;
      _startExamTimerIfReady();
    }
    _initAudioPlayer();
    if (_isLoading) {
      _loadExamData();
    }
  }

  void _initAudioPlayer() {
    _audioPlayer = widget.audioPlayer ?? DefaultAudioPlayerService();
    _playerStatusSub = _audioPlayer?.statusStream.listen((status) {
      if (status == AudioPlaybackStatus.completed ||
          status == AudioPlaybackStatus.stopped ||
          status == AudioPlaybackStatus.error) {
        if (mounted) {
          setState(() => _playingQuestionId = null);
        }
      }
    });
  }

  void _startExamTimerIfReady() {
    if (_questions.isEmpty || _isSubmitted) return;
    _countdownTimer?.cancel();
    _remainingSecondsNotifier.value = _durationMinutes * 60;
    if (!_examStopwatch.isRunning) {
      _examStopwatch.start();
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isSubmitted) {
        timer.cancel();
        return;
      }
      final next = _remainingSecondsNotifier.value - 1;
      if (next <= 0) {
        _remainingSecondsNotifier.value = 0;
        timer.cancel();
        _submitExam(forceSubmit: true);
      } else {
        _remainingSecondsNotifier.value = next;
      }
    });
  }

  String _formatRemainingTime(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final mins = safe ~/ 60;
    final secs = safe % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _examStopwatch.stop();
    _remainingSecondsNotifier.dispose();
    _playerStatusSub?.cancel();
    _audioPlayer?.stop();
    if (_ownsAudioPlayer) {
      _audioPlayer?.dispose();
    }
    if (_ownsTtsService) {
      _ttsService?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExamData() async {
    // 1. Direct payload passed in widget
    final directPayload = widget.examData ?? widget.examPayload;
    if (directPayload != null) {
      _parseAndSetExam(directPayload);
      if (mounted) {
        setState(() => _isLoading = false);
        _startExamTimerIfReady();
      }
      return;
    }

    // 2. Load from SQLite via repository
    final levelNum = int.tryParse(widget.level) ?? 1;
    try {
      CurriculumRepository? repo = widget.repository;
      if (repo == null) {
        try {
          repo = ref.read(curriculumRepositoryProvider);
        } catch (_) {}
      }

      if (repo != null) {
        final dbRow = await repo.getExitExam(levelNum);
        if (dbRow != null) {
          _parseAndSetExam(dbRow);
          if (_questions.isNotEmpty) {
            if (mounted) {
              setState(() => _isLoading = false);
              _startExamTimerIfReady();
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[LevelExitExamScreen] Info: Repo load failed or not available: $e');
    }

    // 3. Fallback to asset content pack JSON
    try {
      final assetPath = 'assets/data/content_packs/hsk${widget.level}/hsk${widget.level}_pack_v1.json';
      final jsonString = await rootBundle.loadString(assetPath);
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic> && decoded['exit_exam'] is Map<String, dynamic>) {
        _parseAndSetExam(decoded['exit_exam'] as Map<String, dynamic>);
        if (_questions.isNotEmpty) {
          if (mounted) {
            setState(() => _isLoading = false);
            _startExamTimerIfReady();
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[LevelExitExamScreen] Info: Asset content pack load failed: $e');
    }

    // 4. Honest empty state: no mock fallback questions manufactured
    if (mounted) {
      setState(() {
        _questions = [];
        _isLoading = false;
      });
    }
  }

  void _parseAndSetExam(Map<String, dynamic> payload) {
    if (payload['title'] is String && (payload['title'] as String).trim().isNotEmpty) {
      _title = payload['title'] as String;
    }
    final rawDur = payload['duration_minutes'];
    if (rawDur is num && rawDur > 0) {
      _durationMinutes = rawDur.round();
    }

    dynamic examPayload = payload['exam_data_json'] ?? payload;
    if (examPayload is String) {
      try {
        examPayload = jsonDecode(examPayload);
      } catch (_) {
        examPayload = null;
      }
    }

    final rawPass = payload['passing_score'] ??
        (examPayload is Map<String, dynamic> ? examPayload['passing_score'] : null);
    if (rawPass is num) {
      _passingScore = rawPass <= 1.0
          ? (rawPass * _totalScore).round()
          : rawPass.round();
    } else {
      _passingScore = 120;
    }

    if (examPayload is Map<String, dynamic> && examPayload['duration_minutes'] is num && rawDur == null) {
      final innerDur = (examPayload['duration_minutes'] as num).round();
      if (innerDur > 0) _durationMinutes = innerDur;
    }

    final parsedQuestions = <Map<String, dynamic>>[];

    if (examPayload is Map<String, dynamic>) {
      if (examPayload['sections'] is List) {
        for (final sec in (examPayload['sections'] as List)) {
          if (sec is Map<String, dynamic>) {
            final secName = (sec['name'] ?? '').toString().toLowerCase();
            final defaultSection = secName.contains('listen') ? 'listening' : 'reading';
            final qList = sec['questions'];
            if (qList is List) {
              for (final q in qList) {
                if (q is Map<String, dynamic>) {
                  final qMap = Map<String, dynamic>.from(q);
                  qMap['section'] ??= defaultSection;
                  parsedQuestions.add(qMap);
                }
              }
            }
          }
        }
      } else if (examPayload['questions'] is List) {
        for (final q in (examPayload['questions'] as List)) {
          if (q is Map<String, dynamic>) {
            parsedQuestions.add(Map<String, dynamic>.from(q));
          }
        }
      }
    } else if (payload['questions'] is List) {
      for (final q in (payload['questions'] as List)) {
        if (q is Map<String, dynamic>) {
          parsedQuestions.add(Map<String, dynamic>.from(q));
        }
      }
    }

    final levelNum = int.tryParse(widget.level) ?? 1;
    for (int i = 0; i < parsedQuestions.length; i++) {
      final q = parsedQuestions[i];
      final rawSection = (q['section'] ?? 'reading').toString().toLowerCase();
      q['section'] = rawSection == 'listening' ? 'listening' : 'reading';
      q['id'] = (q['id'] ?? 'q_${levelNum}_$i').toString();

      final opts = ((q['options'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList();
      // Ensure correct_answer string is resolved before shuffling options
      if (q['correct_answer'] == null || q['correct_answer'].toString().isEmpty) {
        final rawIdx = q['answer_index'] ?? q['correct_index'];
        if (rawIdx is num && rawIdx.toInt() >= 0 && rawIdx.toInt() < opts.length) {
          q['correct_answer'] = opts[rawIdx.toInt()];
        }
      }
      if (opts.length > 1) {
        opts.shuffle(math.Random(levelNum * 1009 + i * 37));
      }
      q['options'] = opts;
    }

    _questions = parsedQuestions;
    _hasListeningSection = _questions.any((q) => q['section'] == 'listening');
    _remainingSecondsNotifier.value = _durationMinutes * 60;
  }

  Future<void> _submitExam({bool forceSubmit = false}) async {
    if (_isSubmitting || _isSubmitted) return;

    if (!forceSubmit && _userAnswers.isEmpty && mounted) {
      final confirmEmpty = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chưa trả lời câu hỏi nào'),
          content: const Text(
            'Bạn chưa chọn đáp án nào. Nếu nộp bài ngay bây giờ, kết quả sẽ là 0/200 điểm và chưa đạt. Bạn muốn nộp chứ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Tiếp tục làm'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Nộp bài (0 điểm)'),
            ),
          ],
        ),
      );
      if (confirmEmpty != true || !mounted) return;
    }

    setState(() => _isSubmitting = true);
    _countdownTimer?.cancel();
    _examStopwatch.stop();

    try {
      final listeningQuestions = _questions.where((q) => q['section'] == 'listening').toList();
      final readingQuestions = _questions.where((q) => q['section'] != 'listening').toList();

      int listenCorrect = 0;
      for (final q in listeningQuestions) {
        final qId = q['id'].toString();
        final correctAns = (q['correct_answer'] ?? '').toString();
        if (correctAns.isNotEmpty && _userAnswers[qId] == correctAns) {
          listenCorrect++;
        }
      }
      int readCorrect = 0;
      for (final q in readingQuestions) {
        final qId = q['id'].toString();
        final correctAns = (q['correct_answer'] ?? '').toString();
        if (correctAns.isNotEmpty && _userAnswers[qId] == correctAns) {
          readCorrect++;
        }
      }

      int listenPoints = 0;
      int readPoints = 0;
      if (listeningQuestions.isNotEmpty && readingQuestions.isNotEmpty) {
        listenPoints = (listenCorrect / listeningQuestions.length * (_totalScore / 2)).round();
        readPoints = (readCorrect / readingQuestions.length * (_totalScore / 2)).round();
      } else if (readingQuestions.isNotEmpty) {
        readPoints = (readCorrect / readingQuestions.length * _totalScore).round();
      } else if (listeningQuestions.isNotEmpty) {
        listenPoints = (listenCorrect / listeningQuestions.length * _totalScore).round();
      }

      final totalPoints = listenPoints + readPoints;
      final isPassed = totalPoints >= _passingScore;
      final elapsedSeconds = _examStopwatch.elapsed.inSeconds.clamp(1, _durationMinutes * 60);

      if (mounted) {
        setState(() {
          _hasListeningSection = listeningQuestions.isNotEmpty;
          _listenScore = listenPoints;
          _readScore = readPoints;
          _score = totalPoints;
          _isSubmitted = true;
        });
      }

      // Persist to database atomically
      try {
        CurriculumRepository? repo = widget.repository;
        if (repo == null) {
          try {
            repo = ref.read(curriculumRepositoryProvider);
          } catch (_) {}
        }

        if (repo != null) {
          final levelNum = int.tryParse(widget.level) ?? 1;
          await repo.recordExitExamSubmission(
            hskLevel: levelNum,
            score: totalPoints,
            totalScore: _totalScore,
            listenScore: listenPoints,
            readScore: readPoints,
            isPassed: isPassed,
            durationSeconds: elapsedSeconds,
            itemsCount: _questions.length,
          );
          _invalidateCrossTabProviders();
        }
      } catch (e) {
        debugPrint('[LevelExitExamScreen] Warning: Failed to record exit exam submission: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _invalidateCrossTabProviders() {
    try {
      ref.invalidate(userProfileProvider);
      ref.invalidate(homeDashboardProvider);
      ref.invalidate(curriculumUnitsProvider);
      ref.invalidate(curriculumUnitsWithLessonsProvider);
      ref.invalidate(allCurriculumLessonsProvider);
      ref.invalidate(adaptiveRoadmapProvider);
      ref.invalidate(srsDueCountProvider);
      ref.invalidate(exitExamProvider);
    } catch (_) {}
  }

  Future<void> _playQuestionAudio(Map<String, dynamic> q) async {
    final qId = (q['id'] ?? '').toString();
    final audioUri = (q['audio_uri'] ?? '').toString().trim();

    if (_playingQuestionId == qId) {
      await _audioPlayer?.stop();
      await _ttsService?.stop();
      if (mounted) setState(() => _playingQuestionId = null);
      return;
    }

    setState(() => _playingQuestionId = qId);

    bool playedAudio = false;
    if (audioUri.isNotEmpty && _audioPlayer != null) {
      try {
        await _audioPlayer!.play(audioUri);
        playedAudio = true;
      } catch (_) {
        playedAudio = false;
      }
    }

    if (!playedAudio) {
      final spokenText = (q['audio_text'] ??
              q['transcript'] ??
              q['prompt'] ??
              q['correct_answer'] ??
              '')
          .toString()
          .trim();
      if (spokenText.isNotEmpty) {
        try {
          _ttsService ??= DefaultTtsService();
          _ownsTtsService = widget.ttsService == null;
          await _ttsService!.speak(spokenText, language: 'zh-CN');
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _playingQuestionId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final listeningQuestions = _questions.where((q) => q['section'] == 'listening').toList();
    final readingQuestions = _questions.where((q) => q['section'] == 'reading').toList();

    if (_isSubmitted) {
      final isPassed = _score >= _passingScore;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Kết Quả Thi'),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: isPassed ? AppColors.successContainerLight : AppColors.errorContainerLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPassed ? Icons.workspace_premium_rounded : Icons.highlight_off_rounded,
                    size: 72,
                    color: isPassed ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Kết quả thi tốt nghiệp HSK ${widget.level}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPassed ? AppColors.success : AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isPassed ? 'XUẤT SẮC ĐẠT CHUẨN ĐẦU RA!' : 'CHƯA ĐẠT ĐIỂM CHUẨN',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              HiCard(
                backgroundColor: AppColors.cardBackground,
                borderColor: AppColors.border,
                child: Column(
                  children: [
                    _buildScoreRow('Tổng điểm đạt được', '$_score / $_totalScore điểm', isHighlight: true, isPassed: isPassed),
                    if (_hasListeningSection) ...[
                      const Divider(color: AppColors.divider),
                      _buildScoreRow('Phần 1: Nghe hiểu', '$_listenScore / 100 điểm'),
                      const Divider(color: AppColors.divider),
                      _buildScoreRow('Phần 2: Đọc hiểu', '$_readScore / 100 điểm'),
                    ] else ...[
                      const Divider(color: AppColors.divider),
                      _buildScoreRow('Phần Đọc hiểu & Từ vựng', '$_readScore / $_totalScore điểm'),
                    ],
                    const Divider(color: AppColors.divider),
                    _buildScoreRow('Điểm chuẩn đạt HSK ${widget.level}', '$_passingScore điểm'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Detailed question review
              Text(
                'Chi Tiết Từng Câu Hỏi (${_questions.length} câu)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._questions.map((q) => _buildReviewCard(q)),

              const SizedBox(height: AppSpacing.xl),
              HiButton(
                text: 'Trở về trang giáo trình',
                isFullWidth: true,
                variant: HiButtonVariant.primary,
                size: HiButtonSize.lg,
                onPressed: () => Navigator.of(context).pop(isPassed),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlueLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.primaryBlueDark),
                const SizedBox(width: 4),
                ValueListenableBuilder<int>(
                  valueListenable: _remainingSecondsNotifier,
                  builder: (_, secs, _) {
                    return Text(
                      _formatRemainingTime(secs),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: secs < 60 ? AppColors.error : AppColors.primaryBlueDark,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: _questions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.assignment_late_outlined, size: 56, color: AppColors.mutedText),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Chưa có dữ liệu đề thi tốt nghiệp cho HSK ${widget.level}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Vui lòng tải hoặc cập nhật Content Pack HSK ${widget.level} trong kho dữ liệu để bắt đầu bài thi chính thức.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: AppSpacing.screenPadding,
              children: [
                // Section 1: Listening
                if (listeningQuestions.isNotEmpty) ...[
                  Text(
                    'Phần 1: Nghe hiểu',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...listeningQuestions.map((q) => _buildQuestionCard(q)),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Section 2: Reading
                if (readingQuestions.isNotEmpty) ...[
                  Text(
                    'Phần 2: Đọc hiểu',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...readingQuestions.map((q) => _buildQuestionCard(q)),
                  const SizedBox(height: AppSpacing.lg),
                ],

                const SizedBox(height: AppSpacing.md),
                HiButton(
                  text: 'Nộp bài thi',
                  isFullWidth: true,
                  size: HiButtonSize.lg,
                  isLoading: _isSubmitting,
                  onPressed: (_questions.isEmpty || _isSubmitting) ? null : () => _submitExam(),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }

  Widget _buildScoreRow(String label, String value, {bool isHighlight = false, bool isPassed = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlight ? 16 : 14,
              color: AppColors.primaryText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isHighlight ? 18 : 14,
              color: isHighlight
                  ? (isPassed ? AppColors.success : AppColors.error)
                  : AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q) {
    final theme = Theme.of(context);
    final qId = (q['id'] ?? '').toString();
    final prompt = (q['prompt'] ?? '') as String;
    final audioUri = q['audio_uri'] as String?;
    final options = ((q['options'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList();
    final selected = _userAnswers[qId];
    final isPlaying = _playingQuestionId == qId;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: HiCard(
        backgroundColor: AppColors.cardBackground,
        borderColor: AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prompt,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            if (q['section'] == 'listening' || (audioUri != null && audioUri.isNotEmpty)) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                  size: 18,
                  color: AppColors.primaryBlueDark,
                ),
                label: Text(
                  isPlaying ? 'Đang phát âm thanh...' : 'Nghe audio câu hỏi',
                  style: const TextStyle(fontSize: 13, color: AppColors.primaryBlueDark),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryBlueDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _playQuestionAudio(q),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            ...options.map((opt) {
              final isChosen = selected == opt;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _userAnswers[qId] = opt;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isChosen ? AppColors.primaryBlueLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isChosen ? AppColors.primaryBlueDark : AppColors.border,
                        width: isChosen ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isChosen ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 18,
                          color: isChosen ? AppColors.primaryBlueDark : AppColors.mutedText,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            opt,
                            style: TextStyle(
                              color: isChosen ? AppColors.primaryBlueDark : AppColors.primaryText,
                              fontWeight: isChosen ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> q) {
    final theme = Theme.of(context);
    final qId = (q['id'] ?? '').toString();
    final prompt = (q['prompt'] ?? '') as String;
    final correctAnswer = (q['correct_answer'] ?? '').toString();
    final userAnswer = _userAnswers[qId];
    final isCorrect = userAnswer == correctAnswer;
    final explanation = (q['explanation'] ?? q['explanationVi'] ?? '') as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: HiCard(
        backgroundColor: isCorrect ? AppColors.cardBackground : AppColors.errorContainerLight.withAlpha(50),
        borderColor: isCorrect ? AppColors.success.withAlpha(120) : AppColors.error.withAlpha(120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isCorrect ? AppColors.success : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prompt,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Đáp án của bạn: ${userAnswer ?? "(Chưa chọn)"}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isCorrect ? AppColors.success : AppColors.error,
              ),
            ),
            if (!isCorrect) ...[
              const SizedBox(height: 2),
              Text(
                'Đáp án đúng: $correctAnswer',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
            if (explanation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Giải thích: $explanation',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
