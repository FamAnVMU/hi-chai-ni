import '../models/practice_models.dart';

/// Pluggable interface for optional external AI evaluator
abstract class AiPracticeEvaluator {
  Future<ScoringResult> evaluateOpenAnswer({
    required ExerciseDefinition definition,
    required String studentAnswer,
  });
}

/// Unified scoring engine implementing deterministic and rubric-based evaluations
class PracticeScoringEngine {
  final AiPracticeEvaluator? aiEvaluator;

  const PracticeScoringEngine({this.aiEvaluator});

  /// Evaluates an attempt against its exercise definition
  Future<ScoringResult> evaluate({
    required ExerciseDefinition definition,
    required ExerciseAnswer answer,
  }) async {
    switch (definition.type) {
      case ExerciseType.multipleChoice:
      case ExerciseType.selectMeaningOrPinyin:
        return _evaluateMultipleChoice(definition, answer);

      case ExerciseType.matchingPairs:
        return _evaluateMatchingPairs(definition, answer);

      case ExerciseType.fillInTheBlank:
        return _evaluateFillInTheBlank(definition, answer);

      case ExerciseType.reorderWords:
        return _evaluateReorderWords(definition, answer);

      case ExerciseType.trueFalseOrErrorDetection:
        return _evaluateTrueFalseOrError(definition, answer);

      case ExerciseType.shortAnswer:
        return _evaluateShortAnswer(definition, answer);
    }
  }

  ScoringResult _evaluateMultipleChoice(
    ExerciseDefinition definition,
    ExerciseAnswer answer,
  ) {
    if (answer.selectedOptionIndex == null) {
      return const ScoringResult(
        isCorrect: false,
        score: 0.0,
        confidence: 1.0,
        evaluatorType: EvaluatorType.deterministic,
        feedbackVi: 'Chưa chọn đáp án.',
      );
    }

    final isCorrect = answer.selectedOptionIndex == definition.correctOptionIndex;
    final score = isCorrect ? 1.0 : 0.0;
    final correctText = definition.correctOptionIndex != null &&
            definition.correctOptionIndex! < definition.options.length
        ? definition.options[definition.correctOptionIndex!]
        : '';

    return ScoringResult(
      isCorrect: isCorrect,
      score: score,
      confidence: 1.0,
      evaluatorType: EvaluatorType.deterministic,
      feedbackVi: isCorrect
          ? 'Chính xác! ${definition.explanationVi}'
          : 'Chưa chính xác. Đáp án đúng là: "$correctText". ${definition.explanationVi}',
      breakdown: {
        'selected_index': answer.selectedOptionIndex,
        'correct_index': definition.correctOptionIndex,
      },
    );
  }

  ScoringResult _evaluateMatchingPairs(
    ExerciseDefinition definition,
    ExerciseAnswer answer,
  ) {
    final userPairs = answer.matchedPairs ?? {};
    final totalPairs = definition.matchingPairs.length;
    if (totalPairs == 0) {
      return const ScoringResult(
        isCorrect: true,
        score: 1.0,
        confidence: 1.0,
        evaluatorType: EvaluatorType.deterministic,
        feedbackVi: 'Hoàn tất ghép cặp.',
      );
    }

    int correctCount = 0;
    final details = <String, bool>{};

    for (final entry in definition.matchingPairs.entries) {
      final userMatch = userPairs[entry.key];
      final isMatch = userMatch == entry.value;
      if (isMatch) correctCount++;
      details[entry.key] = isMatch;
    }

    final score = correctCount / totalPairs;
    final isAllCorrect = correctCount == totalPairs;

    return ScoringResult(
      isCorrect: isAllCorrect,
      score: score,
      confidence: 1.0,
      evaluatorType: EvaluatorType.deterministic,
      feedbackVi: isAllCorrect
          ? 'Ghép cặp hoàn hảo ($correctCount/$totalPairs)! ${definition.explanationVi}'
          : 'Đã ghép đúng $correctCount/$totalPairs cặp. ${definition.explanationVi}',
      breakdown: {
        'correct_pairs': correctCount,
        'total_pairs': totalPairs,
        'details': details,
      },
    );
  }

