import 'package:flutter_test/flutter_test.dart';
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
      expect(speakingItem.checkAnswer('speech_sample_recorded'), isTrue);
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

      // Pass turn with 0.85 pronunciation score
      final nextState = engine.processTurn(
        currentState: state,
        userAnswer: 0.85,
        latencyMs: 1500,
      );

      expect(nextState.responses.last.isCorrect, isTrue);
      expect(nextState.currentTheta, greaterThan(initialTheta));
    });
  });
}
