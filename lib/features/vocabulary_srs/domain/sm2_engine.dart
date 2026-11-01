import 'dart:math' as math;
import 'srs_models.dart';

/// Configuration parameters for the SuperMemo 2 (SM-2) algorithm.
class Sm2Configuration {
  /// Strict mathematical minimum for Ease Factor as defined by Piotr Woźniak (1987).
  final double minEaseFactor;

  /// Safety ceiling for Ease Factor to prevent runaway exponential intervals.
  final double maxEaseFactor;

  /// Default starting Ease Factor for newly introduced cards.
  final double initialEaseFactor;

  /// Interval in days on first successful repetition (n = 1). Standard SM-2 is 1.
  final int firstIntervalDays;

  /// Interval in days on second successful repetition (n = 2). Standard SM-2 is 6.
  final int secondIntervalDays;

  /// Multiplier applied to previous interval when user marks [SrsRating.hard].
  final double hardIntervalMultiplier;

  /// Bonus multiplier applied when user marks [SrsRating.easy].
  final double easyBonusMultiplier;

  /// Threshold after which a card is classified as 'mastered'.
  final int masteryRepetitionThreshold;
  final int masteryIntervalThreshold;

  const Sm2Configuration({
    this.minEaseFactor = 1.3,
    this.maxEaseFactor = 5.0,
    this.initialEaseFactor = 2.5,
    this.firstIntervalDays = 1,
    this.secondIntervalDays = 6,
    this.hardIntervalMultiplier = 1.2,
    this.easyBonusMultiplier = 1.3,
    this.masteryRepetitionThreshold = 6,
    this.masteryIntervalThreshold = 90,
  });
}

/// Pure Dart implementation of the SuperMemo 2 (SM-2) algorithm.
/// Fully decoupled from Flutter UI, isolates, and database persistence.
class Sm2Engine {
  final Sm2Configuration config;

  const Sm2Engine({this.config = const Sm2Configuration()});

  /// Computes the updated Ease Factor (EF') according to the classical SM-2 formula:
  /// EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
  /// Clamped between [config.minEaseFactor] (1.3) and [config.maxEaseFactor] (5.0).
  double calculateNewEaseFactor(double currentEaseFactor, int quality) {
    final q = quality.clamp(0, 5);
    final factorDelta = 0.1 - (5 - q) * (0.08 + (5 - q) * 0.02);
    final calculated = currentEaseFactor + factorDelta;
    return calculated.clamp(config.minEaseFactor, config.maxEaseFactor);
  }

  /// Calculates the next [SrsCardState] given an existing state and a UI [SrsRating].
  SrsReviewResult calculateNextState({
    required SrsCardState currentState,
    required SrsRating rating,
    DateTime? reviewTime,
  }) {
    return calculateNextStateFromQuality(
      currentState: currentState,
      quality: rating.quality,
      reviewTime: reviewTime,
      explicitRating: rating,
    );
  }

