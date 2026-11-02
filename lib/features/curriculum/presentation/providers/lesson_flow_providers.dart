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

    final result = sampler.evaluateSubmission(
      questions: questions,
      userAnswers: state.userAnswers,
    );

    // Record attempt in MasteryEngine
    await masteryEngine.recordLessonAttempt(
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

final lessonFlowNotifierProvider =
    NotifierProvider.family<LessonFlowNotifier, LessonFlowState, String>(
  (lessonId) => LessonFlowNotifier(lessonId),
);
