import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/home/data/home_repository.dart';
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
    tempDir = await Directory.systemTemp.createTemp('hi_chinese_home_stats_test_');
    final dbPath = '${tempDir.path}/home_stats_test.db';

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

  group('Lỗi A – Tên người học động & Fallback Profile', () {
    test('1. Resolves learner display name from user_profiles table', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableUserProfiles, {
        'id': 'user_001',
        'display_name': 'Nguyễn Văn Minh',
        'current_hsk_level': 1,
        'target_hsk_level': 3,
        'purpose': 'daily_communication',
        'timeframe': 'standard',
        'daily_minutes': 30,
        'start_date': nowUtc,
        'interests_json': '[]',
        'avatar_style': 'panda',
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      final name = await homeRepo.getLearnerDisplayName();
      expect(name, 'Nguyễn Văn Minh');

      final dashboard = await homeRepo.getDashboardData();
      expect(dashboard.learnerName, 'Nguyễn Văn Minh');
    });

    test('2. Trims leading and trailing whitespace from user profile display name', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableUserProfiles, {
        'id': 'user_002',
        'display_name': '   Trần Thị Hoa   ',
        'current_hsk_level': 1,
        'target_hsk_level': 2,
        'purpose': 'travel',
        'timeframe': 'standard',
        'daily_minutes': 20,
        'start_date': nowUtc,
        'interests_json': '[]',
        'avatar_style': 'dragon',
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      final name = await homeRepo.getLearnerDisplayName();
      expect(name, 'Trần Thị Hoa');
    });

    test('3. Falls back to app_settings when user_profiles has empty or whitespace-only name', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableUserProfiles, {
        'id': 'user_003',
        'display_name': '   ',
        'current_hsk_level': 1,
        'target_hsk_level': 3,
        'purpose': 'daily_communication',
        'timeframe': 'standard',
        'daily_minutes': 15,
        'start_date': nowUtc,
        'interests_json': '[]',
        'avatar_style': 'tea',
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      await db.insert(DatabaseConstants.tableAppSettings, {
        'key': 'user_name',
        'value': 'Lê Hoàng Nam',
        'updated_at': nowUtc,
      });

      final name = await homeRepo.getLearnerDisplayName();
      expect(name, 'Lê Hoàng Nam');
    });

    test('4. Falls back to default "Học viên" when no profile or app setting exists', () async {
      final name = await homeRepo.getLearnerDisplayName();
      expect(name, 'Học viên');

      final dashboard = await homeRepo.getDashboardData();
      expect(dashboard.learnerName, 'Học viên');
    });

    test('5. Updates dynamically after user edits profile in SQLite', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableUserProfiles, {
        'id': 'user_005',
        'display_name': 'Tên Ban Đầu',
        'current_hsk_level': 1,
        'target_hsk_level': 2,
        'purpose': 'daily_communication',
        'timeframe': 'standard',
        'daily_minutes': 15,
        'start_date': nowUtc,
        'interests_json': '[]',
        'avatar_style': 'scholar',
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      var dashboard = await homeRepo.getDashboardData();
      expect(dashboard.learnerName, 'Tên Ban Đầu');

      // User edits name to "Phạm An"
      final updatedUtc = DateTime.now().toUtc().add(const Duration(seconds: 1)).toIso8601String();
      await db.update(
        DatabaseConstants.tableUserProfiles,
        {'display_name': 'Phạm An', 'updated_at': updatedUtc},
        where: 'id = ?',
        whereArgs: ['user_005'],
      );

      dashboard = await homeRepo.getDashboardData();
      expect(dashboard.learnerName, 'Phạm An');
    });
  });

  group('Lỗi B – Khử cộng trùng thời gian học (Zero Double-Counting)', () {
    test('1. Simultaneous session in learning_activities and learner_evidence is counted ONCE', () async {
      final nowUtc = DateTime.utc(2026, 11, 4, 10, 0); // Wednesday

      // Lesson completed at 10:00: duration = 900s (15 min), 10 items
      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'ACT_LESSON_001',
        'activity_type': 'lesson',
        'duration_seconds': 900,
        'items_count': 10,
        'activity_date': '2026-11-04',
        'created_at': nowUtc.toIso8601String(),
      });

      // 10 evidence items inserted during the same 15-minute lesson window
      for (int i = 0; i < 10; i++) {
        final itemTime = nowUtc.subtract(Duration(seconds: 90 * (10 - i)));
        await db.insert(DatabaseConstants.tableLearnerEvidence, {
          'id': 'EVI_ITEM_$i',
          'content_id': 'voc_hsk1_00$i',
          'content_type': 'vocabulary',
          'source': 'lesson',
          'score': 1.0,
          'duration_ms': 90000, // 90 seconds each
          'created_at': itemTime.toIso8601String(),
        });
      }

      final stats = await homeRepo.getStudyTimeStats(
        evaluationTime: nowUtc,
        timeZoneOffset: const Duration(hours: 7),
      );

      // Duration must be EXACTLY 900 seconds (15 minutes), NOT 1800 seconds (30 minutes)!
      expect(stats.todayDurationSeconds, 900);
      expect(stats.todayDurationMinutes, 15);
      expect(stats.todayItemsCompleted, 10);

      // Total and Week match
      expect(stats.weekDurationSeconds, 900);
      expect(stats.totalDurationSeconds, 900);
    });

    test('2. Standalone evidence without learning_activities session is credited properly', () async {
      final nowUtc = DateTime.utc(2026, 11, 4, 14, 0);

      // Quick standalone evidence without an activity session
      await db.insert(DatabaseConstants.tableLearnerEvidence, {
        'id': 'EVI_STANDALONE_001',
        'content_id': 'voc_hsk1_099',
        'content_type': 'vocabulary',
        'source': 'srs',
        'score': 1.0,
        'duration_ms': 120000, // 2 minutes (120s)
        'created_at': nowUtc.toIso8601String(),
      });

      final stats = await homeRepo.getStudyTimeStats(
        evaluationTime: nowUtc,
        timeZoneOffset: const Duration(hours: 7),
      );

      expect(stats.todayDurationSeconds, 120);
      expect(stats.todayDurationMinutes, 2);
      expect(stats.todayItemsCompleted, 1);
    });

    test('3. Discards negative durations and caps anomalous durations exceeding 4 hours', () async {
      final nowUtc = DateTime.utc(2026, 11, 4, 15, 0);

      // Corrupted session with negative duration
      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'ACT_NEGATIVE',
        'activity_type': 'lesson',
        'duration_seconds': -300,
        'items_count': 5,
        'activity_date': '2026-11-04',
        'created_at': nowUtc.subtract(const Duration(hours: 2)).toIso8601String(),
      });

      // Runaway timer session: 10 hours (36,000s)
      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'ACT_RUNAWAY',
        'activity_type': 'shadowing',
        'duration_seconds': 36000,
        'items_count': 1,
        'activity_date': '2026-11-04',
        'created_at': nowUtc.toIso8601String(),
      });

      final stats = await homeRepo.getStudyTimeStats(
        evaluationTime: nowUtc,
        timeZoneOffset: const Duration(hours: 7),
      );

      // Negative clamped to 0; runaway capped to 14,400s (4 hours)
      expect(stats.todayDurationSeconds, HomeRepository.maxSessionDurationSeconds);
      expect(stats.todayDurationMinutes, 240); // 4 hours max
    });

    test('4. Deduplicates sync and retry duplicate records occurring within 2 seconds', () async {
      final nowUtc = DateTime.utc(2026, 11, 4, 16, 0);

      // First sync record
      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'ACT_SYNC_1',
        'activity_type': 'ai_tutor',
        'duration_seconds': 600,
        'items_count': 1,
        'activity_date': '2026-11-04',
        'created_at': nowUtc.toIso8601String(),
      });

      // Duplicate sync record inserted with a different ID 1 second later
      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'ACT_SYNC_1_RETRY',
        'activity_type': 'ai_tutor',
        'duration_seconds': 600,
        'items_count': 1,
        'activity_date': '2026-11-04',
        'created_at': nowUtc.add(const Duration(seconds: 1)).toIso8601String(),
      });

      final stats = await homeRepo.getStudyTimeStats(
        evaluationTime: nowUtc,
        timeZoneOffset: const Duration(hours: 7),
      );

      // Deduplicated to 600s, 1 item!
      expect(stats.todayDurationSeconds, 600);
      expect(stats.todayDurationMinutes, 10);
      expect(stats.todayItemsCompleted, 1);
    });

    test('5. Accurately calculates Today, This Week (Monday-start), and Total study time', () async {
      // Reference: Wednesday, Nov 4, 2026, 12:00 UTC (19:00 GMT+7)
      final wednesdayUtc = DateTime.utc(2026, 11, 4, 12, 0);

      // 1. Session Today (Wednesday Nov 4): 30 minutes
      await homeRepo.logLearningActivity(
        activityType: 'lesson',
        durationSeconds: 1800,
        itemsCount: 15,
        activityTimeUtc: wednesdayUtc,
      );

      // 2. Session Yesterday (Tuesday Nov 3 - this week): 20 minutes
      final tuesdayUtc = DateTime.utc(2026, 11, 3, 12, 0);
      await homeRepo.logLearningActivity(
        activityType: 'srs_review',
        durationSeconds: 1200,
        itemsCount: 20,
        activityTimeUtc: tuesdayUtc,
      );

      // 3. Session Last Week (Sunday Nov 1 - previous calendar week): 45 minutes
      final lastSundayUtc = DateTime.utc(2026, 11, 1, 12, 0);
      await homeRepo.logLearningActivity(
        activityType: 'reading',
        durationSeconds: 2700,
        itemsCount: 5,
        activityTimeUtc: lastSundayUtc,
      );

      final stats = await homeRepo.getStudyTimeStats(
        evaluationTime: wednesdayUtc,
        timeZoneOffset: const Duration(hours: 7),
      );

      // Today: only Wednesday (1,800s / 30m)
      expect(stats.todayDurationSeconds, 1800);
      expect(stats.todayDurationMinutes, 30);
      expect(stats.todayItemsCompleted, 15);

      // This Week: Tuesday + Wednesday (1200 + 1800 = 3,000s / 50m)
      expect(stats.weekDurationSeconds, 3000);
      expect(stats.weekDurationMinutes, 50);
      expect(stats.weekItemsCompleted, 35);

      // Total: Sunday + Tuesday + Wednesday (2700 + 1200 + 1800 = 5,700s / 95m)
      expect(stats.totalDurationSeconds, 5700);
      expect(stats.totalDurationMinutes, 95);
      expect(stats.totalItemsCompleted, 40);
    });
  });

  group('Lỗi C – SRS lọc chính xác theo HSK hiện tại', () {
    test('1. Counts only due flashcards matching active HSK level', () async {
      final nowUtc = DateTime.utc(2026, 11, 4, 8, 0);

      // Insert vocabularies for HSK 1, HSK 2, and HSK 3
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'voc_hsk1_001',
        'simplified': '你好',
        'pinyin': 'nǐ hǎo',
        'hsk_level': 1,
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'voc_hsk1_002',
        'simplified': '再见',
        'pinyin': 'zàijiàn',
        'hsk_level': 1,
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'voc_hsk2_001',
        'simplified': '机场',
        'pinyin': 'jīchǎng',
        'hsk_level': 2,
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      // Insert SRS items:
      // Card 1: HSK 1 - DUE
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'srs_001',
        'content_id': 'voc_hsk1_001',
        'content_type': 'vocabulary',
        'state': 'review',
        'interval_days': 1,
        'ease_factor': 2.5,
        'repetitions': 1,
        'lapses': 0,
        'due_at': nowUtc.subtract(const Duration(hours: 2)).toIso8601String(),
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      // Card 2: HSK 1 - NOT DUE (in future)
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'srs_002',
        'content_id': 'voc_hsk1_002',
        'content_type': 'vocabulary',
        'state': 'review',
        'interval_days': 3,
        'ease_factor': 2.5,
        'repetitions': 2,
        'lapses': 0,
        'due_at': nowUtc.add(const Duration(days: 2)).toIso8601String(),
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      // Card 3: HSK 2 - DUE
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'srs_003',
        'content_id': 'voc_hsk2_001',
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

      // Card 4: Orphan card without matching vocabulary in database - DUE
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'srs_orphan',
        'content_id': 'voc_nonexistent_999',
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

      // 1. When querying for HSK 1: should return ONLY 1 card (srs_001)
      final hsk1DueCount = await srsRepo.getDueCardsCount(
        hskLevel: 1,
        asOf: nowUtc,
        forceRefresh: true,
      );
      expect(hsk1DueCount, 1);

      // Dashboard with targetHskLevel = 1
      final dataHsk1 = await homeRepo.getDashboardData(
        targetHskLevel: 1,
        evaluationTime: nowUtc,
      );
      expect(dataHsk1.srsDueCount, 1);

      // 2. When querying for HSK 2: should return ONLY 1 card (srs_003)
      final hsk2DueCount = await srsRepo.getDueCardsCount(
        hskLevel: 2,
        asOf: nowUtc,
        forceRefresh: true,
      );
      expect(hsk2DueCount, 1);

      // Dashboard with targetHskLevel = 2
      final dataHsk2 = await homeRepo.getDashboardData(
        targetHskLevel: 2,
        evaluationTime: nowUtc,
      );
      expect(dataHsk2.srsDueCount, 1);

      // 3. When querying for HSK 3: should return 0 cards
      final hsk3DueCount = await srsRepo.getDueCardsCount(
        hskLevel: 3,
        asOf: nowUtc,
        forceRefresh: true,
      );
      expect(hsk3DueCount, 0);

      // 4. When hskLevel is null (unfiltered): returns all 3 due cards (srs_001, srs_003, srs_orphan)
      final allDueCount = await srsRepo.getDueCardsCount(
        asOf: nowUtc,
        forceRefresh: true,
      );
      expect(allDueCount, 3);
    });

    test('2. Changing active HSK level dynamically switches dashboard SRS count', () async {
      final nowUtc = DateTime.utc(2026, 11, 4, 8, 0);

      // Seed learner profile at HSK 1
      await db.insert(DatabaseConstants.tableUserProfiles, {
        'id': 'user_active',
        'display_name': 'Học viên HSK 1',
        'current_hsk_level': 1,
        'target_hsk_level': 2,
        'purpose': 'daily_communication',
        'timeframe': 'standard',
        'daily_minutes': 20,
        'start_date': nowUtc.toIso8601String(),
        'interests_json': '[]',
        'avatar_style': 'panda',
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      // Add HSK 2 vocabulary and due card
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'voc_hsk2_100',
        'simplified': '准备',
        'pinyin': 'zhǔnbèi',
        'hsk_level': 2,
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'srs_hsk2_100',
        'content_id': 'voc_hsk2_100',
        'content_type': 'vocabulary',
        'state': 'review',
        'interval_days': 1,
        'ease_factor': 2.5,
        'repetitions': 1,
        'lapses': 0,
        'due_at': nowUtc.subtract(const Duration(minutes: 30)).toIso8601String(),
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      // At HSK 1, SRS count is 0 because the due card is for HSK 2
      var dashboard = await homeRepo.getDashboardData(evaluationTime: nowUtc);
      expect(dashboard.srsDueCount, 0);
      expect(dashboard.roadmap.currentHskLevel, 1);

      // Learner advances to HSK 2
      await db.update(
        DatabaseConstants.tableUserProfiles,
        {'current_hsk_level': 2, 'updated_at': nowUtc.toIso8601String()},
        where: 'id = ?',
        whereArgs: ['user_active'],
      );

      // At HSK 2, SRS count is 1
      dashboard = await homeRepo.getDashboardData(evaluationTime: nowUtc);
      expect(dashboard.srsDueCount, 1);
      expect(dashboard.roadmap.currentHskLevel, 2);
    });
  });
}
