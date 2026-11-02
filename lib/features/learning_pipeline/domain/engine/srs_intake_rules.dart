import '../models/mastery_state.dart';

/// Decision result for an item considered for SRS enrollment or rescheduling.
class SrsIntakeDecision {
  final bool shouldEnrollOrReschedule;
  final String srsItemId;
  final String contentId;
  final String contentType;
  final String targetState; // 'new', 'learning', 'relearning'
  final DateTime scheduledDueAt;
  final String reason;

  const SrsIntakeDecision({
    required this.shouldEnrollOrReschedule,
    required this.srsItemId,
    required this.contentId,
    required this.contentType,
    required this.targetState,
    required this.scheduledDueAt,
    required this.reason,
  });

  static String generateSrsItemId(String contentId, String contentType) {
    return 'SRS_${contentType.toUpperCase()}_$contentId';
  }
}

/// Pure business rules determining when and how knowledge items enter or get rescheduled
/// in the Spaced Repetition System (SRS).
class SrsIntakeRules {
  const SrsIntakeRules();

  static String generateSrsItemId(String contentId, String contentType) {
    return SrsIntakeDecision.generateSrsItemId(contentId, contentType);
  }

  /// Evaluates an item newly completed in a syllabus lesson.
  /// Scheduled for first recall review tomorrow.
  SrsIntakeDecision evaluateLessonVocabIntake({
    required String contentId,
    String contentType = 'vocabulary',
    DateTime? now,
  }) {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    return SrsIntakeDecision(
      shouldEnrollOrReschedule: true,
      srsItemId: SrsIntakeRules.generateSrsItemId(contentId, contentType),
      contentId: contentId,
      contentType: contentType,
      targetState: 'learning',
      scheduledDueAt: nowUtc.add(const Duration(days: 1)),
      reason: 'lesson_intake',
    );
  }

  /// Evaluates a knowledge item missed during exercises, tests, or quizzes.
  /// Scheduled immediately for urgent reinforcement (`due_at: now`).
  SrsIntakeDecision evaluateFailedAttemptIntake({
    required String contentId,
    String contentType = 'vocabulary',
    DateTime? now,
  }) {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    return SrsIntakeDecision(
      shouldEnrollOrReschedule: true,
      srsItemId: SrsIntakeRules.generateSrsItemId(contentId, contentType),
      contentId: contentId,
      contentType: contentType,
      targetState: 'relearning',
      scheduledDueAt: nowUtc, // Due immediately today!
      reason: 'exercise_failure_reinforcement',
    );
  }

  /// Determines whether an existing mastery state warrants intake.
  bool shouldIntakeForMastery(MasteryState state) {
    switch (state) {
      case MasteryState.unstable:
      case MasteryState.learning:
        return true;
      case MasteryState.familiar:
      case MasteryState.mastered:
      case MasteryState.exposed:
      case MasteryState.unseen:
        return false;
    }
  }
}
