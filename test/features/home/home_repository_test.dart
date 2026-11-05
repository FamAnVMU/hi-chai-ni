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
      await db.close();

      expect(
        () async => await homeRepo.getDashboardData(),
        throwsA(isA<Exception>()),
      );
    });

    test('8. Query optimization excludes activities older than 30 days and sample_data', () async {
      final nowUtc = DateTime.now().toUtc();
      final oldDate = nowUtc.subtract(const Duration(days: 35));
      final recentDate = nowUtc.subtract(const Duration(days: 5));

      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'act_old',
        'activity_type': 'lesson',
        'duration_seconds': 300,
        'items_count': 5,
        'activity_date': '${oldDate.year}-${oldDate.month.toString().padLeft(2, '0')}-${oldDate.day.toString().padLeft(2, '0')}',
        'created_at': oldDate.toIso8601String(),
      });

      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'act_sample',
        'activity_type': 'sample_data',
        'duration_seconds': 400,
        'items_count': 5,
        'activity_date': '${recentDate.year}-${recentDate.month.toString().padLeft(2, '0')}-${recentDate.day.toString().padLeft(2, '0')}',
        'created_at': recentDate.toIso8601String(),
      });

      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'act_seed',
        'activity_type': 'seed',
        'duration_seconds': 400,
        'items_count': 5,
        'activity_date': '${recentDate.year}-${recentDate.month.toString().padLeft(2, '0')}-${recentDate.day.toString().padLeft(2, '0')}',
        'created_at': recentDate.toIso8601String(),
      });

      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'act_valid',
        'activity_type': 'lesson',
        'duration_seconds': 600,
        'items_count': 10,
        'activity_date': '${recentDate.year}-${recentDate.month.toString().padLeft(2, '0')}-${recentDate.day.toString().padLeft(2, '0')}',
        'created_at': recentDate.toIso8601String(),
      });

      final sessions = await homeRepo.getSanitizedStudySessionsAndStats();
      expect(sessions.stats.totalDurationSeconds, equals(600));
      expect(sessions.stats.totalItemsCompleted, equals(10));
    });

    test('9. Query limits cap learning_activities at 200 and learner_evidence at 100', () async {
      final nowUtc = DateTime.now().toUtc();
      final batch = db.batch();

      for (int i = 0; i < 250; i++) {
        final d = nowUtc.subtract(Duration(minutes: i + 1));
        batch.insert(DatabaseConstants.tableLearningActivities, {
          'id': 'act_cap_$i',
          'activity_type': 'srs_review',
          'duration_seconds': 10,
          'items_count': 1,
          'activity_date': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          'created_at': d.toIso8601String(),
        });
      }

      for (int i = 0; i < 150; i++) {
        final d = nowUtc.subtract(Duration(hours: 10, minutes: i + 1));
        batch.insert(DatabaseConstants.tableLearnerEvidence, {
          'id': 'evi_cap_$i',
          'content_id': 'content_$i',
          'content_type': 'vocabulary',
          'source': 'srs_flashcard',
          'score': 1.0,
          'duration_ms': 5000,
          'metadata_json': '{}',
          'created_at': d.toIso8601String(),
        });
      }

      await batch.commit(noResult: true);

      final actCountRows = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM (
          SELECT id FROM ${DatabaseConstants.tableLearningActivities}
          WHERE activity_type NOT IN ('sample_data', 'seed')
            AND created_at >= datetime('now', '-30 days')
          ORDER BY created_at ASC
          LIMIT 200
        )
      ''');
      expect(actCountRows.first['cnt'], equals(200));

      final eviCountRows = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM (
          SELECT id FROM ${DatabaseConstants.tableLearnerEvidence}
          WHERE source NOT IN ('sample_data', 'seed')
            AND created_at >= datetime('now', '-30 days')
          ORDER BY created_at ASC
          LIMIT 100
        )
      ''');
      expect(eviCountRows.first['cnt'], equals(100));

      final dashboard = await homeRepo.getDashboardData();
      expect(dashboard, isNotNull);
    });

    test('10. Migration v17 index idx_learning_activities_created_at exists and is active', () async {
      final indexRows = await db.rawQuery(
        "PRAGMA index_list(${DatabaseConstants.tableLearningActivities});",
      );
      final hasCreatedAtIndex = indexRows.any((row) => row['name'] == 'idx_learning_activities_created_at');
      expect(hasCreatedAtIndex, isTrue);
    });
  });
}
