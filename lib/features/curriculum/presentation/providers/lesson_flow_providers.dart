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
  Future<MasteryUpdateResult> completeLesson({double defaultScorePercent = 1.0}) async {
    final masteryEngine = ref.read(masteryEngineProvider);
    final scoreToRecord = state.lastScorePercent ?? defaultScorePercent;

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