  ScoringResult _evaluateFillInTheBlank(
    ExerciseDefinition definition,
    ExerciseAnswer answer,
  ) {
    final response = (answer.filledBlank ?? '').trim();
    if (response.isEmpty) {
      return const ScoringResult(
        isCorrect: false,
        score: 0.0,
        confidence: 1.0,
        evaluatorType: EvaluatorType.deterministic,
        feedbackVi: 'Vui lòng điền đáp án vào chỗ trống.',
      );
    }

    final normResponse = _normalize(response);
    final acceptable = <String>{};
    if (definition.blankAnswer != null) acceptable.add(_normalize(definition.blankAnswer!));
    for (final a in definition.acceptableAnswers) {
      acceptable.add(_normalize(a));
    }

    final isCorrect = acceptable.contains(normResponse);
    final primaryTarget = definition.blankAnswer ?? definition.acceptableAnswers.firstOrNull ?? '';

    return ScoringResult(
      isCorrect: isCorrect,
      score: isCorrect ? 1.0 : 0.0,
      confidence: 1.0,
      evaluatorType: EvaluatorType.deterministic,
      feedbackVi: isCorrect
          ? 'Điền từ chính xác! ${definition.explanationVi}'
          : 'Chưa chính xác. Đáp án đúng: "$primaryTarget". ${definition.explanationVi}',
      breakdown: {
        'student_response': response,
        'target_blank': primaryTarget,
      },
    );
  }

  ScoringResult _evaluateReorderWords(
    ExerciseDefinition definition,
    ExerciseAnswer answer,
  ) {
    final tokens = answer.orderedTokens ?? [];
    if (tokens.isEmpty) {
      return const ScoringResult(
        isCorrect: false,
        score: 0.0,
        confidence: 1.0,
        evaluatorType: EvaluatorType.deterministic,
        feedbackVi: 'Vui lòng sắp xếp các từ để hoàn thiện câu.',
      );
    }

    final assembled = _normalize(tokens.join());
    final targetNorm = _normalize(definition.targetSentence ?? '');
    final acceptable = definition.acceptableAnswers.map(_normalize).toSet();

    final isCorrect = assembled == targetNorm || acceptable.contains(assembled);

    return ScoringResult(
      isCorrect: isCorrect,
      score: isCorrect ? 1.0 : 0.0,
      confidence: 1.0,
      evaluatorType: EvaluatorType.deterministic,
      feedbackVi: isCorrect
          ? 'Trật tự câu chuẩn xác! ${definition.explanationVi}'
          : 'Trật tự câu chưa đúng. Câu chuẩn: "${definition.targetSentence}". ${definition.explanationVi}',
      breakdown: {
        'assembled_sentence': tokens.join(),
        'target_sentence': definition.targetSentence,
      },
    );
  }

  ScoringResult _evaluateTrueFalseOrError(
    ExerciseDefinition definition,
    ExerciseAnswer answer,
  ) {
    // 1. Error detection mode
    if (definition.errorToken != null && definition.errorToken!.isNotEmpty) {
      final selected = answer.selectedErrorToken ?? '';
      final isCorrect = selected == definition.errorToken ||
          (selected.isNotEmpty && _normalize(selected) == _normalize(definition.errorToken!));
      return ScoringResult(
        isCorrect: isCorrect,
        score: isCorrect ? 1.0 : 0.0,
        confidence: 1.0,
        evaluatorType: EvaluatorType.deterministic,
        feedbackVi: isCorrect
          ? 'Phát hiện lỗi rất tốt! Lỗi ở: "${definition.errorToken}". ${definition.explanationVi}'
          : 'Chưa tìm đúng vị trí lỗi. Chỗ sai là: "${definition.errorToken}". ${definition.explanationVi}',
        breakdown: {
          'selected_error_token': selected,
          'target_error_token': definition.errorToken,
          'suggested_correction': definition.errorCorrection,
        },
      );
    }

    // 2. Standard True/False mode
    if (answer.userBool == null) {
      return const ScoringResult(
        isCorrect: false,
        score: 0.0,
        confidence: 1.0,
        evaluatorType: EvaluatorType.deterministic,
        feedbackVi: 'Vui lòng chọn Đúng hoặc Sai.',
      );
    }

    final isCorrect = answer.userBool == definition.isTrue;
    return ScoringResult(
      isCorrect: isCorrect,
      score: isCorrect ? 1.0 : 0.0,
      confidence: 1.0,
      evaluatorType: EvaluatorType.deterministic,
      feedbackVi: isCorrect
          ? 'Nhận định hoàn toàn chính xác! ${definition.explanationVi}'
          : 'Nhận định chưa đúng. ${definition.explanationVi}',
      breakdown: {
        'student_boolean': answer.userBool,
        'target_boolean': definition.isTrue,
      },
    );
  }

