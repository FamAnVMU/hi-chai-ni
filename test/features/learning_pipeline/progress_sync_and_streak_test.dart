import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/curriculum/domain/engine/mastery_engine.dart';
import 'package:hi_chinese/features/curriculum/presentation/providers/lesson_flow_providers.dart';
import 'package:hi_chinese/features/home/data/home_repository.dart';
import 'package:hi_chinese/features/home/domain/models/learning_streak.dart';
import 'package:hi_chinese/features/learning_pipeline/learning_pipeline.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Progress Sync, Activity Logging & Streak Integration Tests', () {
    late Database db;
    late Directory tempDir;
    late LearningPipelineCoordinator coordinator;
    late HomeRepository homeRepository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('progress_sync_test_');
      final dbPath = '${tempDir.path}/test_progress_sync.db';
      db = await databaseFactory.openDatabase(dbPath);

      final engine = MigrationEngine();
      await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

      coordinator = LearningPipelineCoordinator(db);
      homeRepository = HomeRepository(db);

      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'pack_hsk1',
        'hsk_level': 1,
        'version': '1.0.0',
        'title': 'HSK 1 Standard Pack',
        'is_bundled': 1,
        'status': 'installed',
        'updated_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_hsk1',
        'pack_id': 'pack_hsk1',
        'code': 'HSK1',
        'standard_name': 'HSK 1 Standard',
        'hsk_level': 1,
        'total_units': 1,
        'total_lessons': 2,
        'created_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableCurriculumUnits, {
        'id': 'unit_1',
        'curriculum_id': 'curr_hsk1',
        'order_index': 1,
        'title_vi': 'Unit 1: Chào hỏi',
        'title_zh': '第一单元：问候',
        'created_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableCurriculumLessons, {
        'id': 'lesson_1_1',
        'unit_id': 'unit_1',
        'order_index': 1,
        'title_vi': 'Bài 1: Xin chào',
        'title_zh': '第一课：你好',
        'pinyin': 'Nǐ hǎo',
        'status': 'not_started',
        'is_locked': 0,
        'prerequisites_json': '[]',
        'created_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableCurriculumLessons, {
        'id': 'lesson_1_2',
        'unit_id': 'unit_1',
        'order_index': 2,
        'title_vi': 'Bài 2: Cảm ơn',
        'title_zh': '第二课：谢谢',
        'pinyin': 'Xièxie',
        'status': 'not_started',
        'is_locked': 1,
        'prerequisites_json': '["lesson_1_1"]',
        'created_at': nowIso,
      });
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Completing a lesson inserts 1 valid row into learning_activities with today local date', () async {
      final result = await coordinator.recordLessonCompletion(
        lessonId: 'lesson_1_1',
        scorePercent: 0.90,
        durationMs: 240000,
      );

      expect(result.isPassed, isTrue);

      final activities = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'activity_type = ?',
        whereArgs: ['lesson'],
      );

      expect(activities.length, equals(1));
      final row = activities.first;
      expect(row['id'].toString(), startsWith('act_lesson_1_1_'));
      expect(row['activity_type'], equals('lesson'));
      expect(row['duration_seconds'], equals(240));
      expect(row['items_count'], equals(10));

      final expectedTodayStr = StreakCalculator.toDateString(
        StreakCalculator.toLocalDate(
          DateTime.now().toUtc(),
          timeZoneOffset: DateTime.now().timeZoneOffset,
        ),
      );
      expect(row['activity_date'], equals(expectedTodayStr));
      expect(row['timezone_offset_minutes'], equals(DateTime.now().timeZoneOffset.inMinutes));
    });

    test('2. HomeRepository.calculateStreak and getDashboardData reflect streak >= 1 and hasCompletedLessons == true', () async {
      await coordinator.recordLessonCompletion(
        lessonId: 'lesson_1_1',
        scorePercent: 0.85,
        durationMs: 180000,
      );

      final streak = await homeRepository.calculateStreak();
      expect(streak.currentStreak, greaterThanOrEqualTo(1));
      expect(streak.hasStudiedToday, isTrue);

      final dashboard = await homeRepository.getDashboardData();
      expect(dashboard.hasCompletedLessons, isTrue);
      expect(dashboard.streak.currentStreak, greaterThanOrEqualTo(1));
      expect(dashboard.recentActivities, isNotEmpty);
      expect(dashboard.recentActivities.first.durationSeconds, greaterThanOrEqualTo(180));
    });

    test('3. Completing lesson via LessonFlowNotifier (even with empty userAnswers) passes with >= 0.85 and unlocks next lesson', () async {
      final container = ProviderContainer(
        overrides: [
          masteryEngineProvider.overrideWithValue(MasteryEngine(db)),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(lessonFlowNotifierProvider('lesson_1_1'), (_, _) {});
      addTearDown(sub.close);

      final notifier = container.read(lessonFlowNotifierProvider('lesson_1_1').notifier);
      final updateResult = await notifier.completeLesson();

      expect(updateResult.isPassed, isTrue);
      expect(updateResult.scorePercent, greaterThanOrEqualTo(0.85));
      expect(container.read(lessonFlowNotifierProvider('lesson_1_1')).isCompleted, isTrue);

      final lesson1Rows = await db.query(
        DatabaseConstants.tableCurriculumLessons,
        where: 'id = ?',
        whereArgs: ['lesson_1_1'],
      );
      expect(lesson1Rows.first['status'], equals('completed'));

      final lesson2Rows = await db.query(
        DatabaseConstants.tableCurriculumLessons,
        where: 'id = ?',
        whereArgs: ['lesson_1_2'],
      );
      expect(lesson2Rows.first['is_locked'], equals(0));

      final progressRows = await db.query(
        DatabaseConstants.tableLessonProgress,
        where: 'lesson_id = ?',
        whereArgs: ['lesson_1_1'],
      );
      expect(progressRows, isNotEmpty);
      expect(progressRows.first['status'], equals('completed'));

      final masteryRows = await db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: ['lesson_1_1'],
      );
      expect(masteryRows, isNotEmpty);
      expect(masteryRows.first['mastery_state'], equals('completed'));

      final activityRows = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'activity_type = ?',
        whereArgs: ['lesson'],
      );
      expect(activityRows, isNotEmpty);
    });
  });
}
