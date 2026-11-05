import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/lesson_flow_state.dart';
import '../../domain/engine/adaptive_exercise_sampler.dart';
import '../../domain/engine/mastery_engine.dart';
import '../../../../core/database/app_database.dart';

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

  void recordAnswer(String questionId, dynamic answer) {
    final updated = Map<String, dynamic>.from(state.userAnswers);
    updated[questionId] = answer;
    state = state.copyWith(userAnswers: updated);
  }

  Future<ExerciseEvaluationResult> submitPractice(List<Map<String, dynamic>> questions) async {
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
    await masteryEngine.recordLessonAttempt(
      lessonId: state.lessonId,
      scorePercent: result.scorePercent,
      questionResults: enrichedQuestions,
    );

    state = state.copyWith(
      userAnswers: mergedAnswers,
      lastScorePercent: result.scorePercent,
      isCompleted: result.isPassed,
    );

    return result;
  }

  /// Explicitly records lesson completion when learner finishes all segments
  /// (e.g. via Exit Exam completion or when masteryCheck has no standalone questions).
  ///
  /// Anti-cheating & Educational Measurement Integrity (F-05):
  /// - Case 1: If empirical assessment score exists (`state.lastScorePercent != null`),
  ///   record it faithfully. Preserves exact actual score (including 0.0).
  /// - Case 2: If no mastery exam was taken (`state.lastScorePercent == null`) but
  ///   evidence exists (learner completed exercises/answers, `state.userAnswers.isNotEmpty`),
  ///   use pedagogical benchmark passing threshold [defaultScorePercent] (defaulting to 0.8, never 1.0).
  /// - Case 3: If learner has no assessment evidence (`state.lastScorePercent == null` and
  ///   `state.userAnswers.isEmpty`), strictly assign 0.0 score. Never grant virtual mastery.
  /// - Case 4: Sanitize invalid numbers (NaN, infinite, negative, or > 1.0) by clamping to [0.0, 1.0].
  Future<MasteryUpdateResult> completeLesson({
    double defaultScorePercent = 0.8,
  }) async {
    final masteryEngine = ref.read(masteryEngineProvider);

    double candidateScore;
    if (state.lastScorePercent != null) {
      // Case 1: Empirical assessment score exists. Preserve exact score.
      candidateScore = state.lastScorePercent!;
    } else if (state.userAnswers.isNotEmpty) {
      // Case 2: Engaged with lesson exercises / valid completion without standalone mastery quiz.
      candidateScore = defaultScorePercent;
    } else {
      // Case 3: Zero evidence / learner skipped straight to completion without answering.
      candidateScore = 0.0;
    }

    // Case 4: Validation & clamping against NaN, infinite, negative, or > 1.0 values.
    final double scoreToRecord;
    if (candidateScore.isNaN || candidateScore.isInfinite) {
      scoreToRecord = 0.0;
    } else {
      scoreToRecord = candidateScore.clamp(0.0, 1.0);
    }

    final result = await masteryEngine.recordLessonAttempt(
      lessonId: state.lessonId,
      scorePercent: scoreToRecord,
    );

    state = state.copyWith(
      isCompleted: result.isPassed,
      lastScorePercent: scoreToRecord,
    );

    return result;
  }
}

final lessonFlowNotifierProvider =
    NotifierProvider.family<LessonFlowNotifier, LessonFlowState, String>(
  (lessonId) => LessonFlowNotifier(lessonId),
);
