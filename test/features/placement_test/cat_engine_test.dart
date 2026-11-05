import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/placement_test/domain/engine/cat_blueprint.dart';
import 'package:hi_chinese/features/placement_test/domain/engine/cat_engine.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_assessment_result.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_item.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_session_state.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_skill.dart';

void main() {
  const engine = CatEngine();

  group('CatEngine IRT & Adaptive Routing Tests', () {
    test('1. 2PL IRT Probability and Fisher Information calculation', () {
      // When theta equals difficulty, probability is exactly 0.5
      final p = CatEngine.calculateProbability(0.0, 0.0, 1.0);
      expect(p, closeTo(0.5, 0.001));

      // Information is maximum at theta == b: a^2 * 0.5 * 0.5 = 0.25
      final info = CatEngine.calculateInformation(0.0, 0.0, 1.0);
      expect(info, closeTo(0.25, 0.001));

      // Higher ability has higher probability
      final pHigh = CatEngine.calculateProbability(2.0, 0.0, 1.0);
      expect(pHigh, greaterThan(0.8));

      // Lower ability has lower probability
      final pLow = CatEngine.calculateProbability(-2.0, 0.0, 1.0);
      expect(pLow, lessThan(0.2));
    });

    test('2. Beginner Profile simulation: consecutive wrong answers drop theta and trigger early exit', () {
      var state = CatSessionState.initial('SESSION_BEGINNER');
      state = state.copyWith(activeItem: engine.selectInitialItem(CatSkill.vocabulary));

      // Answer 3 consecutive vocabulary questions incorrectly
      for (int i = 0; i < 3; i++) {
        expect(state.activeItem, isNotNull);
        final initialTheta = state.currentTheta;

        state = engine.processTurn(
          currentState: state,
          userAnswer: 3, // Wrong answer (Option D)
          latencyMs: 1200,
        );

        // Theta must decrease or stay bounded at floor
        expect(state.currentTheta, lessThanOrEqualTo(initialTheta));
      }

      // After 3 consecutive wrong answers on low difficulty, it terminates vocabulary early and advances to grammar
      expect(state.currentSkill, isNot(CatSkill.vocabulary));
    });

    test('3. Advanced Profile simulation: correct answers increase theta and adapt to harder items', () {
      var state = CatSessionState.initial('SESSION_ADVANCED');
      state = state.copyWith(activeItem: engine.selectInitialItem(CatSkill.vocabulary));

      final initialTheta = state.currentTheta;

      // Answer first item correctly
      state = engine.processTurn(
        currentState: state,
        userAnswer: 0, // Correct answer (Option A)
        latencyMs: 1000,
      );

      // Theta must increase
      expect(state.currentTheta, greaterThan(initialTheta));

      // Next item difficulty should be higher or equal to previous
      if (state.activeItem != null) {
        expect(state.activeItem!.difficulty, greaterThanOrEqualTo(-1.8));
      }
    });

    test('4. Skipped skill test: skipped skill is marked unassessed and NEVER scored as zero', () {
      var state = CatSessionState.initial('SESSION_SKIP_SKILL');
      state = state.copyWith(
        currentSkill: CatSkill.speaking,
        activeItem: engine.selectInitialItem(CatSkill.speaking),
      );

      // Learner skips speaking question
      state = engine.processTurn(
        currentState: state,
        userAnswer: null,
        latencyMs: 100,
        isSkipped: true,
      );

      final result = engine.generateAssessmentResult(
        sessionId: state.sessionId,
        overallTheta: -0.5,
        overallStandardError: 0.5,
        responses: state.responses,
        completedAt: DateTime.now().toUtc(),
      );

      final speakingScore = result.skillScores[CatSkill.speaking]!;
      expect(speakingScore.isAssessed, isFalse);
      expect(speakingScore.confidenceLabel, 'Chưa đánh giá');
      expect(speakingScore.accuracyRate, isNull); // NOT 0.0!
    });

    test('5. Writing sub-metrics test: separates character recognition, pinyin input, and stroke order', () {
      final responses = [
        CatResponseRecord(
          itemId: 'WRIT_001',
          skill: CatSkill.writing,
          writingSubType: WritingSubType.characterRecognition,
          itemDifficulty: -1.5,
          hskTarget: 1,
          isCorrect: true,
          timestamp: DateTime.now().toUtc(),
        ),
        CatResponseRecord(
          itemId: 'WRIT_002',
          skill: CatSkill.writing,
          writingSubType: WritingSubType.pinyinTranscription,
          itemDifficulty: -0.7,
          hskTarget: 2,
          isCorrect: false,
          timestamp: DateTime.now().toUtc(),
        ),
        CatResponseRecord(
          itemId: 'WRIT_003',
          skill: CatSkill.writing,
          writingSubType: WritingSubType.strokeOrderWriting,
          itemDifficulty: -1.1,
          hskTarget: 1,
          isCorrect: true,
          timestamp: DateTime.now().toUtc(),
        ),
      ];

      final result = engine.generateAssessmentResult(
        sessionId: 'WRITING_TEST',
        overallTheta: 0.0,
        overallStandardError: 0.4,
        responses: responses,
        completedAt: DateTime.now().toUtc(),
      );

      final writingScore = result.skillScores[CatSkill.writing]!;
      expect(writingScore.isAssessed, isTrue);
      expect(writingScore.subMetrics['character_recognition_accuracy'], 1.0);
      expect(writingScore.subMetrics['pinyin_transcription_accuracy'], 0.0);
      expect(writingScore.subMetrics['stroke_order_accuracy'], 1.0);
    });

    test('6. Knowledge gaps collection: incorrect answers populate targeted remediation items', () {
      final responses = [
        CatResponseRecord(
          itemId: 'GRAM_003', // Ba sentence question
          skill: CatSkill.grammar,
          itemDifficulty: 0.7,
          hskTarget: 3,
          isCorrect: false,
          timestamp: DateTime.now().toUtc(),
        ),
      ];

      final result = engine.generateAssessmentResult(
        sessionId: 'GAP_TEST',
        overallTheta: 0.0,
        overallStandardError: 0.4,
        responses: responses,
        completedAt: DateTime.now().toUtc(),
      );

      expect(result.knowledgeGaps, isNotEmpty);
      expect(result.knowledgeGaps.first.tag, 'grammar_ba_construction');
      expect(result.knowledgeGaps.first.suggestedRemediationVi, contains('Cấu trúc câu chữ 把'));
    });

    test('7. Mandatory legal disclaimer is always embedded and non-empty', () {
      expect(CatAssessmentResult.disclaimerVi, isNotEmpty);
      expect(CatAssessmentResult.disclaimerVi, contains('ước lượng tham chiếu nội bộ'));
      expect(CatAssessmentResult.disclaimerVi, contains('không có giá trị thay thế chứng chỉ HSK chính thức'));
    });

    test('8. CatItemType.speakingPrompt handles boolean, numerical, map, and transcript answers in checkAnswer', () {
      const speakingItem = CatItem(
        id: 'SPK_TEST_01',
        skill: CatSkill.speaking,
        type: CatItemType.speakingPrompt,
        speakingMode: SpeakingEvaluationMode.acousticAudioAnalyzed,
        difficulty: -1.0,
        discrimination: 1.2,
        hskLevel: 1,
        prompt: 'Đọc: 你好 (nǐ hǎo)',
        correctAnswerText: '你好',
        explanationVi: 'Biến điệu thanh 3',
        knowledgeGapTag: 'speaking_tone3',
        knowledgeGapLabelVi: 'Thanh điệu',
      );

      // Direct boolean evaluation
      expect(speakingItem.checkAnswer(true), isTrue);
      expect(speakingItem.checkAnswer(false), isFalse);

      // Numerical score on 0.0-1.0 scale (threshold: 0.60)
      expect(speakingItem.checkAnswer(0.85), isTrue);
      expect(speakingItem.checkAnswer(0.60), isTrue);
      expect(speakingItem.checkAnswer(0.55), isFalse);

      // Numerical score on 0-100 scale (threshold: 60)
      expect(speakingItem.checkAnswer(85), isTrue);
      expect(speakingItem.checkAnswer(60.0), isTrue);
      expect(speakingItem.checkAnswer(45), isFalse);

      // Map evaluation payload
      expect(speakingItem.checkAnswer({'isCorrect': true}), isTrue);
      expect(speakingItem.checkAnswer({'isCorrect': false}), isFalse);
      expect(speakingItem.checkAnswer({'score': 0.75}), isTrue);
      expect(speakingItem.checkAnswer({'overallScore': 80}), isTrue);
      expect(speakingItem.checkAnswer({'accuracyRate': 0.40}), isFalse);

      // String transcript and indicators
      expect(speakingItem.checkAnswer('passed'), isTrue);
      expect(speakingItem.checkAnswer('speech_sample_recorded'), isNull);
      expect(speakingItem.checkAnswer({'status': 'pending_review'}), isNull);
      expect(speakingItem.checkAnswer('你好'), isTrue);
      expect(speakingItem.checkAnswer('nǐ hǎo'), isFalse); // Non-matching text
      expect(speakingItem.checkAnswer(null), isFalse);
    });

    test('9. CatEngine processTurn evaluates speakingPrompt turns properly', () {
      const speakingItem = CatItem(
        id: 'SPK_TEST_02',
        skill: CatSkill.speaking,
        type: CatItemType.speakingPrompt,
        speakingMode: SpeakingEvaluationMode.acousticAudioAnalyzed,
        difficulty: -0.5,
        discrimination: 1.0,
        hskLevel: 1,
        prompt: 'Đọc: 谢谢',
        correctAnswerText: '谢谢',
        explanationVi: 'Phát âm thanh nhẹ',
        knowledgeGapTag: 'speaking_neutral_tone',
        knowledgeGapLabelVi: 'Thanh nhẹ',
      );

      var state = CatSessionState.initial('SESSION_SPEAKING');
      state = state.copyWith(activeItem: speakingItem, currentSkill: CatSkill.speaking);

      final initialTheta = state.currentTheta;

      // Unassessed sample recording without acoustic score -> marked pending review (isCorrect == null)
      final recordedState = engine.processTurn(
        currentState: state,
        userAnswer: 'speech_sample_recorded',
        latencyMs: 1500,
      );
      expect(recordedState.responses.last.isCorrect, isNull);
      expect(recordedState.currentTheta, equals(initialTheta));

      final assessmentPending = engine.generateAssessmentResult(
        sessionId: recordedState.sessionId,
        overallTheta: recordedState.currentTheta,
        overallStandardError: recordedState.currentStandardError,
        responses: recordedState.responses,
        completedAt: DateTime.now().toUtc(),
      );
      expect(assessmentPending.skillScores[CatSkill.speaking]!.isAssessed, isFalse);
      expect(assessmentPending.skillScores[CatSkill.speaking]!.subMetrics['reason'], 'Bản ghi âm đang chờ kiểm tra');

      // Pass turn with 0.85 pronunciation score
      final nextState = engine.processTurn(
        currentState: state,
        userAnswer: 0.85,
        latencyMs: 1500,
      );

      expect(nextState.responses.last.isCorrect, isTrue);
      expect(nextState.currentTheta, greaterThan(initialTheta));
    });

    test('10. Zero-Chinese beginner CAT session calibrates in [-3.0, -1.0], runs 5-8 questions, and yields Acoustic Sensitivity & Pictographic Intuition', () {
      final initialItem = engine.selectInitialItem(CatSkill.listening, targetTheta: -2.0);
      expect(initialItem, isNotNull);
      expect(initialItem!.difficulty, inInclusiveRange(-3.0, -1.0));

      var state = CatSessionState.initial(
        'SESSION_ZERO_CHINESE',
        initialSkill: CatSkill.listening,
        initialItem: initialItem,
        initialTheta: -2.0,
        blueprintVersion: 'v1.0-beginner',
      );

      expect(state.isBeginnerMode, isTrue);

      int iterations = 0;
      while (!state.isCompleted && iterations < 15) {
        iterations++;
        final currentItem = state.activeItem;
        expect(currentItem, isNotNull);

        // Simulate learner answering with correct option
        state = engine.processTurn(
          currentState: state,
          userAnswer: currentItem!.correctOptionIndex ?? 0,
          latencyMs: 1200,
        );
      }

      expect(state.isCompleted, isTrue);
      expect(state.responses.length, inInclusiveRange(5, 8));

      final result = state.result;
      expect(result, isNotNull);
      expect(result!.recommendedHskLevel, 1);
      expect(result.blueprintVersion, 'v1.0-beginner');
      expect(result.hasBeginnerDiagnostics, isTrue);
      expect(result.acousticSensitivityScore, isNotNull);
      expect(result.acousticSensitivityScore!, greaterThanOrEqualTo(0.5));
      expect(result.pictographicIntuitionScore, isNotNull);
      expect(result.pictographicIntuitionScore!, greaterThanOrEqualTo(0.5));
    });

    test('11 (F-02 Test 1): Does NOT terminate at minTotalItems (12 items) when skills remain to be assessed', () {
      var state = CatSessionState.initial('SESSION_MIN_ITEMS_CHECK');
      state = state.copyWith(activeItem: engine.selectInitialItem(CatSkill.vocabulary));

      // Simulate answers through Vocabulary, Grammar, and Reading
      // In CatItemBank: Vocab (5 items), Grammar (4 items), Reading (3 items) = 12 items.
      int count = 0;
      while (!state.isCompleted && count < 12) {
        final item = state.activeItem;
        expect(item, isNotNull);
        count++;

        state = engine.processTurn(
          currentState: state,
          userAnswer: item!.correctOptionIndex ?? 0,
          latencyMs: 1000,
        );
      }

      // At exactly 12 items (which equals minTotalItems = 12):
      expect(state.responses.length, equals(12));
      expect(
        state.isCompleted,
        isFalse,
        reason: 'Test MUST NOT complete at minTotalItems when Listening, Writing, and Speaking remain unassessed (F-02)',
      );
      expect(state.status, equals('in_progress'));
      expect(state.activeItem, isNotNull);
      expect(state.currentSkill, equals(CatSkill.listening), reason: 'Should have advanced to Listening');
    });

    test('12 (F-02 Test 2): Evaluates all 6 skills in sequence without skipping Listening, Writing, or Speaking', () {
      var state = CatSessionState.initial('SESSION_SIX_SKILLS');
      state = state.copyWith(activeItem: engine.selectInitialItem(CatSkill.vocabulary));

      int turnLimit = 0;
      while (!state.isCompleted && turnLimit < 40) {
        turnLimit++;
        final item = state.activeItem;
        if (item == null) break;

        dynamic answer;
        if (item.type == CatItemType.speakingPrompt) {
          answer = true;
        } else if (item.correctOptionIndex != null) {
          answer = item.correctOptionIndex;
        } else if (item.correctAnswerText != null) {
          answer = item.correctAnswerText;
        } else {
          answer = 0;
        }

        state = engine.processTurn(
          currentState: state,
          userAnswer: answer,
          latencyMs: 1200,
        );
      }

      expect(state.isCompleted, isTrue);
      final assessedSkills = state.responses.map((r) => r.skill).toSet();
      expect(
        assessedSkills,
        containsAll([
          CatSkill.vocabulary,
          CatSkill.grammar,
          CatSkill.reading,
          CatSkill.listening,
          CatSkill.writing,
          CatSkill.speaking,
        ]),
        reason: 'All 6 skills must have recorded responses',
      );

      final result = state.result;
      expect(result, isNotNull);
      expect(result!.skillScores[CatSkill.vocabulary]!.isAssessed, isTrue);
      expect(result.skillScores[CatSkill.grammar]!.isAssessed, isTrue);
      expect(result.skillScores[CatSkill.reading]!.isAssessed, isTrue);
      expect(result.skillScores[CatSkill.listening]!.isAssessed, isTrue);
      expect(result.skillScores[CatSkill.writing]!.isAssessed, isTrue);
      expect(result.skillScores[CatSkill.speaking]!.isAssessed, isTrue);
    });

    test('13 (F-02 Test 3): Terminates and synthesizes completed result when no next skill remains in blueprint sequence', () {
      // Create engine with a custom 2-skill blueprint
      const twoSkillBlueprint = CatBlueprint(
        minTotalItems: 2,
        maxTotalItems: 10,
        minItemsPerSkill: 1,
        maxItemsPerSkill: 2,
        skillSequence: [CatSkill.vocabulary, CatSkill.grammar],
      );
      const customEngine = CatEngine(blueprint: twoSkillBlueprint);

      var state = CatSessionState.initial('SESSION_END_OF_SKILLS');
      state = state.copyWith(activeItem: customEngine.selectInitialItem(CatSkill.vocabulary));

      int count = 0;
      while (!state.isCompleted && count < 10) {
        count++;
        final item = state.activeItem;
        if (item == null) break;

        state = customEngine.processTurn(
          currentState: state,
          userAnswer: item.correctOptionIndex ?? 0,
          latencyMs: 1000,
        );
      }

      expect(state.isCompleted, isTrue);
      expect(state.status, 'completed');
      expect(state.activeItem, isNull);
      expect(state.result, isNotNull);
      expect(state.result!.skillScores[CatSkill.vocabulary]!.isAssessed, isTrue);
      expect(state.result!.skillScores[CatSkill.grammar]!.isAssessed, isTrue);
      expect(state.result!.skillScores[CatSkill.reading]!.isAssessed, isFalse);
    });

    test('14 (F-02 Test 4): Terminates immediately when total responses hit maxTotalItems', () {
      const tightBlueprint = CatBlueprint(
        minTotalItems: 4,
        maxTotalItems: 6, // Hard fatigue limit set to 6
        minItemsPerSkill: 3,
        maxItemsPerSkill: 5,
        skillSequence: [CatSkill.vocabulary, CatSkill.grammar, CatSkill.reading],
      );
      const customEngine = CatEngine(blueprint: tightBlueprint);

      var state = CatSessionState.initial('SESSION_MAX_ITEMS');
      state = state.copyWith(activeItem: customEngine.selectInitialItem(CatSkill.vocabulary));

      int turns = 0;
      while (!state.isCompleted && turns < 15) {
        turns++;
        final item = state.activeItem;
        if (item == null) break;

        state = customEngine.processTurn(
          currentState: state,
          userAnswer: item.correctOptionIndex ?? 0,
          latencyMs: 1000,
        );
      }

      expect(state.isCompleted, isTrue);
      expect(state.responses.length, equals(6), reason: 'Must stop precisely at maxTotalItems = 6');
      expect(state.status, 'completed');
      expect(state.activeItem, isNull);
      expect(state.result, isNotNull);
    });

    test('15 (F-02 Test 5): Enforces strict upper bound - never exceeds maxTotalItems even under repeated turn calls', () {
      const capBlueprint = CatBlueprint(
        minTotalItems: 2,
        maxTotalItems: 5,
        minItemsPerSkill: 3,
        maxItemsPerSkill: 5,
        skillSequence: [CatSkill.vocabulary],
      );
      const customEngine = CatEngine(blueprint: capBlueprint);

      var state = CatSessionState.initial('SESSION_CAP_BOUND');
      state = state.copyWith(activeItem: customEngine.selectInitialItem(CatSkill.vocabulary));

      for (int i = 0; i < 10; i++) {
        state = customEngine.processTurn(
          currentState: state,
          userAnswer: 0,
          latencyMs: 1000,
        );
      }

      expect(state.responses.length, equals(5));
      expect(state.responses.length, lessThanOrEqualTo(capBlueprint.maxTotalItems));
      expect(state.isCompleted, isTrue);
    });

    test('16 (F-02 Test 6): Preserves full assessment integrity: UTC completedAt, theta, SE, responses, skill counts, and blueprint version', () {
      var state = CatSessionState.initial('SESSION_INTEGRITY_CHECK');
      state = state.copyWith(activeItem: engine.selectInitialItem(CatSkill.vocabulary));

      while (!state.isCompleted) {
        final item = state.activeItem;
        if (item == null) break;

        dynamic answer = true;
        if (item.correctOptionIndex != null) answer = item.correctOptionIndex;
        if (item.correctAnswerText != null) answer = item.correctAnswerText;

        state = engine.processTurn(
          currentState: state,
          userAnswer: answer,
          latencyMs: 1000,
        );
      }

      expect(state.isCompleted, isTrue);
      final result = state.result;
      expect(result, isNotNull);

      // Verify responses & skill item counts
      expect(state.responses.isNotEmpty, isTrue);
      expect(state.responses.length, equals(state.stepIndex));

      int sumCounts = 0;
      for (final count in state.skillItemCounts.values) {
        sumCounts += count;
      }
      expect(sumCounts, equals(state.responses.length));

      // Verify theta and SE match
      expect(result!.overallTheta, equals(state.currentTheta));
      expect(result.overallStandardError, equals(state.currentStandardError));

      // Verify blueprint version
      expect(result.blueprintVersion, equals(engine.blueprint.version));

      // Verify completedAt in UTC
      expect(result.completedAt.isUtc, isTrue);
      expect(result.completedAt.isAfter(state.startedAt) || result.completedAt.isAtSameMomentAs(state.startedAt), isTrue);

      // Verify skillScores and referenceHskBand
      expect(result.skillScores.length, equals(CatSkill.values.length));
      expect(result.referenceHskBand, isNotEmpty);
      expect(result.recommendedHskLevel, inInclusiveRange(1, 6));
    });
  });
}
