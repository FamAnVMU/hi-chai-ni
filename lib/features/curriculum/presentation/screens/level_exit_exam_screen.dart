import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio_models.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/theme/theme.dart';
import '../../data/curriculum_repository.dart';
import '../providers/curriculum_providers.dart';

class LevelExitExamScreen extends ConsumerStatefulWidget {
  final String level;
  final Map<String, dynamic>? examPayload;
  final Map<String, dynamic>? examData;
  final CurriculumRepository? repository;
  final AudioPlayerService? audioPlayer;

  const LevelExitExamScreen({
    super.key,
    this.level = '1',
    this.examPayload,
    this.examData,
    this.repository,
    this.audioPlayer,
  });

  @override
  ConsumerState<LevelExitExamScreen> createState() => _LevelExitExamScreenState();
}

class _LevelExitExamScreenState extends ConsumerState<LevelExitExamScreen> {
  final Map<String, String> _userAnswers = {};
  bool _isLoading = true;
  bool _isSubmitted = false;
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
  StreamSubscription<AudioPlaybackStatus>? _playerStatusSub;

  @override
  void initState() {
    super.initState();
    _title = 'Đề Thi Tốt Nghiệp HSK ${widget.level}';
    final directPayload = widget.examData ?? widget.examPayload;
    if (directPayload != null) {
      _parseAndSetExam(directPayload);
      _isLoading = false;
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

  @override
  void dispose() {
    _playerStatusSub?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _loadExamData() async {
    // 1. Direct payload passed in widget
    final directPayload = widget.examData ?? widget.examPayload;
    if (directPayload != null) {
      _parseAndSetExam(directPayload);
      if (mounted) setState(() => _isLoading = false);
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
            if (mounted) setState(() => _isLoading = false);
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
          if (mounted) setState(() => _isLoading = false);
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
    if (payload['title'] is String) {
      _title = payload['title'] as String;
    }
    if (payload['duration_minutes'] is int) {
      _durationMinutes = payload['duration_minutes'] as int;
    }
    if (payload['passing_score'] is int) {
      _passingScore = payload['passing_score'] as int;
    }

    final parsedQuestions = <Map<String, dynamic>>[];

    dynamic examPayload = payload['exam_data_json'] ?? payload;
    if (examPayload is String) {
      try {
        examPayload = jsonDecode(examPayload);
      } catch (_) {
        examPayload = null;
      }
    }

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

    _questions = parsedQuestions;
  }

  Future<void> _submitExam() async {
    final listeningQuestions = _questions.where((q) => q['section'] == 'listening').toList();
    final readingQuestions = _questions.where((q) => q['section'] == 'reading').toList();

    int listenCorrect = 0;
    for (final q in listeningQuestions) {
      if (_userAnswers[q['id']] == q['correct_answer']) listenCorrect++;
    }
    int readCorrect = 0;
    for (final q in readingQuestions) {
      if (_userAnswers[q['id']] == q['correct_answer']) readCorrect++;
    }

    final listenPoints = listeningQuestions.isNotEmpty
        ? (listenCorrect / listeningQuestions.length * 100).round()
        : 0;
    final readPoints = readingQuestions.isNotEmpty
        ? (readCorrect / readingQuestions.length * 100).round()
        : 0;
    final totalPoints = listenPoints + readPoints;
    final isPassed = totalPoints >= _passingScore;

    setState(() {
      _listenScore = listenPoints;
      _readScore = readPoints;
      _score = totalPoints;
      _isSubmitted = true;
    });

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
          durationSeconds: _durationMinutes * 60,
          itemsCount: _questions.length,
        );
      }
    } catch (e) {
      debugPrint('[LevelExitExamScreen] Warning: Failed to record exit exam submission: $e');
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
                    const Divider(color: AppColors.divider),
                    _buildScoreRow('Phần 1: Nghe hiểu', '$_listenScore / 100 điểm'),
                    const Divider(color: AppColors.divider),
                    _buildScoreRow('Phần 2: Đọc hiểu', '$_readScore / 100 điểm'),
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
                Text(
                  '$_durationMinutes:00',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlueDark),
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
                  onPressed: _questions.isEmpty ? null : _submitExam,
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
            if (audioUri != null && audioUri.isNotEmpty) ...[
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
                onPressed: () async {
                  if (isPlaying) {
                    await _audioPlayer?.stop();
                    setState(() => _playingQuestionId = null);
                  } else {
                    setState(() => _playingQuestionId = qId);
                    try {
                      await _audioPlayer?.play(audioUri);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi phát âm thanh: $e')),
                        );
                        setState(() => _playingQuestionId = null);
                      }
                    }
                  }
                },
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
