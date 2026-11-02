class ExerciseEvaluationResult {
  final int totalQuestions;
  final int correctCount;
  final double scorePercent;
  final bool isPassed;
  final List<String> incorrectQuestionIds;

  const ExerciseEvaluationResult({
    required this.totalQuestions,
    required this.correctCount,
    required this.scorePercent,
    required this.isPassed,
    required this.incorrectQuestionIds,
  });
}

class AdaptiveExerciseSampler {
  const AdaptiveExerciseSampler();

  /// Samples [totalCount] questions, prioritizing [focusSkill] to at least 40% (e.g. 4 of 10).
  List<Map<String, dynamic>> sampleQuestions({
    required List<Map<String, dynamic>> allExercises,
    required String focusSkill,
    int totalCount = 10,
  }) {
    if (allExercises.length <= totalCount) {
      return List<Map<String, dynamic>>.from(allExercises);
    }

    final focusQuestions = allExercises.where((q) {
      final skill = (q['skill_type'] as String?)?.toLowerCase() ?? '';
      return skill == focusSkill.toLowerCase();
    }).toList();

    final otherQuestions = allExercises.where((q) {
      final skill = (q['skill_type'] as String?)?.toLowerCase() ?? '';
      return skill != focusSkill.toLowerCase();
    }).toList();

    // Target 40% focus questions (min 4 of 10)
    final targetFocusCount = (totalCount * 0.4).round();
    final actualFocusCount = focusQuestions.length < targetFocusCount
        ? focusQuestions.length
        : targetFocusCount;

    final selected = <Map<String, dynamic>>[];
    selected.addAll(focusQuestions.take(actualFocusCount));

    final neededOthers = totalCount - selected.length;
    selected.addAll(otherQuestions.take(neededOthers));

    // If still short, pull remainder from focus questions
    if (selected.length < totalCount && focusQuestions.length > actualFocusCount) {
      final moreFocus = focusQuestions.skip(actualFocusCount).take(totalCount - selected.length);
      selected.addAll(moreFocus);
    }

    return selected;
  }

  /// Deterministically evaluates user answers against official question keys without external APIs.
  ExerciseEvaluationResult evaluateSubmission({
    required List<Map<String, dynamic>> questions,
    required Map<String, dynamic> userAnswers,
    double passingThreshold = 0.8,
  }) {
    if (questions.isEmpty) {
      return const ExerciseEvaluationResult(
        totalQuestions: 0,
        correctCount: 0,
        scorePercent: 0.0,
        isPassed: false,
        incorrectQuestionIds: [],
      );
    }

    int correct = 0;
    final incorrectIds = <String>[];

    for (final q in questions) {
      final qId = q['id'] as String;
      final expected = q['correct_answer']?.toString().trim();
      final given = userAnswers[qId]?.toString().trim();

      if (expected != null && given != null && expected.toLowerCase() == given.toLowerCase()) {
        correct++;
      } else {
        incorrectIds.add(qId);
      }
    }

    final score = correct / questions.length;
    final isPassed = score >= passingThreshold;

    return ExerciseEvaluationResult(
      totalQuestions: questions.length,
      correctCount: correct,
      scorePercent: score,
      isPassed: isPassed,
      incorrectQuestionIds: incorrectIds,
    );
  }
}
