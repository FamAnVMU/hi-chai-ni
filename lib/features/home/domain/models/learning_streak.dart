import 'package:flutter/foundation.dart';

/// Represents a learner's continuous study streak state and daily engagement.
@immutable
class LearningStreak {
  /// Current continuous days of study.
  final int currentStreak;

  /// All-time personal best streak in days.
  final int bestStreak;

  /// Whether the learner has completed any meaningful learning activity today in local time.
  final bool hasStudiedToday;

  /// The most recent calendar date on which a meaningful activity occurred (local date).
  final DateTime? lastActiveDate;

  /// Total duration in seconds spent studying today (meaningful activities only).
  final int todayDurationSeconds;

  /// Number of distinct learning items/reviews completed today.
  final int todayItemsCompleted;

  const LearningStreak({
    required this.currentStreak,
    required this.bestStreak,
    required this.hasStudiedToday,
    this.lastActiveDate,
    this.todayDurationSeconds = 0,
    this.todayItemsCompleted = 0,
  });

  /// Initial zero streak for a brand new learner.
  factory LearningStreak.empty() => const LearningStreak(
        currentStreak: 0,
        bestStreak: 0,
        hasStudiedToday: false,
        todayDurationSeconds: 0,
        todayItemsCompleted: 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningStreak &&
          runtimeType == other.runtimeType &&
          currentStreak == other.currentStreak &&
          bestStreak == other.bestStreak &&
          hasStudiedToday == other.hasStudiedToday &&
          lastActiveDate == other.lastActiveDate &&
          todayDurationSeconds == other.todayDurationSeconds &&
          todayItemsCompleted == other.todayItemsCompleted;

  @override
  int get hashCode => Object.hash(
        currentStreak,
        bestStreak,
        hasStudiedToday,
        lastActiveDate,
        todayDurationSeconds,
        todayItemsCompleted,
      );

  @override
  String toString() =>
      'LearningStreak(current: $currentStreak, best: $bestStreak, studiedToday: $hasStudiedToday, todayDurationSec: $todayDurationSeconds, todayItems: $todayItemsCompleted)';
}

/// Standalone, pure-Dart timezone-aware streak calculator.
///
/// Rules:
/// 1. Only meaningful learning events (duration > 0 or items >= 1 or score recorded) count.
/// 2. Mere app launch is NOT an activity and never increases the streak.
/// 3. Sample / seed data is strictly excluded.
/// 4. Day boundaries are evaluated in the learner's local timezone.
/// 5. Midnight crossover: An event at 23:55 (Day 1) and 00:05 (Day 2) credits both Day 1 and Day 2.
/// 6. If today has no activity yet, but yesterday was active, the streak is maintained (not broken)
///    until midnight passes without study.
class StreakCalculator {
  const StreakCalculator();

  /// Converts a UTC timestamp into a calendar date (midnight `00:00:00`) in the local timezone.
  /// If [timeZoneOffset] is provided, uses that specific offset; otherwise uses [DateTime.toLocal].
  static DateTime toLocalDate(DateTime utcDateTime, {Duration? timeZoneOffset}) {
    final local = timeZoneOffset != null
        ? utcDateTime.toUtc().add(timeZoneOffset)
        : utcDateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Calculates the [LearningStreak] from a collection of meaningful UTC event timestamps.
  ///
  /// [meaningfulEventTimesUtc]: List of UTC timestamps of genuine learning activities.
  /// [referenceTimeUtc]: The evaluation timestamp (defaults to `DateTime.now().toUtc()`).
  /// [timeZoneOffset]: Optional local timezone offset. If omitted, uses system local time.
  /// [todayDurationSeconds]: Aggregated seconds of study today.
  /// [todayItemsCompleted]: Aggregated items/reviews completed today.
  LearningStreak calculate({
    required Iterable<DateTime> meaningfulEventTimesUtc,
    DateTime? referenceTimeUtc,
    Duration? timeZoneOffset,
    int todayDurationSeconds = 0,
    int todayItemsCompleted = 0,
  }) {
    if (meaningfulEventTimesUtc.isEmpty) {
      return LearningStreak(
        currentStreak: 0,
        bestStreak: 0,
        hasStudiedToday: false,
        todayDurationSeconds: todayDurationSeconds,
        todayItemsCompleted: todayItemsCompleted,
      );
    }

    final refUtc = referenceTimeUtc ?? DateTime.now().toUtc();
    final today = toLocalDate(refUtc, timeZoneOffset: timeZoneOffset);
    final yesterday = today.subtract(const Duration(days: 1));

    // Map each UTC event to its local calendar day
    final activeDays = <DateTime>{};
    for (final eventUtc in meaningfulEventTimesUtc) {
      activeDays.add(toLocalDate(eventUtc, timeZoneOffset: timeZoneOffset));
    }

    final hasStudiedToday = activeDays.contains(today);

    // Calculate current streak
    int currentStreak = 0;
    if (hasStudiedToday) {
      // User studied today: count today and consecutive past days
      currentStreak = 1;
      var checkDate = today.subtract(const Duration(days: 1));
      while (activeDays.contains(checkDate)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    } else if (activeDays.contains(yesterday)) {
      // User hasn't studied today, but studied yesterday: streak is alive
      currentStreak = 1;
      var checkDate = yesterday.subtract(const Duration(days: 1));
      while (activeDays.contains(checkDate)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    } else {
      // Both today and yesterday have no activity -> streak broken
      currentStreak = 0;
    }

    // Calculate all-time best streak
    final bestStreak = _calculateBestStreak(activeDays);

    // Find the latest active calendar day
    DateTime? lastActive;
    for (final d in activeDays) {
      if (lastActive == null || d.isAfter(lastActive)) {
        lastActive = d;
      }
    }

    return LearningStreak(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      hasStudiedToday: hasStudiedToday,
      lastActiveDate: lastActive,
      todayDurationSeconds: todayDurationSeconds,
      todayItemsCompleted: todayItemsCompleted,
    );
  }

  /// Calculates the maximum number of consecutive active calendar days across all history.
  int _calculateBestStreak(Set<DateTime> activeDays) {
    if (activeDays.isEmpty) return 0;
    final sorted = activeDays.toList()..sort();

    int maxStreak = 1;
    int currentRun = 1;

    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];

      // Difference in days between calendar dates
      final diff = curr.difference(prev).inDays;
      if (diff == 1) {
        currentRun++;
        if (currentRun > maxStreak) {
          maxStreak = currentRun;
        }
      } else if (diff > 1) {
        currentRun = 1;
      }
      // diff == 0 should not occur in a Set, but safe if it does
    }

    return maxStreak;
  }
}
