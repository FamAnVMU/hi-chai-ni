import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/practice_models.dart';
import '../providers/practice_providers.dart';
import '../widgets/exercise_card_container.dart';
import '../widgets/fill_in_the_blank_widget.dart';
import '../widgets/matching_pairs_widget.dart';
import '../widgets/multiple_choice_widget.dart';
import '../widgets/reorder_words_widget.dart';
import '../widgets/short_answer_widget.dart';
import '../widgets/true_false_or_error_widget.dart';

class PracticeSessionScreen extends ConsumerStatefulWidget {
  final String? initialSessionId;
  final String skill;
  final int hskLevel;
  final List<ExerciseDefinition>? customExercises;

  const PracticeSessionScreen({
    super.key,
    this.initialSessionId,
    this.skill = 'general',
    this.hskLevel = 1,
    this.customExercises,
  });

  @override
  ConsumerState<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends ConsumerState<PracticeSessionScreen> {
  PracticeSession? _session;
  List<ExerciseDefinition> _exercises = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Active question state
  int? _selectedOptionIndex;
  Map<String, String> _userPairs = {};
  String _filledBlank = '';
  List<String> _orderedTokens = [];
  bool? _userBool;
  String? _selectedErrorToken;
  String _textResponse = '';

  ScoringResult? _currentResult;
  DateTime _questionStartTime = DateTime.now();
  final Stopwatch _sessionStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final repo = ref.read(practiceRepositoryProvider);

    // 1. Check for custom exercises or load from DB
    List<ExerciseDefinition> exercises;
    if (widget.customExercises != null && widget.customExercises!.isNotEmpty) {
      exercises = widget.customExercises!;
    } else {
      exercises = await repo.getExercises(
        skill: widget.skill == 'general' ? null : widget.skill,
        hskLevel: widget.hskLevel,
      );
    }

    if (exercises.isEmpty) {
      // Fallback: load all active exercises
      exercises = await repo.getExercises();
    }

    // 2. Check for active session to resume
    PracticeSession? session;
    if (widget.initialSessionId != null) {
      session = await repo.getSessionById(widget.initialSessionId!);
    } else {
      session = await repo.getActiveSession(skill: widget.skill == 'general' ? null : widget.skill);
    }

    // 3. If no active session, create a new one
    if (session == null || session.isCompleted) {
      session = await repo.createSession(
        title: 'Luyện tập ${widget.skill.toUpperCase()} HSK ${widget.hskLevel}',
        skill: widget.skill,
        hskLevel: widget.hskLevel,
        exerciseIds: exercises.map((e) => e.id).toList(),
      );
    }

    if (!mounted) return;

    setState(() {
      _session = session;
      _exercises = exercises;
      _isLoading = false;
      _questionStartTime = DateTime.now();
      _sessionStopwatch.start();
    });

    _loadExistingAttemptForCurrentQuestion();
  }

  void _loadExistingAttemptForCurrentQuestion() {
    if (_session == null || _exercises.isEmpty) return;
    final currentEx = _exercises[_session!.currentIndex];

    // Check if this exercise was already answered in the session
    final existingAttempt = _session!.attempts.cast<ExerciseAttempt?>().firstWhere(
          (a) => a?.exerciseId == currentEx.id,
          orElse: () => null,
        );

    if (existingAttempt != null) {
      final ans = existingAttempt.answer;
      setState(() {
        _selectedOptionIndex = ans.selectedOptionIndex;
        _userPairs = ans.matchedPairs ?? {};
        _filledBlank = ans.filledBlank ?? '';
        _orderedTokens = ans.orderedTokens ?? [];
        _userBool = ans.userBool;
        _selectedErrorToken = ans.selectedErrorToken;
        _textResponse = ans.textResponse ?? '';
        _currentResult = existingAttempt.result;
      });
    } else {
      // Reset input for new question
      setState(() {
        _selectedOptionIndex = null;
        _userPairs = {};
        _filledBlank = '';
        _orderedTokens = [];
        _userBool = null;
        _selectedErrorToken = null;
        _textResponse = '';
        _currentResult = null;
        _questionStartTime = DateTime.now();
      });
    }
  }

  bool _canSubmit() {
    if (_isSubmitting || _currentResult != null || _exercises.isEmpty || _session == null) {
      return false;
    }
    final ex = _exercises[_session!.currentIndex];
    switch (ex.type) {
      case ExerciseType.multipleChoice:
      case ExerciseType.selectMeaningOrPinyin:
        return _selectedOptionIndex != null;
      case ExerciseType.matchingPairs:
        return _userPairs.isNotEmpty;
      case ExerciseType.fillInTheBlank:
        return _filledBlank.trim().isNotEmpty;
      case ExerciseType.reorderWords:
        return _orderedTokens.isNotEmpty;
      case ExerciseType.trueFalseOrErrorDetection:
        return ex.errorToken != null ? _selectedErrorToken != null : _userBool != null;
      case ExerciseType.shortAnswer:
        return _textResponse.trim().isNotEmpty;
    }
  }

