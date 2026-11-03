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
        : (utcDateTime.isUtc ? utcDateTime.toLocal() : utcDateTime);
    return DateTime(local.year, local.month, local.day);
  }

  static String toDateString(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  LearningStreak calculate({
    required Iterable<DateTime> meaningfulEventTimesUtc,
    Iterable<DateTime>? meaningfulLocalDates,
    DateTime? referenceTimeUtc,
    Duration? timeZoneOffset,
    int todayDurationSeconds = 0,
    int todayItemsCompleted = 0,
  }) {
    final hasUtcEvents = meaningfulEventTimesUtc.isNotEmpty;
    final hasLocalDates = meaningfulLocalDates != null && meaningfulLocalDates.isNotEmpty;

    if (!hasUtcEvents && !hasLocalDates) {
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
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    final activeDays = <DateTime>{};
    if (meaningfulLocalDates != null && meaningfulLocalDates.isNotEmpty) {
      for (final localDate in meaningfulLocalDates) {
        activeDays.add(DateTime(localDate.year, localDate.month, localDate.day));
      }
    } else {
      for (final eventUtc in meaningfulEventTimesUtc) {
        activeDays.add(toLocalDate(eventUtc, timeZoneOffset: timeZoneOffset));
      }
    }

    final hasStudiedToday = activeDays.contains(today);

    int currentStreak = 0;
    if (hasStudiedToday) {
      currentStreak = 1;
      var checkDate = DateTime(today.year, today.month, today.day - 1);
      while (activeDays.contains(checkDate)) {
        currentStreak++;
        checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
      }
    } else if (activeDays.contains(yesterday)) {
      currentStreak = 1;
      var checkDate = DateTime(yesterday.year, yesterday.month, yesterday.day - 1);
      while (activeDays.contains(checkDate)) {
        currentStreak++;
        checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
      }
    } else {
      currentStreak = 0;
    }

    final bestStreak = _calculateBestStreak(activeDays);

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

  int _calculateBestStreak(Set<DateTime> activeDays) {
    if (activeDays.isEmpty) return 0;
    final sorted = activeDays.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()..sort();

    int maxStreak = 1;
    int currentRun = 1;

    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];

      final expectedNext = DateTime(prev.year, prev.month, prev.day + 1);
      if (curr == expectedNext) {
        currentRun++;
        if (currentRun > maxStreak) {
          maxStreak = currentRun;
        }
      } else if (curr.isAfter(expectedNext)) {
        currentRun = 1;
      }
    }

    return maxStreak;
  }
}
