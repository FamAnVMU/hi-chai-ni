import '../models/learning_evidence.dart';
import '../models/mastery_state.dart';

/// Pure domain evaluation engine that calculates a knowledge item's cognitive mastery state
/// strictly from its accumulated immutable learning evidence history.
class MasteryEvaluator {
  const MasteryEvaluator();

  /// Evaluates evidence chronologically and computes the resulting [MasteryState].
  MasteryState evaluate({
    required List<LearningEvidence> evidenceHistory,
    MasteryState currentState = MasteryState.unseen,
  }) {
    if (evidenceHistory.isEmpty) {
      return currentState == MasteryState.unseen ? MasteryState.unseen : currentState;
    }

    // Sort evidence by createdAt ascending to trace cognitive trajectory
    final sorted = List<LearningEvidence>.from(evidenceHistory)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // 1. Check if the most recent high-stakes attempt was an outright failure
    final latestAttempt = sorted.lastWhere(
      (e) =>
          e.activityType == ActivityType.application ||
          e.activityType == ActivityType.recall ||
          e.activityType == ActivityType.retention ||
          e.activityType == ActivityType.recognition,
      orElse: () => sorted.last,
    );

    final isLatestFailed = !latestAttempt.isSuccess || latestAttempt.score < 0.6;
    if (isLatestFailed &&
        (latestAttempt.activityType == ActivityType.application ||
            latestAttempt.activityType == ActivityType.retention ||
            latestAttempt.activityType == ActivityType.recall)) {
      return MasteryState.unstable;
    }

    // 2. Count successful events across categories
    int successfulApplications = 0;
    int successfulRetentions = 0;
    bool hasInstruction = false;
    bool hasExposure = false;

    for (final ev in sorted) {
      if (ev.activityType == ActivityType.instruction) {
        hasInstruction = true;
      } else if (ev.activityType == ActivityType.exposure) {
        hasExposure = true;
      }

      if (ev.isSuccess && ev.score >= 0.75) {
        if (ev.activityType == ActivityType.application ||
            ev.activityType == ActivityType.recognition ||
            ev.activityType == ActivityType.recall) {
          successfulApplications++;
        } else if (ev.activityType == ActivityType.retention) {
          // Verify spaced interval if available in metadata
          final newInterval = (ev.metadata['new_interval'] as num?)?.toInt() ?? 0;
          final quality = (ev.metadata['quality'] as num?)?.toInt() ?? 0;
          if (newInterval >= 5 || quality >= 4) {
            successfulRetentions++;
          } else {
            successfulApplications++;
          }
        }
      }
    }

    // 3. Evaluate state progression
    // MASTERED requires proven spaced retention + foundational application mastery
    if (successfulRetentions >= 1 && (successfulApplications >= 1 || successfulRetentions >= 2)) {
      return MasteryState.mastered;
    }

    // FAMILIAR requires repeated successful applications
    if (successfulApplications >= 2 || (successfulApplications >= 1 && successfulRetentions >= 1)) {
      return MasteryState.familiar;
    }

    // LEARNING if instructed or started initial practice
    if (hasInstruction || successfulApplications >= 1) {
      return MasteryState.learning;
    }

    // EXPOSED if only seen in dialogue or reading
    if (hasExposure) {
      return MasteryState.exposed;
    }

    return MasteryState.unseen;
  }
}
