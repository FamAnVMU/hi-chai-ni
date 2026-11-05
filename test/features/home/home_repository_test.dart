import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/home/data/home_repository.dart';
import 'package:hi_chinese/features/home/domain/models/home_dashboard_data.dart';
import 'package:hi_chinese/features/vocabulary_srs/data/srs_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late SrsRepository srsRepo;
  late HomeRepository homeRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hi_chinese_home_repo_test_');
    final dbPath = '${tempDir.path}/home_repo_test.db';

    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseConstants.currentDatabaseVersion,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON;');
          final engine = MigrationEngine();
          await engine.executeMigrations(db, 0, version);
        },
      ),
    );

    srsRepo = SrsRepository(db, debounceCooldownMs: 0);
    homeRepo = HomeRepository(db, srsRepository: srsRepo);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HomeRepository Live SQLite Tests', () {
    test('1. New learner empty state returns zero streak, zero due cards, and empty recent activities', () async {
      final data = await homeRepo.getDashboardData(
        evaluationTime: DateTime.utc(2026, 11, 1, 10, 0),
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(data.streak.currentStreak, 0);
      expect(data.streak.bestStreak, 0);
      expect(data.streak.hasStudiedToday, isFalse);
      expect(data.srsDueCount, 0);
      expect(data.roadmap.learnedVocabCount, 0);
      expect(data.roadmap.masteredVocabCount, 0);
      expect(data.recentActivities, isEmpty);
      expect(data.greeting, isNotEmpty);
      expect(data.hasCompletedLessons, isFalse);
    });

    test('1b. When a lesson is marked completed in curriculum_lessons, hasCompletedLessons is true', () async {
      final nowIso = DateTime.utc(2026, 11, 1, 9, 0).toIso8601String();
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'pack_hsk1',
        'hsk_level': 1,
        'title': 'HSK 1',
        'version': '1.0.0',
        'status': 'installed',
        'updated_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_hsk1',
        'pack_id': 'pack_hsk1',
        'code': 'HSK1',
        'standard_name': 'HSK 1 Standard',
        'hsk_level': 1,
        'created_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableCurriculumUnits, {
        'id': 'UNIT_001',
        'curriculum_id': 'curr_hsk1',
        'order_index': 1,
        'title_vi': 'Unit 1: Chào hỏi',
        'title_zh': '第一单元：问候',
        'created_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableCurriculumLessons, {
        'id': 'LESSON_001',
        'unit_id': 'UNIT_001',
        'order_index': 1,
        'title_vi': 'Bài 1: Chào hỏi',
        'title_zh': '第一课：你好',
        'pinyin': 'Nǐ hǎo',
        'status': 'completed',
        'is_locked': 0,
        'completed_at': nowIso,
        'created_at': nowIso,
      });

      final data = await homeRepo.getDashboardData(
        evaluationTime: DateTime.utc(2026, 11, 1, 10, 0),
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(data.hasCompletedLessons, isTrue);
    });

    test('2. Real SRS items due today are accurately counted and returned', () async {
      final nowUtc = DateTime.utc(2026, 11, 1, 8, 0);

      // Insert 2 vocabularies and SRS states due before now
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'VOCAB_001',
        'simplified': '你好',
        'pinyin': 'nǐ hǎo',
        'hsk_level': 1,
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'VOCAB_002',
        'simplified': '谢谢',
        'pinyin': 'xièxie',
        'hsk_level': 1,
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      // Item 1: due 1 hour ago
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'SRS_VOCAB_001',
        'content_id': 'VOCAB_001',
        'content_type': 'vocabulary',
        'state': 'review',
        'interval_days': 1,
        'ease_factor': 2.5,
        'repetitions': 1,
        'lapses': 0,
        'due_at': nowUtc.subtract(const Duration(hours: 1)).toIso8601String(),
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      // Item 2: due in 2 days (NOT due today)
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'SRS_VOCAB_002',
        'content_id': 'VOCAB_002',
        'content_type': 'vocabulary',
        'state': 'review',
        'interval_days': 2,
        'ease_factor': 2.5,
        'repetitions': 1,
        'lapses': 0,
        'due_at': nowUtc.add(const Duration(days: 2)).toIso8601String(),
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      final data = await homeRepo.getDashboardData(
        evaluationTime: nowUtc,
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(data.srsDueCount, 1); // Only VOCAB_001 is due
    });

    test('3. Meaningful activity logging increments streak and updates today stats', () async {
      final nowUtc = DateTime.utc(2026, 11, 1, 8, 0); // 15:00 GMT+7

      // Log a genuine 15-minute lesson activity
      await homeRepo.logLearningActivity(
        activityType: 'lesson',
        durationSeconds: 900,
        itemsCount: 10,
        activityTimeUtc: nowUtc,
      );

      final streak = await homeRepo.calculateStreak(
        evaluationTime: nowUtc,
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(streak.currentStreak, 1);
      expect(streak.hasStudiedToday, isTrue);
      expect(streak.todayDurationSeconds, 900);
      expect(streak.todayItemsCompleted, 10);
    });

    test('4. Sample/seed data is strictly excluded from streak calculation and recent activities', () async {
      final nowUtc = DateTime.utc(2026, 11, 1, 8, 0);

      // Insert mock evidence with source 'sample_data'
      await db.insert(DatabaseConstants.tableLearnerEvidence, {
        'id': 'EVI_SAMPLE_001',
        'content_id': 'VOCAB_SAMPLE',
        'content_type': 'vocabulary',
        'source': 'sample_data',
        'score': 1.0,
        'duration_ms': 5000,
        'created_at': nowUtc.toIso8601String(),
      });

      final streak = await homeRepo.calculateStreak(
        evaluationTime: nowUtc,
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(streak.currentStreak, 0); // Excluded!
      expect(streak.hasStudiedToday, isFalse);

      final activities = await homeRepo.getRecentActivities();
      expect(activities, isEmpty); // Excluded!
    });

    test('5. Midnight crossover in SQLite properly credits both days to streak', () async {
      // Study at 23:55 on Oct 31 in GMT+7 (16:55 UTC)
      final event1Utc = DateTime.utc(2026, 10, 31, 16, 55);
      await homeRepo.logLearningActivity(
        activityType: 'srs_review',
        durationSeconds: 300,
        itemsCount: 5,
        activityTimeUtc: event1Utc,
      );

      // Study at 00:05 on Nov 1 in GMT+7 (17:05 UTC Oct 31)
      final event2Utc = DateTime.utc(2026, 10, 31, 17, 5);
      await homeRepo.logLearningActivity(
        activityType: 'srs_review',
        durationSeconds: 300,
        itemsCount: 5,
        activityTimeUtc: event2Utc,
      );

      final streak = await homeRepo.calculateStreak(
        evaluationTime: DateTime.utc(2026, 11, 1, 5, 0), // Midday Nov 1
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(streak.currentStreak, 2); // Both days credited
      expect(streak.bestStreak, 2);
      expect(streak.hasStudiedToday, isTrue);
    });

    test('6. Recent activities returns chronological items with relative formatting', () async {
      final nowUtc = DateTime.utc(2026, 11, 1, 10, 0);

      await homeRepo.logLearningActivity(
        activityType: 'ai_tutor',
        durationSeconds: 600,
        itemsCount: 1,
        activityTimeUtc: nowUtc.subtract(const Duration(minutes: 10)),
      );

      await homeRepo.logLearningActivity(
        activityType: 'srs_review',
        durationSeconds: 300,
        itemsCount: 8,
        activityTimeUtc: nowUtc.subtract(const Duration(minutes: 2)),
      );

      final activities = await homeRepo.getRecentActivities(limit: 5);

      expect(activities.length, 2);
      expect(activities[0].type, ActivityType.srsReview); // Most recent first
      expect(activities[1].type, ActivityType.aiTutor);
    });

    test('7. Database error propagation occurs cleanly when SQLite connection is closed', () async {
      await db.close(); // Force DB closed

      expect(
        () async => await homeRepo.getDashboardData(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
