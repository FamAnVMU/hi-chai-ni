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

  /// Canonical 6 core skills for comprehensive balanced curriculum distribution.
  static const List<String> canonicalSkills = [
    'listening',
    'speaking',
    'reading',
    'writing',
    'vocabulary',
    'grammar',
  ];

  /// Samples [totalCount] questions:
  /// - When [focusSkill] is 'balanced' (Comprehensive path): distributes exercises evenly
  ///   across the 6 skills (~16.7% each), without applying the 40% single-skill boost.
  /// - When [focusSkill] is a specific skill (e.g. 'reading'): allocates at least 40%
  ///   to that priority skill and distributes the remaining 60% across other skills.
  List<Map<String, dynamic>> sampleQuestions({
    required List<Map<String, dynamic>> allExercises,
    required String focusSkill,
    int totalCount = 10,
  }) {
    if (allExercises.length <= totalCount) {
      return List<Map<String, dynamic>>.from(allExercises);
    }

    final normalizedFocus = focusSkill.toLowerCase().trim();

    // 1. Comprehensive / Balanced distribution path (~16.7% each across 6 skills)
    if (normalizedFocus == 'balanced') {
      final skillBuckets = <String, List<Map<String, dynamic>>>{};
      for (final q in allExercises) {
        final skill = (q['skill_type'] as String?)?.toLowerCase().trim() ?? 'other';
        skillBuckets.putIfAbsent(skill, () => []).add(q);
      }

      // Order skills: canonical 6 first, then any other skills
      final orderedSkills = <String>[];
      for (final s in canonicalSkills) {
        if (skillBuckets.containsKey(s)) {
          orderedSkills.add(s);
        }
      }
      for (final s in skillBuckets.keys) {
        if (!orderedSkills.contains(s)) {
          orderedSkills.add(s);
        }
      }

      if (orderedSkills.isEmpty) {
        return allExercises.take(totalCount).toList();
      }

      final selected = <Map<String, dynamic>>[];
      final pointers = <String, int>{for (final s in orderedSkills) s: 0};

      while (selected.length < totalCount) {
        bool addedInCycle = false;
        for (final s in orderedSkills) {
          if (selected.length >= totalCount) break;
          final pool = skillBuckets[s]!;
          final idx = pointers[s]!;
          if (idx < pool.length) {
            selected.add(pool[idx]);
            pointers[s] = idx + 1;
            addedInCycle = true;
          }
        }
        if (!addedInCycle) break;
      }

      // If still short of totalCount, top up with remaining unselected questions
      if (selected.length < totalCount) {
        final selectedIds = selected.map((q) => q['id']).toSet();
        for (final q in allExercises) {
          if (selected.length >= totalCount) break;
          if (!selectedIds.contains(q['id'])) {
            selected.add(q);
          }
        }
      }

      return selected;
    }

    // 2. Focused priority skill path (40% priority skill + 60% other skills)
    final focusQuestions = allExercises.where((q) {
      final skill = (q['skill_type'] as String?)?.toLowerCase() ?? '';
      return skill == normalizedFocus;
    }).toList();

    final otherQuestions = allExercises.where((q) {
      final skill = (q['skill_type'] as String?)?.toLowerCase() ?? '';
      return skill != normalizedFocus;
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
