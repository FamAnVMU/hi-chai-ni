import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hi_chinese/features/curriculum/presentation/providers/lesson_flow_providers.dart';
import 'package:hi_chinese/features/curriculum/domain/engine/mastery_engine.dart';
import 'package:hi_chinese/features/curriculum/domain/models/lesson_flow_state.dart';

class FakeMasteryEngine implements MasteryEngine {
  String? lastLessonId;
  double? lastScorePercent;
  int callCount = 0;
  List<Map<String, dynamic>>? lastQuestionResults;
  double? lastPassingThreshold;

  @override
  Future<MasteryUpdateResult> recordLessonAttempt({
    required String lessonId,
    required double scorePercent,
    List<Map<String, dynamic>>? questionResults,
    double passingThreshold = 0.8,
  }) async {
    lastLessonId = lessonId;
    lastScorePercent = scorePercent;
    lastQuestionResults = questionResults;
    lastPassingThreshold = passingThreshold;
    callCount++;

    final isPassed = scorePercent >= passingThreshold;
    return MasteryUpdateResult(
      lessonId: lessonId,
      isPassed: isPassed,
      scorePercent: scorePercent,
      masteryState: isPassed ? 'completed' : 'in_progress',
      totalAttempts: callCount,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getWeakLessons({double threshold = 0.70}) async {
    return [];
  }
}

void main() {
  group('F-05 Mastery Score & Anti-Cheating Assessment Integrity Tests', () {
    late FakeMasteryEngine fakeEngine;
    late ProviderContainer container;

    setUp(() {
      fakeEngine = FakeMasteryEngine();
      container = ProviderContainer(
        overrides: [
          masteryEngineProvider.overrideWithValue(fakeEngine),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Test 1 - Empirical Assessment Score Preserved: Does not overwrite actual score with default', () async {
      final lessonId = 'les_empirical_01';
      final notifier = container.read(lessonFlowNotifierProvider(lessonId).notifier);

      final questions = [
        {'id': 'q1', 'correct_answer': 'A'},
        {'id': 'q2', 'correct_answer': 'A'},
        {'id': 'q3', 'correct_answer': 'B'},
        {'id': 'q4', 'correct_answer': 'B'},
      ];
      notifier.recordAnswer('q1', 'A');
      notifier.recordAnswer('q2', 'A');
      notifier.recordAnswer('q3', 'X');
      notifier.recordAnswer('q4', 'Y');

      await notifier.submitPractice(questions);
      final stateAfterPractice = container.read(lessonFlowNotifierProvider(lessonId));
      expect(stateAfterPractice.lastScorePercent, 0.5);

      final result = await notifier.completeLesson();
      expect(result.scorePercent, 0.5);
      expect(fakeEngine.lastScorePercent, 0.5);
      expect(result.isPassed, isFalse);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).isCompleted, isFalse);
    });

    test('2. Test 2 - No Mastery Quiz: Uses pedagogical benchmark 0.85 when evidence exists, NEVER 1.0', () async {
      final lessonId = 'les_no_quiz_02';
      final notifier = container.read(lessonFlowNotifierProvider(lessonId).notifier);

      notifier.recordAnswer('practice_q1', '你好');
      notifier.recordAnswer('practice_q2', 'hǎo');

      final stateBefore = container.read(lessonFlowNotifierProvider(lessonId));
      expect(stateBefore.lastScorePercent, isNull);
      expect(stateBefore.userAnswers.isNotEmpty, isTrue);

      final result = await notifier.completeLesson();
      expect(result.scorePercent, 0.85);
      expect(fakeEngine.lastScorePercent, 0.85);
      expect(result.scorePercent, isNot(1.0));
      expect(result.isPassed, isTrue);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).isCompleted, isTrue);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).lastScorePercent, 0.85);
    });

