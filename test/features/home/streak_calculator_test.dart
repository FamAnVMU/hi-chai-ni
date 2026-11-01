import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/home/domain/models/learning_streak.dart';

void main() {
  const calculator = StreakCalculator();

  group('StreakCalculator Pure Domain Logic Tests', () {
    test('1. Brand new learner with zero activities has 0 streak and hasStudiedToday false', () {
      final result = calculator.calculate(
        meaningfulEventTimesUtc: const [],
        referenceTimeUtc: DateTime.utc(2026, 11, 1, 10, 0),
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(result.currentStreak, 0);
      expect(result.bestStreak, 0);
      expect(result.hasStudiedToday, isFalse);
      expect(result.lastActiveDate, isNull);
    });

    test('2. Single activity today gives currentStreak 1, bestStreak 1, hasStudiedToday true', () {
      final todayUtc = DateTime.utc(2026, 11, 1, 3, 0); // 10:00 in GMT+7
      final result = calculator.calculate(
        meaningfulEventTimesUtc: [todayUtc],
        referenceTimeUtc: DateTime.utc(2026, 11, 1, 8, 0), // 15:00 in GMT+7
        timeZoneOffset: const Duration(hours: 7),
        todayDurationSeconds: 600,
        todayItemsCompleted: 15,
      );

      expect(result.currentStreak, 1);
      expect(result.bestStreak, 1);
      expect(result.hasStudiedToday, isTrue);
      expect(result.todayDurationSeconds, 600);
      expect(result.todayItemsCompleted, 15);
      expect(result.lastActiveDate, DateTime(2026, 11, 1));
    });

    test('3. Activity yesterday but none today preserves streak (not broken yet)', () {
      final yesterdayUtc = DateTime.utc(2026, 10, 31, 12, 0); // Oct 31 19:00 in GMT+7
      final result = calculator.calculate(
        meaningfulEventTimesUtc: [yesterdayUtc],
        referenceTimeUtc: DateTime.utc(2026, 11, 1, 3, 0), // Nov 1 10:00 in GMT+7
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(result.currentStreak, 1);
      expect(result.bestStreak, 1);
      expect(result.hasStudiedToday, isFalse);
      expect(result.lastActiveDate, DateTime(2026, 10, 31));
    });

    test('4. 5 consecutive days ending today gives streak 5 and hasStudiedToday true', () {
      final events = [
        DateTime.utc(2026, 10, 28, 5, 0),
        DateTime.utc(2026, 10, 29, 6, 0),
        DateTime.utc(2026, 10, 30, 7, 0),
        DateTime.utc(2026, 10, 31, 8, 0),
        DateTime.utc(2026, 11, 1, 2, 0),
      ];

      final result = calculator.calculate(
        meaningfulEventTimesUtc: events,
        referenceTimeUtc: DateTime.utc(2026, 11, 1, 10, 0),
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(result.currentStreak, 5);
      expect(result.bestStreak, 5);
      expect(result.hasStudiedToday, isTrue);
    });

    test('5. 5 consecutive days ending yesterday preserves streak 5 while awaiting study today', () {
      final events = [
        DateTime.utc(2026, 10, 27, 5, 0),
        DateTime.utc(2026, 10, 28, 6, 0),
        DateTime.utc(2026, 10, 29, 7, 0),
        DateTime.utc(2026, 10, 30, 8, 0),
        DateTime.utc(2026, 10, 31, 9, 0),
      ];

      final result = calculator.calculate(
        meaningfulEventTimesUtc: events,
        referenceTimeUtc: DateTime.utc(2026, 11, 1, 10, 0),
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(result.currentStreak, 5);
      expect(result.bestStreak, 5);
      expect(result.hasStudiedToday, isFalse);
    });

    test('6. Day skipped (missed yesterday and today) resets currentStreak to 0, preserves bestStreak', () {
      final events = [
        DateTime.utc(2026, 10, 27, 5, 0),
        DateTime.utc(2026, 10, 28, 6, 0),
        DateTime.utc(2026, 10, 29, 7, 0),
        // Missed Oct 30 and Oct 31!
      ];

      final result = calculator.calculate(
        meaningfulEventTimesUtc: events,
        referenceTimeUtc: DateTime.utc(2026, 11, 1, 10, 0), // Today is Nov 1
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(result.currentStreak, 0); // Broken streak
      expect(result.bestStreak, 3); // Record of 3 days preserved
      expect(result.hasStudiedToday, isFalse);
    });

    test('7. Midnight crossover (study session spanning 23:55 and 00:05) credits both calendar days', () {
      // Event 1 at 23:55 on Oct 31 (local GMT+7 is 16:55 UTC)
      final event1Utc = DateTime.utc(2026, 10, 31, 16, 55);
      // Event 2 at 00:05 on Nov 1 (local GMT+7 is 17:05 UTC on Oct 31)
      final event2Utc = DateTime.utc(2026, 10, 31, 17, 5);

      final result = calculator.calculate(
        meaningfulEventTimesUtc: [event1Utc, event2Utc],
        referenceTimeUtc: DateTime.utc(2026, 11, 1, 5, 0), // 12:00 PM Nov 1 GMT+7
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(result.currentStreak, 2); // Both Oct 31 and Nov 1 are credited
      expect(result.bestStreak, 2);
      expect(result.hasStudiedToday, isTrue);
    });

    test('8. Timezone handling correctly separates local days across different offsets', () {
      // Event at 2026-11-01 22:30:00 UTC
      final eventUtc = DateTime.utc(2026, 11, 1, 22, 30);

      // In GMT+7 (Vietnam): 2026-11-01 22:30 + 7h = 2026-11-02 05:30 -> Nov 2
      final dateVn = StreakCalculator.toLocalDate(
        eventUtc,
        timeZoneOffset: const Duration(hours: 7),
      );
      expect(dateVn, DateTime(2026, 11, 2));

      // In GMT-5 (New York): 2026-11-01 22:30 - 5h = 2026-11-01 17:30 -> Nov 1
      final dateNy = StreakCalculator.toLocalDate(
        eventUtc,
        timeZoneOffset: const Duration(hours: -5),
      );
      expect(dateNy, DateTime(2026, 11, 1));
    });

    test('9. Best streak across multiple gaps calculates the true maximum run', () {
      final events = [
        // Run 1: 2 days (Jan 1, 2)
        DateTime.utc(2026, 1, 1, 12, 0),
        DateTime.utc(2026, 1, 2, 12, 0),

        // Run 2: 4 days (Jan 10, 11, 12, 13)
        DateTime.utc(2026, 1, 10, 12, 0),
        DateTime.utc(2026, 1, 11, 12, 0),
        DateTime.utc(2026, 1, 12, 12, 0),
        DateTime.utc(2026, 1, 13, 12, 0),

        // Run 3: 3 days (Feb 1, 2, 3)
        DateTime.utc(2026, 2, 1, 12, 0),
        DateTime.utc(2026, 2, 2, 12, 0),
        DateTime.utc(2026, 2, 3, 12, 0),
      ];

      final result = calculator.calculate(
        meaningfulEventTimesUtc: events,
        referenceTimeUtc: DateTime.utc(2026, 2, 15, 12, 0),
        timeZoneOffset: Duration.zero,
      );

      expect(result.currentStreak, 0); // No recent activity in mid-Feb
      expect(result.bestStreak, 4); // Max run was 4 days
    });
  });
}