  /// Core pure calculation accepting raw quality (0..5).
  SrsReviewResult calculateNextStateFromQuality({
    required SrsCardState currentState,
    required int quality,
    DateTime? reviewTime,
    SrsRating? explicitRating,
  }) {
    final nowUtc = (reviewTime ?? DateTime.now()).toUtc();
    final q = quality.clamp(0, 5);
    final rating = explicitRating ?? SrsRating.fromQuality(q);

    final prevInterval = currentState.intervalDays;
    final prevEf = currentState.easeFactor;
    final prevReps = currentState.repetitions;
    final prevLapses = currentState.lapses;

    // 1. Calculate new Ease Factor
    final newEf = calculateNewEaseFactor(prevEf, q);

    int newReps;
    int newLapses;
    int newInterval;
    SrsItemState newState;

    if (q < 3) {
      // Recall Failure (Again)
      newReps = 0;
      newLapses = prevLapses + 1;
      newInterval = 1; // Reset to 1 day
      newState = (currentState.state == SrsItemState.newCard)
          ? SrsItemState.learning
          : SrsItemState.relearning;
    } else {
      // Recall Success (Hard, Good, Easy)
      newReps = prevReps + 1;
      newLapses = prevLapses;

      if (prevReps == 0) {
        // First successful review (n = 1)
        if (rating == SrsRating.easy) {
          newInterval = 3; // Easy jumpstart bonus
        } else {
          newInterval = config.firstIntervalDays; // 1 day
        }
      } else if (prevReps == 1) {
        // Second successful review (n = 2)
        if (rating == SrsRating.hard) {
          newInterval = 3;
        } else if (rating == SrsRating.easy) {
          newInterval = (config.secondIntervalDays * config.easyBonusMultiplier).round(); // ~8 days
        } else {
          newInterval = config.secondIntervalDays; // 6 days
        }
      } else {
        // Subsequent reviews (n >= 3)
        if (rating == SrsRating.hard) {
          // Hard: minimal progression (at least +1 day or 1.2x)
          final scaled = (prevInterval * config.hardIntervalMultiplier).round();
          newInterval = math.max(prevInterval + 1, scaled);
        } else if (rating == SrsRating.easy) {
          // Easy: full EF progression with bonus multiplier
          final scaled = (prevInterval * newEf * config.easyBonusMultiplier).round();
          newInterval = math.max(prevInterval + 2, scaled);
        } else {
          // Good: canonical SM-2 formula I(n) = round(I(n-1) * EF)
          final scaled = (prevInterval * newEf).round();
          newInterval = math.max(prevInterval + 1, scaled);
        }
      }

      // Check mastery transition
      if (newReps >= config.masteryRepetitionThreshold &&
          newInterval >= config.masteryIntervalThreshold) {
        newState = SrsItemState.mastered;
      } else {
        newState = SrsItemState.review;
      }
    }

    // Calculate scheduled due date cleanly in UTC
    final scheduledDueAt = nowUtc.add(Duration(days: newInterval));

    final nextCardState = currentState.copyWith(
      state: newState,
      intervalDays: newInterval,
      easeFactor: newEf,
      repetitions: newReps,
      lapses: newLapses,
      dueAt: scheduledDueAt,
      lastReviewedAt: nowUtc,
      updatedAt: nowUtc,
    );

    return SrsReviewResult(
      nextState: nextCardState,
      rating: rating,
      quality: q,
      previousIntervalDays: prevInterval,
      newIntervalDays: newInterval,
      previousEaseFactor: prevEf,
      newEaseFactor: newEf,
      reviewTime: nowUtc,
      scheduledDueAt: scheduledDueAt,
    );
  }

  /// Determines whether a card is currently due for review.
  bool isDue(SrsCardState state, {DateTime? now}) {
    final currentTime = (now ?? DateTime.now()).toUtc();
    return !state.dueAt.isAfter(currentTime);
  }

  /// Number of whole days a card is overdue (0 if not overdue).
  int daysOverdue(SrsCardState state, {DateTime? now}) {
    final currentTime = (now ?? DateTime.now()).toUtc();
    if (!isDue(state, now: currentTime)) return 0;
    return currentTime.difference(state.dueAt).inDays;
  }

  /// Previews scheduled intervals for all 4 ratings without side effects.
  Map<SrsRating, int> previewIntervals(SrsCardState currentState, {DateTime? reviewTime}) {
    return {
      SrsRating.again: calculateNextState(
        currentState: currentState,
        rating: SrsRating.again,
        reviewTime: reviewTime,
      ).newIntervalDays,
      SrsRating.hard: calculateNextState(
        currentState: currentState,
        rating: SrsRating.hard,
        reviewTime: reviewTime,
      ).newIntervalDays,
      SrsRating.good: calculateNextState(
        currentState: currentState,
        rating: SrsRating.good,
        reviewTime: reviewTime,
      ).newIntervalDays,
      SrsRating.easy: calculateNextState(
        currentState: currentState,
        rating: SrsRating.easy,
        reviewTime: reviewTime,
      ).newIntervalDays,
    };
  }

  /// Formats interval in days into a user-friendly Vietnamese explanation for the rating buttons.
  static String formatIntervalExplanation(SrsRating rating, int days) {
    if (rating == SrsRating.again) {
      return '< 10 phút';
    }
    if (days <= 1) {
      return '1 ngày';
    }
    if (days < 30) {
      return '$days ngày';
    }
    final months = (days / 30).round();
    return '$months tháng';
  }
}