    test('3. Test 3 - Self-Study Interactive Completion: Uses defaultScorePercent (0.85) when no standalone quiz answers exist', () async {
      final lessonId = 'les_self_study_03';
      final notifier = container.read(lessonFlowNotifierProvider(lessonId).notifier);

      final stateBefore = container.read(lessonFlowNotifierProvider(lessonId));
      expect(stateBefore.userAnswers.isEmpty, isTrue);
      expect(stateBefore.lastScorePercent, isNull);

      final result = await notifier.completeLesson();

      expect(result.scorePercent, 0.85);
      expect(fakeEngine.lastScorePercent, 0.85);
      expect(result.isPassed, isTrue);
      expect(result.masteryState, 'completed');
      expect(container.read(lessonFlowNotifierProvider(lessonId)).isCompleted, isTrue);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).lastScorePercent, 0.85);
    });

    test('4. Test 4 - Zero Score Preservation: A true 0.0 score is never treated as null or replaced by 0.85', () async {
      final lessonId = 'les_zero_score_04';
      final notifier = container.read(lessonFlowNotifierProvider(lessonId).notifier);

      final questions = [
        {'id': 'q1', 'correct_answer': 'A'},
        {'id': 'q2', 'correct_answer': 'B'},
      ];
      notifier.recordAnswer('q1', 'WRONG_1');
      notifier.recordAnswer('q2', 'WRONG_2');

      final practiceResult = await notifier.submitPractice(questions);
      expect(practiceResult.scorePercent, 0.0);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).lastScorePercent, 0.0);

      final completeResult = await notifier.completeLesson();
      expect(completeResult.scorePercent, 0.0);
      expect(fakeEngine.lastScorePercent, 0.0);
      expect(completeResult.isPassed, isFalse);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).lastScorePercent, 0.0);
    });

    test('5. Test 5 - Invalid Score Sanitization: Clamps negative, overflow, NaN, and Infinity', () async {
      final notifierA = container.read(lessonFlowNotifierProvider('les_sanitization_5a').notifier);
      notifierA.recordAnswer('q_dummy', 'ans');
      await notifierA.completeLesson(defaultScorePercent: -0.25);
      expect(fakeEngine.lastScorePercent, 0.0);

      final notifierB = container.read(lessonFlowNotifierProvider('les_sanitization_5b').notifier);
      notifierB.recordAnswer('q_dummy', 'ans');
      await notifierB.completeLesson(defaultScorePercent: 1.75);
      expect(fakeEngine.lastScorePercent, 1.0);

      final notifierC = container.read(lessonFlowNotifierProvider('les_sanitization_5c').notifier);
      notifierC.recordAnswer('q_dummy', 'ans');
      await notifierC.completeLesson(defaultScorePercent: double.nan);
      expect(fakeEngine.lastScorePercent, 0.0);

      final notifierD = container.read(lessonFlowNotifierProvider('les_sanitization_5d').notifier);
      notifierD.recordAnswer('q_dummy', 'ans');
      await notifierD.completeLesson(defaultScorePercent: double.infinity);
      expect(fakeEngine.lastScorePercent, 0.0);
    });

    test('6. Test 6 - Lesson Flow Progression & Completion Integrity: Passing unlocks, failing retains in_progress', () async {
      final lessonId = 'les_lifecycle_06';
      final notifier = container.read(lessonFlowNotifierProvider(lessonId).notifier);

      expect(container.read(lessonFlowNotifierProvider(lessonId)).currentStep, LessonStep.warmup);
      notifier.nextStep();
      expect(container.read(lessonFlowNotifierProvider(lessonId)).currentStep, LessonStep.vocabulary);
      notifier.nextStep();
      expect(container.read(lessonFlowNotifierProvider(lessonId)).currentStep, LessonStep.grammar);
      notifier.nextStep();
      expect(container.read(lessonFlowNotifierProvider(lessonId)).currentStep, LessonStep.dialogue);
      notifier.nextStep();
      expect(container.read(lessonFlowNotifierProvider(lessonId)).currentStep, LessonStep.practice);
      notifier.nextStep();
      expect(container.read(lessonFlowNotifierProvider(lessonId)).currentStep, LessonStep.masteryCheck);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).isAtLastStep, isTrue);

      final questions = [
        {'id': 'q1', 'correct_answer': 'A'},
        {'id': 'q2', 'correct_answer': 'B'},
        {'id': 'q3', 'correct_answer': 'C'},
        {'id': 'q4', 'correct_answer': 'D'},
        {'id': 'q5', 'correct_answer': 'E'},
      ];
      notifier.recordAnswer('q1', 'A');
      notifier.recordAnswer('q2', 'B');
      notifier.recordAnswer('q3', 'C');
      notifier.recordAnswer('q4', 'D');
      notifier.recordAnswer('q5', 'WRONG');

      final evalResult = await notifier.submitPractice(questions);
      expect(evalResult.scorePercent, 0.80);
      expect(evalResult.isPassed, isTrue);

      final finalResult = await notifier.completeLesson();
      expect(finalResult.isPassed, isTrue);
      expect(finalResult.masteryState, 'completed');
      expect(container.read(lessonFlowNotifierProvider(lessonId)).isCompleted, isTrue);
    });

    test('8. Standardized Lifecycle: Opening lesson always starts at Stage 1 (warmup)', () {
      final lessonId = 'les_lifecycle_01';
      final state = container.read(lessonFlowNotifierProvider(lessonId));
      expect(state.currentStep, LessonStep.warmup);
      expect(state.currentStep.stepIndex, 0);
    });

    test('9. Standardized Lifecycle: resetToStep allows programmatic step switching', () {
      final lessonId = 'les_lifecycle_02';
      final notifier = container.read(lessonFlowNotifierProvider(lessonId).notifier);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).currentStep, LessonStep.warmup);

      notifier.resetToStep(LessonStep.dialogue);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).currentStep, LessonStep.dialogue);

      notifier.resetToStep(LessonStep.warmup);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).currentStep, LessonStep.warmup);
    });

    test('10. Standardized Lifecycle: autoDispose resets state when subscriber is disposed', () async {
      final lessonId = 'les_lifecycle_03';
      final subContainer = ProviderContainer(
        overrides: [masteryEngineProvider.overrideWithValue(fakeEngine)],
      );
      final subNotifier = subContainer.read(lessonFlowNotifierProvider(lessonId).notifier);
      subNotifier.nextStep();
      subNotifier.nextStep();
      expect(subContainer.read(lessonFlowNotifierProvider(lessonId)).currentStep, LessonStep.grammar);
      subContainer.dispose();

      final newContainer = ProviderContainer(
        overrides: [masteryEngineProvider.overrideWithValue(fakeEngine)],
      );
      expect(newContainer.read(lessonFlowNotifierProvider(lessonId)).currentStep, LessonStep.warmup);
      newContainer.dispose();
    });
  });
}
