import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/lesson_flow_state.dart';
import '../domain/engine/adaptive_exercise_sampler.dart';
import '../domain/engine/mastery_engine.dart';
import '../../../../core/database/app_database.dart';

final adaptiveExerciseSamplerProvider = Provider<AdaptiveExerciseSampler>((ref) {
  return const AdaptiveExerciseSampler();
});

final masteryEngineProvider = Provider<MasteryEngine>((ref) {
  final db = AppDatabase.instance.database;
  return MasteryEngine(db);
});

class LessonFlowNotifier extends StateNotifier<LessonFlowState> {
  final AdaptiveExerciseSampler _sampler;
  final MasteryEngine _masteryEngine;

  LessonFlowNotifier({
    required String lessonId,
    required AdaptiveExerciseSampler sampler,
    required MasteryEngine masteryEngine,
  })  : _sampler = sampler,
        _masteryEngine = masteryEngine,
        super(LessonFlowState.initial(lessonId: lessonId));

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
    final result = _sampler.evaluateSubmission(
      questions: questions,
      userAnswers: state.userAnswers,
    );

    // Record attempt in MasteryEngine
    await _masteryEngine.recordLessonAttempt(
      lessonId: state.lessonId,
      scorePercent: result.scorePercent,
    );

    state = state.copyWith(
      lastScorePercent: result.scorePercent,
      isCompleted: result.isPassed,
    );

    return result;
  }
}

final lessonFlowNotifierProvider = StateNotifierProvider.family<LessonFlowNotifier, LessonFlowState, String>(
  (ref, lessonId) {
    final sampler = ref.watch(adaptiveExerciseSamplerProvider);
    final masteryEngine = ref.watch(masteryEngineProvider);
    return LessonFlowNotifier(
      lessonId: lessonId,
      sampler: sampler,
      masteryEngine: masteryEngine,
    );
  },
);