  Future<ScoringResult> _evaluateShortAnswer(
    ExerciseDefinition definition,
    ExerciseAnswer answer,
  ) async {
    final response = (answer.textResponse ?? '').trim();
    if (response.isEmpty) {
      return const ScoringResult(
        isCorrect: false,
        score: 0.0,
        confidence: 1.0,
        evaluatorType: EvaluatorType.deterministic,
        feedbackVi: 'Vui lòng nhập câu trả lời ngắn.',
      );
    }

    // Step 1: Deterministic check against exact target & acceptable list
    final normResponse = _normalize(response);
    final targetNorm = _normalize(definition.targetSentence ?? '');
    final acceptable = definition.acceptableAnswers.map(_normalize).toSet();

    if (normResponse == targetNorm || acceptable.contains(normResponse)) {
      return ScoringResult(
        isCorrect: true,
        score: 1.0,
        confidence: 1.0,
        evaluatorType: EvaluatorType.deterministic,
        feedbackVi: 'Câu trả lời chuẩn xác tuyệt đối! ${definition.explanationVi}',
        breakdown: {'matching_rule': 'exact_match'},
      );
    }

    // Step 2: If external AI Evaluator provided and configured, delegate to AI
    if (aiEvaluator != null) {
      return await aiEvaluator!.evaluateOpenAnswer(
        definition: definition,
        studentAnswer: response,
      );
    }

    // Step 3: Pedagogical Rubric keyword matching
    if (definition.rubricKeywords.isNotEmpty) {
      int matched = 0;
      final matchedKeywords = <String>[];
      for (final kw in definition.rubricKeywords) {
        if (normResponse.contains(_normalize(kw))) {
          matched++;
          matchedKeywords.add(kw);
        }
      }

      final ratio = matched / definition.rubricKeywords.length;

      if (ratio >= 1.0) {
        return ScoringResult(
          isCorrect: true,
          score: 0.85,
          confidence: 0.85,
          needsHumanReview: false,
          evaluatorType: EvaluatorType.rubric,
          feedbackVi: 'Đạt toàn bộ từ khóa và tiêu chí ngữ nghĩa yêu cầu! ${definition.explanationVi}',
          breakdown: {
            'matched_keywords': matchedKeywords,
            'total_keywords': definition.rubricKeywords.length,
            'ratio': ratio,
          },
        );
      } else if (ratio >= 0.5) {
        return ScoringResult(
          isCorrect: false,
          score: 0.50,
          confidence: 0.65, // Below 0.8 threshold
          needsHumanReview: true, // Transparently flags for review
          evaluatorType: EvaluatorType.rubric,
          feedbackVi: 'Đã truyền đạt được một phần nội dung nhưng chưa trọn vẹn. [Cần xem lại kết quả]. ${definition.explanationVi}',
          breakdown: {
            'matched_keywords': matchedKeywords,
            'total_keywords': definition.rubricKeywords.length,
            'ratio': ratio,
          },
        );
      }
    }

    // Step 4: Structural failure
    return ScoringResult(
      isCorrect: false,
      score: 0.10,
      confidence: 0.90,
      needsHumanReview: false,
      evaluatorType: EvaluatorType.rubric,
      feedbackVi: 'Chưa đạt nội dung yêu cầu. Câu mẫu tham khảo: "${definition.targetSentence}". ${definition.explanationVi}',
      breakdown: {
        'matching_rule': 'rubric_failure',
        'target_sample': definition.targetSentence,
      },
    );
  }

  /// Normalizes string by trimming, removing whitespace & punctuation
  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '')
        .replaceAll('。', '')
        .replaceAll('，', '')
        .replaceAll('！', '')
        .replaceAll('？', '')
        .replaceAll('、', '');
  }
}
