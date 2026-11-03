import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/dao/activity_dao.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/core/database/migrations/timezone_data_migrator.dart';
import 'package:hi_chinese/core/utils/app_clock.dart';
import 'package:hi_chinese/features/hanzi_writing/data/hanzi_writing_repository.dart';
import 'package:hi_chinese/features/hanzi_writing/domain/models/stroke_models.dart';
import 'package:hi_chinese/features/home/data/home_repository.dart';
import 'package:hi_chinese/features/home/domain/models/learning_streak.dart';
import 'package:hi_chinese/features/roadmap/data/roadmap_repository.dart';
import 'package:hi_chinese/features/vocabulary_srs/data/srs_repository.dart';
import 'package:hi_chinese/features/vocabulary_srs/domain/srs_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  const vnOffset = Duration(hours: 7);
  const calculator = StreakCalculator();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    AppClock.reset();
  });

  group('AppClock Local Timezone & Date Formatting Tests', () {
    test('1. Early morning in Vietnam (00:00 to 06:59) produces correct local date', () {
      final checkpoints = [
        (DateTime.utc(2026, 11, 2, 17, 0), '00:00', '2026-11-03'),
        (DateTime.utc(2026, 11, 2, 18, 0), '01:00', '2026-11-03'),
        (DateTime.utc(2026, 11, 2, 20, 0), '03:00', '2026-11-03'),
        (DateTime.utc(2026, 11, 2, 23, 59), '06:59', '2026-11-03'),
      ];

      for (final (utcTime, localDesc, expectedLocalDate) in checkpoints) {
        AppClock.setMockClock(now: utcTime.add(vnOffset), timeZoneOffset: vnOffset);

        final localDateStr = AppClock.toLocalDateString(utcTime, timeZoneOffset: vnOffset);
        expect(
          localDateStr,
          expectedLocalDate,
          reason: 'Failed at VN $localDesc ($utcTime UTC)',
        );

        final todayStr = AppClock.todayLocalDateString(timeZoneOffset: vnOffset);
        expect(
          todayStr,
          expectedLocalDate,
          reason: 'Failed todayLocalDateString at VN $localDesc',
        );
      }
    });

    test('2. Daytime & Late evening in Vietnam (07:00 and 23:59) produces correct local date', () {
      final checkpoints = [
        (DateTime.utc(2026, 11, 3, 0, 0), '07:00', '2026-11-03'),
        (DateTime.utc(2026, 11, 3, 5, 0), '12:00', '2026-11-03'),
        (DateTime.utc(2026, 11, 3, 16, 59), '23:59', '2026-11-03'),
      ];

      for (final (utcTime, localDesc, expectedLocalDate) in checkpoints) {
        final localDateStr = AppClock.toLocalDateString(utcTime, timeZoneOffset: vnOffset);
        expect(
          localDateStr,
          expectedLocalDate,
          reason: 'Failed at VN $localDesc ($utcTime UTC)',
        );
      }
    });

    test('3. Day transition at midnight boundary evaluates cleanly', () {
      final day1EndUtc = DateTime.utc(2026, 11, 2, 16, 59);
      final day2StartUtc = DateTime.utc(2026, 11, 2, 17, 1);

      expect(AppClock.toLocalDateString(day1EndUtc, timeZoneOffset: vnOffset), '2026-11-02');
      expect(AppClock.toLocalDateString(day2StartUtc, timeZoneOffset: vnOffset), '2026-11-03');
    });
  });

  group('StreakCalculator Multi-Day & Timezone Tests', () {
    test('1. Early morning study at 01:00 AM in VN credits current local day', () {
      final studyUtc = DateTime.utc(2026, 11, 2, 18, 0);
      final evalUtc = DateTime.utc(2026, 11, 3, 3, 0);

      final result = calculator.calculate(
        meaningfulEventTimesUtc: [studyUtc],
        referenceTimeUtc: evalUtc,
        timeZoneOffset: vnOffset,
      );

      expect(result.currentStreak, 1);
      expect(result.bestStreak, 1);
      expect(result.hasStudiedToday, isTrue);
      expect(result.lastActiveDate, DateTime(2026, 11, 3));
    });

    test('2. Multiple sessions on the same local day (01:00, 06:30, 20:00) count as 1 day', () {
      final sessions = [
        DateTime.utc(2026, 11, 2, 18, 0),
        DateTime.utc(2026, 11, 2, 23, 30),
        DateTime.utc(2026, 11, 3, 13, 0),
      ];
      final evalUtc = DateTime.utc(2026, 11, 3, 15, 0);

      final result = calculator.calculate(
        meaningfulEventTimesUtc: sessions,
        referenceTimeUtc: evalUtc,
        timeZoneOffset: vnOffset,
      );

      expect(result.currentStreak, 1);
      expect(result.bestStreak, 1);
      expect(result.hasStudiedToday, isTrue);
    });

    test('3. Continuous 3-day streak with early morning sessions in VN (01:00 - 04:00)', () {
      final events = [
        DateTime.utc(2026, 10, 31, 18, 30),
        DateTime.utc(2026, 11, 1, 19, 0),
        DateTime.utc(2026, 11, 2, 20, 0),
      ];
      final evalUtc = DateTime.utc(2026, 11, 3, 5, 0);

      final result = calculator.calculate(
        meaningfulEventTimesUtc: events,
        referenceTimeUtc: evalUtc,
        timeZoneOffset: vnOffset,
      );

      expect(result.currentStreak, 3);
      expect(result.bestStreak, 3);
      expect(result.hasStudiedToday, isTrue);
    });

    test('4. Broken streak when skipping Nov 2 and evaluating on Nov 3', () {
      final events = [
        DateTime.utc(2026, 10, 31, 19, 0),
      ];
      final evalUtc = DateTime.utc(2026, 11, 3, 3, 0);

      final result = calculator.calculate(
        meaningfulEventTimesUtc: events,
        referenceTimeUtc: evalUtc,
        timeZoneOffset: vnOffset,
      );

      expect(result.currentStreak, 0);
      expect(result.bestStreak, 1);
      expect(result.hasStudiedToday, isFalse);
    });

    test('5. Direct local dates collection correctly powers streak without UTC shifts', () {
      final localDates = [
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 3),
      ];
      final evalUtc = DateTime.utc(2026, 11, 3, 4, 0);

      final result = calculator.calculate(
        meaningfulEventTimesUtc: const [],
        meaningfulLocalDates: localDates,
        referenceTimeUtc: evalUtc,
        timeZoneOffset: vnOffset,
      );

      expect(result.currentStreak, 3);
      expect(result.hasStudiedToday, isTrue);
    });
  });

  group('SQLite ActivityDao & HomeRepository Timezone Integration Tests', () {
    late Database db;
    late Directory tempDir;
    late ActivityDao activityDao;
    late HomeRepository homeRepo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_tz_test_');
      final dbPath = '${tempDir.path}/test_tz.db';

      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: DatabaseConstants.currentDatabaseVersion,
          onCreate: (db, version) async {
            final engine = MigrationEngine();
            await engine.executeMigrations(db, 0, version);
          },
        ),
      );

      activityDao = ActivityDao(db);
      homeRepo = HomeRepository(db);
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Early morning activity at 01:00 AM VN persists local date and UTC created_at', () async {
      final studyUtc = DateTime.utc(2026, 11, 2, 18, 0);

      await homeRepo.logLearningActivity(
        activityType: 'vocabulary_srs',
        durationSeconds: 400,
        itemsCount: 8,
        activityTimeUtc: studyUtc,
        timeZoneOffset: vnOffset,
      );

      final rows = await activityDao.getActivitiesForDate('2026-11-03');
      expect(rows.length, 1);
      expect(rows.first['activity_date'], '2026-11-03');
      expect(rows.first['created_at'], '2026-11-02T18:00:00.000Z');
      expect(rows.first['timezone_offset_minutes'], 420);

      final duration = await activityDao.getTotalStudyDurationSeconds('2026-11-03');
      expect(duration, 400);

      final yesterdayRows = await activityDao.getActivitiesForDate('2026-11-02');
      expect(yesterdayRows.isEmpty, isTrue);
    });

    test('2. Multiple activities in VN morning and evening aggregate without streak inflation', () async {
      final morningUtc = DateTime.utc(2026, 11, 2, 18, 30);
      final eveningUtc = DateTime.utc(2026, 11, 3, 14, 0);

      await homeRepo.logLearningActivity(
        activityType: 'hanzi_writing',
        durationSeconds: 300,
        itemsCount: 5,
        activityTimeUtc: morningUtc,
        timeZoneOffset: vnOffset,
      );

      await homeRepo.logLearningActivity(
        activityType: 'grammar',
        durationSeconds: 600,
        itemsCount: 10,
        activityTimeUtc: eveningUtc,
        timeZoneOffset: vnOffset,
      );

      final stats = await homeRepo.getStudyTimeStats(
        evaluationTime: DateTime.utc(2026, 11, 3, 15, 0),
        timeZoneOffset: vnOffset,
      );

      expect(stats.todayDurationSeconds, 900);
      expect(stats.todayItemsCompleted, 15);

      final streak = await homeRepo.calculateStreak(
        evaluationTime: DateTime.utc(2026, 11, 3, 15, 0),
        timeZoneOffset: vnOffset,
      );

      expect(streak.currentStreak, 1);
      expect(streak.hasStudiedToday, isTrue);
    });

    test('3. Cross-repository recording at 02:00 AM VN saves accurate local date', () async {
      final studyUtc = DateTime.utc(2026, 11, 2, 19, 0);
      AppClock.setMockClock(now: studyUtc.add(vnOffset), timeZoneOffset: vnOffset);

      final hanziRepo = HanziWritingRepository(db);
      await hanziRepo.recordWritingSession(
        character: '中',
        evaluation: const WritingEvaluationResult(
          strokeOrderAccuracy: 0.9,
          correctStrokeCount: 4,
          totalStandardStrokes: 4,
          userDrawnStrokesCount: 4,
          isTracingMode: false,
          strokeFeedbackList: [],
          overallVerdict: 'Tốt',
          hasStandardStrokeData: true,
        ),
        durationMs: 12000,
        timestamp: studyUtc,
        timeZoneOffset: vnOffset,
      );

      final srsRepo = SrsRepository(db, debounceCooldownMs: 0);
      await srsRepo.recordReviewAndProgress(
        item: SrsFlashcardItem(
          id: 'voc_test_01',
          simplified: '好',
          pinyin: 'hǎo',
          meaningVi: 'Tốt',
          hskLevel: 1,
          srsState: SrsCardState.newCard(id: 'srs_voc_test_01', contentId: 'voc_test_01'),
          estimatedIntervalDays: const {SrsRating.good: 3},
        ),
        rating: SrsRating.good,
        durationMs: 5000,
        reviewTime: studyUtc,
        timeZoneOffset: vnOffset,
      );

      final roadmapRepo = DefaultRoadmapRepository(db);
      await roadmapRepo.completeLesson(lessonId: 'c_hsk1_l1', score: 0.9);

      final dates = await activityDao.getDistinctActiveDates();
      expect(dates, contains('2026-11-03'));
      expect(dates.contains('2026-11-02'), isFalse);
    });

    test('4. TimezoneDataMigrator safely audits and backfills affected records', () async {
      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'legacy_act_001',
        'activity_type': 'lesson',
        'duration_seconds': 600,
        'items_count': 5,
        'activity_date': '2026-11-02',
        'created_at': '2026-11-02T19:00:00.000Z',
      });

      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'legacy_act_002',
        'activity_type': 'lesson',
        'duration_seconds': 600,
        'items_count': 5,
        'activity_date': '2026-11-02',
        'created_at': '2026-11-02T05:00:00.000Z',
      });

      const migrator = TimezoneDataMigrator();
      final report = await migrator.auditHistoricalActivities(db, assumedOffset: vnOffset);

      expect(report.totalRecords, 2);
      expect(report.potentiallyShiftedRecords, 1);
      expect(report.shiftedActivityIds, ['legacy_act_001']);

      final backfilled = await migrator.backfillWithVerifiedTimezone(db, verifiedOffset: vnOffset);
      expect(backfilled, 1);

      final row = (await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'id = ?',
        whereArgs: ['legacy_act_001'],
      )).first;
      expect(row['activity_date'], '2026-11-03');
      expect(row['created_at'], '2026-11-02T19:00:00.000Z');
      expect(row['timezone_offset_minutes'], 420);
    });
  });
}
