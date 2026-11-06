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

      // Student submits quiz with 6.5 out of 10 or 65% correct
      final questions = [
        {'id': 'q1', 'correct_answer': 'A'},
        {'id': 'q2', 'correct_answer': 'A'},
        {'id': 'q3', 'correct_answer': 'B'}, // Wrong
        {'id': 'q4', 'correct_answer': 'B'}, // Wrong
      ];
      notifier.recordAnswer('q1', 'A');
      notifier.recordAnswer('q2', 'A');
      notifier.recordAnswer('q3', 'X'); // Wrong
      notifier.recordAnswer('q4', 'Y'); // Wrong

      // 2/4 = 50%
      await notifier.submitPractice(questions);
      final stateAfterPractice = container.read(lessonFlowNotifierProvider(lessonId));
      expect(stateAfterPractice.lastScorePercent, 0.5);

      // Now complete lesson: should faithfully preserve empirical 0.5 score
      final result = await notifier.completeLesson();
      expect(result.scorePercent, 0.5);
      expect(fakeEngine.lastScorePercent, 0.5);
      expect(result.isPassed, isFalse); // 0.5 < 0.8
      expect(container.read(lessonFlowNotifierProvider(lessonId)).isCompleted, isFalse);
    });

    test('2. Test 2 - No Mastery Quiz: Uses pedagogical benchmark 0.8 when evidence exists, NEVER 1.0', () async {
      final lessonId = 'les_no_quiz_02';
      final notifier = container.read(lessonFlowNotifierProvider(lessonId).notifier);

      // Learner has engaged with practice exercises / answered questions during lesson
      notifier.recordAnswer('practice_q1', '你好');
      notifier.recordAnswer('practice_q2', 'hǎo');

      // State has answers, but no mastery quiz score (lastScorePercent is null)
      final stateBefore = container.read(lessonFlowNotifierProvider(lessonId));
      expect(stateBefore.lastScorePercent, isNull);
      expect(stateBefore.userAnswers.isNotEmpty, isTrue);

      // Complete lesson without explicit score: must fall back to 0.8 (never 1.0)
      final result = await notifier.completeLesson();
      expect(result.scorePercent, 0.80);
      expect(fakeEngine.lastScorePercent, 0.80);
      expect(result.scorePercent, isNot(1.0));
      expect(result.isPassed, isTrue); // 0.8 >= 0.8
      expect(container.read(lessonFlowNotifierProvider(lessonId)).isCompleted, isTrue);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).lastScorePercent, 0.80);
    });

    test('3. Test 3 - Zero Evidence Anti-Cheating: Skipping answers records 0.0 and denies virtual mastery', () async {
      final lessonId = 'les_cheating_bypass_03';
      final notifier = container.read(lessonFlowNotifierProvider(lessonId).notifier);

      // Learner attempts to call completeLesson without answering any questions
      final stateBefore = container.read(lessonFlowNotifierProvider(lessonId));
      expect(stateBefore.userAnswers.isEmpty, isTrue);
      expect(stateBefore.lastScorePercent, isNull);

      final result = await notifier.completeLesson();

      // Must be evaluated as 0.0 score - no virtual mastery granted
      expect(result.scorePercent, 0.0);
      expect(fakeEngine.lastScorePercent, 0.0);
      expect(result.isPassed, isFalse);
      expect(result.masteryState, 'in_progress');
      expect(container.read(lessonFlowNotifierProvider(lessonId)).isCompleted, isFalse);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).lastScorePercent, 0.0);
    });

    test('4. Test 4 - Zero Score Preservation: A true 0.0 score is never treated as null or replaced by 0.8', () async {
      final lessonId = 'les_zero_score_04';
      final notifier = container.read(lessonFlowNotifierProvider(lessonId).notifier);

      // Student takes quiz and answers all questions incorrectly
      final questions = [
        {'id': 'q1', 'correct_answer': 'A'},
        {'id': 'q2', 'correct_answer': 'B'},
      ];
      notifier.recordAnswer('q1', 'WRONG_1');
      notifier.recordAnswer('q2', 'WRONG_2');

      final practiceResult = await notifier.submitPractice(questions);
      expect(practiceResult.scorePercent, 0.0);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).lastScorePercent, 0.0);

      // Complete lesson: 0.0 must be preserved and NOT fall back to 0.8
      final completeResult = await notifier.completeLesson();
      expect(completeResult.scorePercent, 0.0);
      expect(fakeEngine.lastScorePercent, 0.0);
      expect(completeResult.isPassed, isFalse);
      expect(container.read(lessonFlowNotifierProvider(lessonId)).lastScorePercent, 0.0);
    });

    test('5. Test 5 - Invalid Score Sanitization: Clamps negative, overflow, NaN, and Infinity', () async {
      // 5a. Negative score clamp
      final notifierA = container.read(lessonFlowNotifierProvider('les_sanitization_5a').notifier);
      notifierA.recordAnswer('q_dummy', 'ans');
      await notifierA.completeLesson(defaultScorePercent: -0.25);
      expect(fakeEngine.lastScorePercent, 0.0);

      // 5b. Overflow score clamp (> 1.0)
      final notifierB = container.read(lessonFlowNotifierProvider('les_sanitization_5b').notifier);
      notifierB.recordAnswer('q_dummy', 'ans');
      await notifierB.completeLesson(defaultScorePercent: 1.75);
      expect(fakeEngine.lastScorePercent, 1.0);

      // 5c. NaN handling
      final notifierC = container.read(lessonFlowNotifierProvider('les_sanitization_5c').notifier);
      notifierC.recordAnswer('q_dummy', 'ans');
      await notifierC.completeLesson(defaultScorePercent: double.nan);
      expect(fakeEngine.lastScorePercent, 0.0);

      // 5d. Infinity handling
      final notifierD = container.read(lessonFlowNotifierProvider('les_sanitization_5d').notifier);
      notifierD.recordAnswer('q_dummy', 'ans');
      await notifierD.completeLesson(defaultScorePercent: double.infinity);
      expect(fakeEngine.lastScorePercent, 0.0);
    });

    test('6. Test 6 - Lesson Flow Progression & Completion Integrity: Passing unlocks, failing retains in_progress', () async {
      final lessonId = 'les_lifecycle_06';
      final notifier = container.read(lessonFlowNotifierProvider(lessonId).notifier);

      // Step progression
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

      // Answer 4 of 5 questions correctly -> 80% passing
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
