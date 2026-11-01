import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/practice/practice.dart';

void main() {
  const engine = PracticeScoringEngine();

  group('PracticeScoringEngine Unit & Acceptance Tests', () {
    test('1. MultipleChoice evaluates deterministically', () async {
      final def = PracticeSeedCatalog.items.firstWhere((e) => e.type == ExerciseType.multipleChoice);

      // Correct
      final resCorrect = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(exerciseId: 'EX_MC_VOCAB_01', selectedOptionIndex: 0),
      );
      expect(resCorrect.isCorrect, isTrue);
      expect(resCorrect.score, 1.0);
      expect(resCorrect.evaluatorType, EvaluatorType.deterministic);

      // Incorrect
      final resWrong = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(exerciseId: 'EX_MC_VOCAB_01', selectedOptionIndex: 1),
      );
      expect(resWrong.isCorrect, isFalse);
      expect(resWrong.score, 0.0);
    });

    test('2. MatchingPairs awards partial credit accurately', () async {
      final def = PracticeSeedCatalog.items.firstWhere((e) => e.type == ExerciseType.matchingPairs);

      // All 4 pairs correct
      final resFull = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(
          exerciseId: 'EX_MATCH_VOCAB_03',
          matchedPairs: {
            '你好': 'Xin chào',
            '谢谢': 'Cảm ơn',
            '再见': 'Tạm biệt',
            '对不起': 'Xin lỗi',
          },
        ),
      );
      expect(resFull.isCorrect, isTrue);
      expect(resFull.score, 1.0);

      // 2 out of 4 correct -> score = 0.5
      final resHalf = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(
          exerciseId: 'EX_MATCH_VOCAB_03',
          matchedPairs: {
            '你好': 'Xin chào',
            '谢谢': 'Cảm ơn',
            '再见': 'Sai',
            '对不起': 'Nhầm',
          },
        ),
      );
      expect(resHalf.isCorrect, isFalse);
      expect(resHalf.score, 0.5);
      expect(resHalf.breakdown?['correct_pairs'], 2);
    });

    test('3. FillInTheBlank handles whitespace and punctuation invariance', () async {
      final def = PracticeSeedCatalog.items.firstWhere((e) => e.type == ExerciseType.fillInTheBlank);

      final res = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(exerciseId: 'EX_BLANK_GRAMMAR_04', filledBlank: ' 是  '),
      );
      expect(res.isCorrect, isTrue);
      expect(res.score, 1.0);

      final resWrong = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(exerciseId: 'EX_BLANK_GRAMMAR_04', filledBlank: '在'),
      );
      expect(resWrong.isCorrect, isFalse);
      expect(resWrong.score, 0.0);
    });

    test('4. ReorderWords validates character order', () async {
      final def = PracticeSeedCatalog.items.firstWhere((e) => e.type == ExerciseType.reorderWords);

      final res = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(
          exerciseId: 'EX_REORDER_GRAMMAR_05',
          orderedTokens: ['我', '喜欢', '吃', '中国菜'],
        ),
      );
      expect(res.isCorrect, isTrue);
      expect(res.score, 1.0);

      final resWrong = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(
          exerciseId: 'EX_REORDER_GRAMMAR_05',
          orderedTokens: ['中国菜', '我', '吃', '喜欢'],
        ),
      );
      expect(resWrong.isCorrect, isFalse);
      expect(resWrong.score, 0.0);
    });

    test('5. TrueFalse and ErrorDetection pinpoint exact targets', () async {
      final def = PracticeSeedCatalog.items.firstWhere((e) => e.id == 'EX_ERROR_DETECT_06');

      final res = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(
          exerciseId: 'EX_ERROR_DETECT_06',
          selectedErrorToken: '在。',
        ),
      );
      expect(res.isCorrect, isTrue);
      expect(res.score, 1.0);

      final resWrong = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(
          exerciseId: 'EX_ERROR_DETECT_06',
          selectedErrorToken: '他在学校',
        ),
      );
      expect(resWrong.isCorrect, isFalse);
      expect(resWrong.score, 0.0);
    });

    test('6. ShortAnswer evaluates rubric keywords and flags uncertainty transparently', () async {
      final def = PracticeSeedCatalog.items.firstWhere((e) => e.type == ExerciseType.shortAnswer);

      // Exact match
      final resExact = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(exerciseId: 'EX_SHORT_ANSWER_07', textResponse: '今天比昨天冷。'),
      );
      expect(resExact.isCorrect, isTrue);
      expect(resExact.score, 1.0);
      expect(resExact.confidence, 1.0);

      // Rubric partial match: contains '今天', '比' but misses '昨天' and '冷' (2/4 = 50%)
      final resPartial = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(exerciseId: 'EX_SHORT_ANSWER_07', textResponse: '今天比很热'),
      );
      expect(resPartial.isCorrect, isFalse);
      expect(resPartial.score, 0.50);
      expect(resPartial.confidence, 0.65);
      expect(resPartial.needsHumanReview, isTrue); // Transparently flags uncertainty!
      expect(resPartial.evaluatorType, EvaluatorType.rubric);

      // Complete rubric structural failure
      final resFail = await engine.evaluate(
        definition: def,
        answer: const ExerciseAnswer(exerciseId: 'EX_SHORT_ANSWER_07', textResponse: '你好吗'),
      );
      expect(resFail.isCorrect, isFalse);
      expect(resFail.score, 0.10);
      expect(resFail.needsHumanReview, isFalse);
    });

    test('7. Randomization with seed produces reproducible permutations', () {
      final def = PracticeSeedCatalog.items.firstWhere((e) => e.type == ExerciseType.reorderWords);

      final perm1 = def.getShuffledTokens(seed: 12345);
      final perm2 = def.getShuffledTokens(seed: 12345);
      expect(perm1, equals(perm2), reason: 'Identical seeds must produce identical permutations');

      final perm3 = def.getShuffledTokens(seed: 99999);
      expect(perm1, isNot(equals(perm3)), reason: 'Different seeds should produce different order');
    });
  });
}
