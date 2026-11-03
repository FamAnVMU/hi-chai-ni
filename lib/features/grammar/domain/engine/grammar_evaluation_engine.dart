import '../models/grammar_models.dart';

/// Evaluation engine evaluating grammar exercises with deterministic precision
/// and transparent academic rubric checks for open answers.
class GrammarEvaluationEngine {
  const GrammarEvaluationEngine();

  /// Evaluates a learner's submission against the exercise criteria
  ExerciseEvaluationResult evaluate({
    required GrammarExercise exercise,
    int? selectedOptionIndex,
    List<String>? orderedTokens,
    String? openTextResponse,
  }) {
    switch (exercise.type) {
      case GrammarExerciseType.multipleChoice:
      case GrammarExerciseType.fillInBlank:
      case GrammarExerciseType.errorRecognition:
        return _evaluateMultipleChoice(exercise, selectedOptionIndex);
      case GrammarExerciseType.reorderWords:
        return _evaluateReorderWords(exercise, orderedTokens);
      case GrammarExerciseType.openTranslation:
        return _evaluateOpenTranslation(exercise, openTextResponse ?? '');
    }
  }

  ExerciseEvaluationResult _evaluateMultipleChoice(
    GrammarExercise exercise,
    int? selectedIndex,
  ) {
    if (selectedIndex == null) {
      return const ExerciseEvaluationResult(
        isCorrect: false,
        score: 0.0,
        confidence: 1.0,
        needsHumanReview: false,
        feedbackVi: 'Chưa chọn đáp án.',
      );
    }

    final isCorrect = selectedIndex == exercise.correctAnswerIndex;
    final score = isCorrect ? 1.0 : 0.0;
    final feedback = isCorrect
        ? 'Chính xác! ${exercise.explanationVi}'
        : 'Chưa chính xác. ${exercise.explanationVi}';

    return ExerciseEvaluationResult(
      isCorrect: isCorrect,
      score: score,
      confidence: 1.0,
      needsHumanReview: false,
      feedbackVi: feedback,
      matchingRule: 'exact_choice_index',
    );
  }

  ExerciseEvaluationResult _evaluateReorderWords(
    GrammarExercise exercise,
    List<String>? orderedTokens,
  ) {
    if (orderedTokens == null || orderedTokens.isEmpty) {
      return const ExerciseEvaluationResult(
        isCorrect: false,
        score: 0.0,
        confidence: 1.0,
        needsHumanReview: false,
        feedbackVi: 'Chưa sắp xếp các từ.',
      );
    }

    final assembled = _normalizeChinese(orderedTokens.join(''));
    final targetNorm = _normalizeChinese(exercise.targetSentence);
    final acceptableNorms = exercise.acceptableAnswers.map(_normalizeChinese).toSet();

    if (assembled == targetNorm || acceptableNorms.contains(assembled)) {
      return ExerciseEvaluationResult(
        isCorrect: true,
        score: 1.0,
        confidence: 1.0,
        needsHumanReview: false,
        feedbackVi: 'Chính xác! Trật tự từ hoàn toàn đúng cấu trúc. ${exercise.explanationVi}',
        matchingRule: 'exact_reorder_match',
      );
    }

    return ExerciseEvaluationResult(
      isCorrect: false,
      score: 0.0,
      confidence: 1.0,
      needsHumanReview: false,
      feedbackVi: 'Trật tự câu chưa đúng. Câu chuẩn: "${exercise.targetSentence}". ${exercise.explanationVi}',
      matchingRule: 'reorder_mismatch',
    );
  }

  ExerciseEvaluationResult _evaluateOpenTranslation(
    GrammarExercise exercise,
    String responseText,
  ) {
    final cleaned = _normalizeChinese(responseText);
    if (cleaned.isEmpty) {
      return const ExerciseEvaluationResult(
        isCorrect: false,
        score: 0.0,
        confidence: 1.0,
        needsHumanReview: false,
        feedbackVi: 'Vui lòng nhập câu trả lời của bạn.',
      );
    }

    final targetNorm = _normalizeChinese(exercise.targetSentence);
    final acceptableNorms = exercise.acceptableAnswers.map(_normalizeChinese).toSet();

    // 1. Exact or recognized acceptable phrasing match
    if (cleaned == targetNorm || acceptableNorms.contains(cleaned)) {
      return const ExerciseEvaluationResult(
        isCorrect: true,
        score: 1.0,
        confidence: 1.0,
        needsHumanReview: false,
        feedbackVi: 'Xuất sắc! Câu trả lời chính xác tuyệt đối với cấu trúc chuẩn.',
        matchingRule: 'exact_open_match',
      );
    }

    // 2. Rubric Keywords and structural tokens analysis
    if (exercise.rubricKeywords.isNotEmpty) {
      int matchedCount = 0;
      for (final kw in exercise.rubricKeywords) {
        if (cleaned.contains(_normalizeChinese(kw))) {
          matchedCount++;
        }
      }

      final matchRatio = matchedCount / exercise.rubricKeywords.length;

      if (matchRatio >= 1.0) {
        // High confidence structural pass
        return ExerciseEvaluationResult(
          isCorrect: true,
          score: 0.85,
          confidence: 0.85,
          needsHumanReview: false,
          feedbackVi: 'Đạt cấu trúc ngữ pháp yêu cầu! Tham khảo câu mẫu chuẩn: "${exercise.targetSentence}".',
          matchingRule: 'rubric_complete_keywords',
        );
      } else if (matchRatio >= 0.5) {
        // Moderate confidence: Contains partial structural elements but may have word order / particle issues
        return ExerciseEvaluationResult(
          isCorrect: false,
          score: 0.50,
          confidence: 0.65, // Below 0.8 threshold
          needsHumanReview: true, // Transparent flag for review
          feedbackVi: 'Đã dùng được một số từ khóa ngữ pháp nhưng cấu trúc chưa hoàn chỉnh. [Cần xem lại kết quả].',
          matchingRule: 'rubric_partial_review_required',
        );
      }
    }

    // 3. Fails rubric completely
    return ExerciseEvaluationResult(
      isCorrect: false,
      score: 0.10,
      confidence: 0.90,
      needsHumanReview: false,
      feedbackVi: 'Chưa vận dụng đúng cấu trúc ngữ pháp mục tiêu. Câu mẫu chuẩn: "${exercise.targetSentence}".',
      matchingRule: 'rubric_structural_failure',
    );
  }

  /// Normalizes Chinese text by removing punctuation, spaces, and converting full-width punctuation
  String _normalizeChinese(String text) {
    return text
        .replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '')
        .replaceAll('。', '')
        .replaceAll('，', '')
        .replaceAll('！', '')
        .replaceAll('？', '')
        .replaceAll('、', '')
        .replaceAll('：', '')
        .replaceAll('；', '')
        .trim();
  }
}
