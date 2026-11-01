import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/practice/practice.dart';

void main() {
  const validator = ExerciseValidator();

  group('ExerciseValidator Acceptance Tests', () {
    test('1. Valid definitions across all 7 types pass validation', () {
      for (final item in PracticeSeedCatalog.items) {
        final errors = validator.validate(item);
        expect(errors, isEmpty, reason: 'Expected valid for ${item.id} (${item.type})');
        expect(validator.isValid(item), isTrue);
      }
    });

    test('2. MultipleChoice requires at least 2 options and valid correctOptionIndex', () {
      final invalidMc1 = ExerciseDefinition(
        id: 'ex_test',
        type: ExerciseType.multipleChoice,
        skill: 'vocabulary',
        prompt: 'Chọn từ:',
        options: const ['Một option'],
        correctOptionIndex: 0,
        explanationVi: 'Giải thích',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final errors1 = validator.validate(invalidMc1);
      expect(errors1.any((e) => e.field == 'options'), isTrue);

      final invalidMc2 = ExerciseDefinition(
        id: 'ex_test_2',
        type: ExerciseType.multipleChoice,
        skill: 'vocabulary',
        prompt: 'Chọn từ:',
        options: const ['A', 'B'],
        correctOptionIndex: 5, // Out of range!
        explanationVi: 'Giải thích',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final errors2 = validator.validate(invalidMc2);
      expect(errors2.any((e) => e.field == 'correctOptionIndex'), isTrue);
    });

    test('3. MatchingPairs requires at least 2 pairs and non-blank values', () {
      final invalidPairs1 = ExerciseDefinition(
        id: 'ex_pair_1',
        type: ExerciseType.matchingPairs,
        skill: 'vocabulary',
        prompt: 'Ghép cặp:',
        matchingPairs: const {'A': 'B'}, // only 1 pair
        explanationVi: 'Giải thích',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final errors1 = validator.validate(invalidPairs1);
      expect(errors1.any((e) => e.field == 'matchingPairs'), isTrue);

      final invalidPairs2 = ExerciseDefinition(
        id: 'ex_pair_2',
        type: ExerciseType.matchingPairs,
        skill: 'vocabulary',
        prompt: 'Ghép cặp:',
        matchingPairs: const {'A': '', 'B': '2'}, // blank value
        explanationVi: 'Giải thích',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final errors2 = validator.validate(invalidPairs2);
      expect(errors2.any((e) => e.field == 'matchingPairs'), isTrue);
    });

    test('4. FillInTheBlank requires blank indicator and target answer', () {
      final invalidBlank1 = ExerciseDefinition(
        id: 'ex_blank_1',
        type: ExerciseType.fillInTheBlank,
        skill: 'grammar',
        prompt: 'Điền vào câu:',
        sentenceWithBlank: 'Câu không có chỗ trống.', // No ___ or _
        blankAnswer: 'đáp án',
        explanationVi: 'Giải thích',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final errors1 = validator.validate(invalidBlank1);
      expect(errors1.any((e) => e.field == 'sentenceWithBlank'), isTrue);

      final invalidBlank2 = ExerciseDefinition(
        id: 'ex_blank_2',
        type: ExerciseType.fillInTheBlank,
        skill: 'grammar',
        prompt: 'Điền vào câu:',
        sentenceWithBlank: 'Tôi là ___ học sinh.',
        blankAnswer: null,
        acceptableAnswers: const [],
        explanationVi: 'Giải thích',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final errors2 = validator.validate(invalidBlank2);
      expect(errors2.any((e) => e.field == 'blankAnswer'), isTrue);
    });

    test('5. ReorderWords requires at least 2 tokens and target sentence', () {
      final invalidReorder = ExerciseDefinition(
        id: 'ex_reorder_1',
        type: ExerciseType.reorderWords,
        skill: 'grammar',
        prompt: 'Sắp xếp:',
        tokens: const ['duy_nhat'],
        targetSentence: 'duy_nhat',
        explanationVi: 'Giải thích',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final errors = validator.validate(invalidReorder);
      expect(errors.any((e) => e.field == 'tokens'), isTrue);
    });

    test('6. TrueFalseOrErrorDetection requires boolean or error token in stimulus', () {
      final invalidTf = ExerciseDefinition(
        id: 'ex_tf_1',
        type: ExerciseType.trueFalseOrErrorDetection,
        skill: 'reading',
        prompt: 'Đúng hay sai:',
        isTrue: null,
        errorToken: null,
        explanationVi: 'Giải thích',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final errors = validator.validate(invalidTf);
      expect(errors.any((e) => e.field.contains('isTrue')), isTrue);
    });

    test('7. ShortAnswer requires targetSentence, acceptableAnswers, or rubricKeywords', () {
      final invalidShort = ExerciseDefinition(
        id: 'ex_short_1',
        type: ExerciseType.shortAnswer,
        skill: 'writing',
        prompt: 'Viết câu:',
        targetSentence: null,
        acceptableAnswers: const [],
        rubricKeywords: const [],
        explanationVi: 'Giải thích',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final errors = validator.validate(invalidShort);
      expect(errors.any((e) => e.field == 'shortAnswer'), isTrue);
    });
  });
}
