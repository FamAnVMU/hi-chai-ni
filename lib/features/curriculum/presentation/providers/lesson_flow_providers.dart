import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/lesson_flow_state.dart';
import '../../domain/engine/adaptive_exercise_sampler.dart';
import '../../domain/engine/mastery_engine.dart';
import '../../../../core/database/app_database.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../roadmap/presentation/providers/roadmap_providers.dart';
import '../../../vocabulary_srs/presentation/providers/srs_providers.dart'
    show hasCompletedLessonsProvider, srsDueCountProvider;
import 'curriculum_providers.dart';

final adaptiveExerciseSamplerProvider = Provider<AdaptiveExerciseSampler>((ref) {
  return const AdaptiveExerciseSampler();
});

final masteryEngineProvider = Provider<MasteryEngine>((ref) {
  final db = AppDatabase.instance.database;
  return MasteryEngine(db);
});

class LessonFlowNotifier extends Notifier<LessonFlowState> {
  final String lessonId;

  LessonFlowNotifier(this.lessonId);

  @override
  LessonFlowState build() {
    return LessonFlowState.initial(lessonId: lessonId);
  }

  void nextStep() {
    state = state.nextStep();
  }

  void previousStep() {
    state = state.previousStep();
  }

  /// Sets or resets the active lesson step (e.g. jumping to Stage 1 or resuming a step).
  void resetToStep(LessonStep step) {
    state = state.copyWith(currentStep: step);
  }

  void recordAnswer(String questionId, dynamic answer) {
    final updated = Map<String, dynamic>.from(state.userAnswers);
    updated[questionId] = answer;
    state = state.copyWith(userAnswers: updated);
  }

  Future<ExerciseEvaluationResult> submitPractice(
    List<Map<String, dynamic>> questions, {
    int durationMs = 0,
  }) async {
    final sampler = ref.read(adaptiveExerciseSamplerProvider);
    final masteryEngine = ref.read(masteryEngineProvider);

    final mergedAnswers = Map<String, dynamic>.from(state.userAnswers);
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final qId = (q['id'] ?? 'ex_m_$i').toString();
      final embeddedAns = q['user_answer'] ?? q['selected_option'];
      if (!mergedAnswers.containsKey(qId) && embeddedAns != null) {
        mergedAnswers[qId] = embeddedAns;
      }
    }

    final result = sampler.evaluateSubmission(
      questions: questions,
      userAnswers: mergedAnswers,
    );

    final incorrectSet = result.incorrectQuestionIds.toSet();
    final enrichedQuestions = <Map<String, dynamic>>[];
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final qId = (q['id'] ?? 'ex_m_$i').toString();
      final userAns = mergedAnswers[qId];
      final isCorrect = q['is_correct'] is bool
          ? q['is_correct'] as bool
          : !incorrectSet.contains(qId) && userAns != null;
      enrichedQuestions.add({
        ...q,
        'id': qId,
        'user_answer': userAns,
        'selected_option': userAns,
        'is_correct': isCorrect,
        'score': isCorrect ? 1.0 : 0.0,
      });
    }

    // Record attempt in MasteryEngine & Learning Data Pipeline
    final masteryResult = await masteryEngine.recordLessonAttempt(
      lessonId: state.lessonId,
      scorePercent: result.scorePercent,
      questionResults: enrichedQuestions,
      durationMs: durationMs,
    );

    if (ref.mounted) {
      state = state.copyWith(
        userAnswers: mergedAnswers,
        lastScorePercent: result.scorePercent,
        isCompleted: result.isPassed,
        masteryResult: masteryResult,
      );
      _invalidateCrossTabProviders(result.isPassed);
    }

    return result;
  }

  /// Explicitly records lesson completion when learner finishes all segments
  /// (e.g. via Exit Exam completion or when masteryCheck has no standalone questions).
  ///
  /// Anti-cheating & Educational Measurement Integrity (F-05):
  /// - Case 0: If [submitPractice] already recorded [state.masteryResult], return it directly
  ///   so 6-step completion never writes duplicate activity/evidence rows.
  /// - Case 1: If empirical assessment score exists (`state.lastScorePercent != null`),
  ///   record it faithfully. Preserves exact actual score (including 0.0).
  /// - Case 2: If no mastery exam was taken (`state.lastScorePercent == null`),
  ///   use pedagogical benchmark passing threshold [defaultScorePercent] (defaulting to 0.85, never 1.0).
  /// - Case 3: Sanitize invalid numbers (NaN, infinite, negative, or > 1.0) by clamping to [0.0, 1.0].
  Future<MasteryUpdateResult> completeLesson({
    double defaultScorePercent = 0.85,
    List<Map<String, dynamic>>? questionResults,
    int durationMs = 0,
  }) async {
    if (state.masteryResult != null) {
      if (ref.mounted) {
        _invalidateCrossTabProviders(state.masteryResult!.isPassed);
      }
      return state.masteryResult!;
    }

    final masteryEngine = ref.read(masteryEngineProvider);

    double candidateScore;
    if (state.lastScorePercent != null) {
      candidateScore = state.lastScorePercent!;
    } else {
      candidateScore = defaultScorePercent;
    }

    final double scoreToRecord;
    if (candidateScore.isNaN || candidateScore.isInfinite) {
      scoreToRecord = 0.0;
    } else {
      scoreToRecord = candidateScore.clamp(0.0, 1.0);
    }

    final result = await masteryEngine.recordLessonAttempt(
      lessonId: state.lessonId,
      scorePercent: scoreToRecord,
      questionResults: questionResults,
      durationMs: durationMs,
    );

    if (ref.mounted) {
      state = state.copyWith(
        isCompleted: result.isPassed,
        lastScorePercent: scoreToRecord,
        masteryResult: result,
      );
      _invalidateCrossTabProviders(result.isPassed);
    }

    return result;
  }

  void _tryInvalidate(void Function() fn) {
    try {
      fn();
    } catch (_) {}
  }

  void _invalidateCrossTabProviders(bool isPassed) {
    _tryInvalidate(() => ref.invalidate(hasCompletedLessonsProvider));
    _tryInvalidate(() => ref.invalidate(homeDashboardProvider));
    _tryInvalidate(() => ref.invalidate(userProfileProvider));
    _tryInvalidate(() => ref.invalidate(srsDueCountProvider));
    _tryInvalidate(() => ref.invalidate(curriculumUnitsProvider));
    _tryInvalidate(() => ref.invalidate(curriculumUnitsWithLessonsProvider));
    _tryInvalidate(() => ref.invalidate(allCurriculumLessonsProvider));
    _tryInvalidate(() => ref.invalidate(curriculumLessonsProvider));
    _tryInvalidate(() => ref.invalidate(lessonDetailProvider));
    _tryInvalidate(() => ref.invalidate(adaptiveRoadmapProvider));
  }
}

final lessonFlowNotifierProvider =
    NotifierProvider.autoDispose.family<LessonFlowNotifier, LessonFlowState, String>(
  (lessonId) => LessonFlowNotifier(lessonId),
);