  Future<void> _submitCurrentAnswer() async {
    if (!_canSubmit()) return;

    setState(() {
      _isSubmitting = true;
    });

    final ex = _exercises[_session!.currentIndex];
    final answer = ExerciseAnswer(
      exerciseId: ex.id,
      selectedOptionIndex: _selectedOptionIndex,
      matchedPairs: _userPairs.isNotEmpty ? _userPairs : null,
      filledBlank: _filledBlank.isNotEmpty ? _filledBlank : null,
      orderedTokens: _orderedTokens.isNotEmpty ? _orderedTokens : null,
      userBool: _userBool,
      selectedErrorToken: _selectedErrorToken,
      textResponse: _textResponse.isNotEmpty ? _textResponse : null,
    );

    final scoringEngine = ref.read(practiceScoringEngineProvider);
    final result = await scoringEngine.evaluate(definition: ex, answer: answer);

    final durationMs = DateTime.now().difference(_questionStartTime).inMilliseconds;
    final attempt = ExerciseAttempt(
      id: 'att_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: _session!.id,
      exerciseId: ex.id,
      answer: answer,
      result: result,
      durationMs: durationMs,
      createdAt: DateTime.now().toUtc(),
    );

    final repo = ref.read(practiceRepositoryProvider);
    final recorded = await repo.recordAttempt(
      sessionId: _session!.id,
      attempt: attempt,
    );

    if (!mounted) return;

    setState(() {
      _currentResult = recorded.result;
      _isSubmitting = false;
      // Append to local session attempts
      final updatedAttempts = List<ExerciseAttempt>.from(_session!.attempts)..add(recorded);
      _session = _session!.copyWith(attempts: updatedAttempts);
    });
  }

  Future<void> _goToNextQuestion() async {
    if (_session == null) return;

    final nextIndex = _session!.currentIndex + 1;
    final repo = ref.read(practiceRepositoryProvider);

    if (nextIndex >= _exercises.length) {
      // Completed session!
      _sessionStopwatch.stop();
      final completed = await repo.completeSession(
        sessionId: _session!.id,
        totalDurationMs: _sessionStopwatch.elapsedMilliseconds,
      );

      if (!mounted) return;
      setState(() {
        _session = completed;
      });
      _showCompletionDialog();
    } else {
      await repo.updateSessionProgress(_session!.id, currentIndex: nextIndex);
      if (!mounted) return;
      setState(() {
        _session = _session!.copyWith(currentIndex: nextIndex);
      });
      _loadExistingAttemptForCurrentQuestion();
    }
  }

  void _showCompletionDialog() {
    final meanScore = _session?.score ?? 0.0;
    final correctCount = _session?.attempts.where((a) => a.result.isCorrect).length ?? 0;
    final total = _exercises.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: AppColors.primaryBlueDark, size: 28),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text('Hoàn Thành Luyện Tập!'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Điểm số đạt được: ${(meanScore * 100).toInt()}%'),
              const SizedBox(height: 4),
              Text('Trả lời đúng: $correctCount / $total câu'),
              const SizedBox(height: 4),
              Text('Thời gian: ${(_sessionStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s'),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Bằng chứng học tập đã được lưu tự động vào Learning Evidence và nuôi dưỡng chuỗi hoạt động của bạn!',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Xong'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Luyện Tập')),
        body: const Center(child: Text('Không có câu hỏi luyện tập nào khả dụng.')),
      );
    }

    final currentEx = _exercises[_session!.currentIndex];
    final progress = (_session!.currentIndex + 1) / _exercises.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_session!.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.primaryBlueLight,
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryBlueDark),
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  // Question Counter Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Câu ${_session!.currentIndex + 1} / ${_exercises.length}',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primaryBlueDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Core Exercise Container & Type Component
                  ExerciseCardContainer(
                    definition: currentEx,
                    result: _currentResult,
                    child: _buildExerciseBody(currentEx),
                  ),
                ],
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  if (_currentResult == null)
                    Expanded(
                      child: HiButton(
                        text: _isSubmitting ? 'Đang chấm điểm...' : 'Kiểm tra đáp án',
                        onPressed: _canSubmit() ? _submitCurrentAnswer : null,
                        isLoading: _isSubmitting,
                      ),
                    )
                  else
                    Expanded(
                      child: HiButton(
                        text: _session!.currentIndex + 1 >= _exercises.length
                            ? 'Hoàn thành phiên'
                            : 'Câu tiếp theo',
                        onPressed: _goToNextQuestion,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseBody(ExerciseDefinition ex) {
    switch (ex.type) {
      case ExerciseType.multipleChoice:
      case ExerciseType.selectMeaningOrPinyin:
        return MultipleChoiceWidget(
          definition: ex,
          selectedIndex: _selectedOptionIndex,
          result: _currentResult,
          onSelectOption: (idx) => setState(() => _selectedOptionIndex = idx),
        );

      case ExerciseType.matchingPairs:
        return MatchingPairsWidget(
          definition: ex,
          userPairs: _userPairs,
          result: _currentResult,
          onPairsChanged: (pairs) => setState(() => _userPairs = pairs),
        );

      case ExerciseType.fillInTheBlank:
        return FillInTheBlankWidget(
          definition: ex,
          currentAnswer: _filledBlank,
          result: _currentResult,
          onAnswerChanged: (ans) => setState(() => _filledBlank = ans),
        );

      case ExerciseType.reorderWords:
        return ReorderWordsWidget(
          definition: ex,
          orderedTokens: _orderedTokens,
          result: _currentResult,
          onTokensChanged: (tokens) => setState(() => _orderedTokens = tokens),
        );

      case ExerciseType.trueFalseOrErrorDetection:
        return TrueFalseOrErrorWidget(
          definition: ex,
          userBool: _userBool,
          selectedErrorToken: _selectedErrorToken,
          result: _currentResult,
          onSelectBool: (b) => setState(() => _userBool = b),
          onSelectErrorToken: (t) => setState(() => _selectedErrorToken = t),
        );

      case ExerciseType.shortAnswer:
        return ShortAnswerWidget(
          definition: ex,
          textResponse: _textResponse,
          result: _currentResult,
          onTextChanged: (txt) => setState(() => _textResponse = txt),
        );
    }
  }
}
