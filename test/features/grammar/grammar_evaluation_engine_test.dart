import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/grammar/grammar.dart';

void main() {
  const engine = GrammarEvaluationEngine();

  group('GrammarEvaluationEngine Unit Tests', () {
    test('1. Multiple choice evaluation is exact and deterministic', () {
      const exercise = GrammarExercise(
        id: 'ex_mc_1',
        type: GrammarExerciseType.multipleChoice,
        prompt: 'Chọn từ đúng:',
        sentenceWithBlank: '李明 ___ 老师。',
        options: ['是', '在', '有'],
        correctAnswerIndex: 0,
        targetSentence: '李明是老师。',
        explanationVi: 'Câu phán đoán dùng 是.',
      );

      // Correct selection
      final resultCorrect = engine.evaluate(
        exercise: exercise,
        selectedOptionIndex: 0,
      );
      expect(resultCorrect.isCorrect, isTrue);
      expect(resultCorrect.score, 1.0);
      expect(resultCorrect.confidence, 1.0);
      expect(resultCorrect.needsHumanReview, isFalse);

      // Incorrect selection
      final resultIncorrect = engine.evaluate(
        exercise: exercise,
        selectedOptionIndex: 1,
      );
      expect(resultIncorrect.isCorrect, isFalse);
      expect(resultIncorrect.score, 0.0);
      expect(resultIncorrect.confidence, 1.0);
      expect(resultIncorrect.needsHumanReview, isFalse);

      // Unanswered
      final resultEmpty = engine.evaluate(exercise: exercise);
      expect(resultEmpty.isCorrect, isFalse);
    });

    test('2. Reorder words evaluation handles whitespace and punctuation invariance', () {
      const exercise = GrammarExercise(
        id: 'ex_reorder_1',
        type: GrammarExerciseType.reorderWords,
        prompt: 'Sắp xếp câu:',
        shuffledTokens: ['在', '看书', '我', '学校'],
        targetSentence: '我在学校看书。',
        acceptableAnswers: ['我在学校看书', '我在学校看书。'],
        explanationVi: 'Trạng ngữ nơi chốn đứng trước động từ.',
      );

      // Correct order
      final resultCorrect = engine.evaluate(
        exercise: exercise,
        orderedTokens: ['我', '在', '学校', '看书'],
      );
      expect(resultCorrect.isCorrect, isTrue);
      expect(resultCorrect.score, 1.0);
      expect(resultCorrect.confidence, 1.0);
      expect(resultCorrect.needsHumanReview, isFalse);

      // Incorrect order (L1 Vietnamese transfer: 看书在学校)
      final resultWrong = engine.evaluate(
        exercise: exercise,
        orderedTokens: ['我', '看书', '在', '学校'],
      );
      expect(resultWrong.isCorrect, isFalse);
      expect(resultWrong.score, 0.0);
      expect(resultWrong.confidence, 1.0);
      expect(resultWrong.needsHumanReview, isFalse);
    });

    test('3. Open translation exact match achieves 100% score and high confidence', () {
      const exercise = GrammarExercise(
        id: 'ex_open_1',
        type: GrammarExerciseType.openTranslation,
        prompt: 'Dịch câu: Cô ấy là bác sĩ.',
        targetSentence: '她是医生。',
        acceptableAnswers: ['她是医生', '她是大夫'],
        rubricKeywords: ['她是', '医生'],
        explanationVi: 'Cô ấy (她) + 是 + 医生.',
      );

      final result = engine.evaluate(
        exercise: exercise,
        openTextResponse: '她是医生',
      );
      expect(result.isCorrect, isTrue);
      expect(result.score, 1.0);
      expect(result.confidence, 1.0);
      expect(result.needsHumanReview, isFalse);
    });

    test('4. Open translation with complete rubric keywords yields high confidence pass', () {
      const exercise = GrammarExercise(
        id: 'ex_open_2',
        type: GrammarExerciseType.openTranslation,
        prompt: 'Dịch: Họ ăn cơm ở nhà hàng.',
        targetSentence: '他们在饭馆吃饭。',
        acceptableAnswers: ['他们在饭馆吃饭'],
        rubricKeywords: ['在', '饭馆', '吃饭'],
        explanationVi: 'Ở nhà hàng ăn cơm.',
      );

      // Expressed with acceptable synonym / variations containing all required slots
      final result = engine.evaluate(
        exercise: exercise,
        openTextResponse: '我们今天都在饭馆吃饭呢',
      );
      expect(result.isCorrect, isTrue);
      expect(result.score, 0.85);
      expect(result.confidence, 0.85);
      expect(result.needsHumanReview, isFalse);
    });

    test('5. Open translation with partial structural keywords flags needsHumanReview transparently', () {
      const exercise = GrammarExercise(
        id: 'ex_open_3',
        type: GrammarExerciseType.openTranslation,
        prompt: 'Dịch câu chữ 把: Anh ấy đã uống nước rồi.',
        targetSentence: '他把水喝了。',
        rubricKeywords: ['把', '水', '喝了'],
        explanationVi: 'Chủ ngữ + 把 + Tân ngữ + Động từ + 了.',
      );

      // Student remembered 把 and 水 but missed the mandatory completion aspect particle 了
      final result = engine.evaluate(
        exercise: exercise,
        openTextResponse: '他把水喝',
      );
      expect(result.isCorrect, isFalse);
      expect(result.score, 0.50);
      expect(result.confidence, 0.65); // < 0.8 confidence threshold
      expect(result.needsHumanReview, isTrue); // Flagged for human/teacher review!
      expect(result.feedbackVi, contains('Cần xem lại kết quả'));
    });

    test('6. Open translation failing grammar rubric is marked incorrect', () {
      const exercise = GrammarExercise(
        id: 'ex_open_4',
        type: GrammarExerciseType.openTranslation,
        prompt: 'Dịch câu so sánh: Quả dưa hấu to hơn quả táo.',
        targetSentence: '西瓜比苹果大。',
        rubricKeywords: ['西瓜', '比', '苹果', '大'],
        explanationVi: 'A 比 B + Tính từ.',
      );

      // Totally missing comparative structure and target elements
      final result = engine.evaluate(
        exercise: exercise,
        openTextResponse: '今天天气很好',
      );
      expect(result.isCorrect, isFalse);
      expect(result.score, 0.10);
      expect(result.needsHumanReview, isFalse);
    });
  });
}
