import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/roadmap/roadmap.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late RoadmapRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('roadmap_test_');
    final dbPath = '${tempDir.path}/test_roadmap.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    repository = DefaultRoadmapRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RoadmapRepository SQLite Integration Tests', () {
    test('1. getActiveGoal returns default goal when empty and persists to SQLite', () async {
      final goal = await repository.getActiveGoal();
      expect(goal, isNotNull);
      expect(goal.targetHskLevel, 1);
      expect(goal.purpose, LearnerPurpose.dailyCommunication);

      final rows = await db.query(DatabaseConstants.tableLearnerGoals);
      expect(rows, isNotEmpty);
      expect(rows.first['id'], goal.id);
    });

    test('2. updateGoal replaces previous active goal cleanly in transaction', () async {
      await repository.getActiveGoal();

      final newGoal = LearnerGoal(
        id: 'user_custom_goal',
        targetHskLevel: 2,
        purpose: LearnerPurpose.businessWork,
        timeframe: LearnerTimeframe.express,
        dailyMinutes: 45,
        isActive: true,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await repository.updateGoal(newGoal);

      final activeGoal = await repository.getActiveGoal();
      expect(activeGoal.id, 'user_custom_goal');
      expect(activeGoal.targetHskLevel, 2);
      expect(activeGoal.purpose, LearnerPurpose.businessWork);

      final activeRows = await db.query(
        DatabaseConstants.tableLearnerGoals,
        where: 'is_active = 1',
      );
      expect(activeRows.length, 1);
    });

    test('3. startLesson changes status to inProgress and NEVER marks completed', () async {
      const lessonId = 'LES_HSK1_01_TONES';

      await repository.startLesson(lessonId);

      final progressMap = await repository.getLessonProgressMap();
      final progress = progressMap[lessonId];

      expect(progress, isNotNull);
      expect(progress!.status, LessonStatus.inProgress);
      expect(progress.isCompleted, isFalse);
      expect(progress.completionScore, isNull);
      expect(progress.startedAt, isNotNull);
      expect(progress.completedAt, isNull);
    });

    test('4. completeLesson atomically records evidence and activity in SQLite', () async {
      const lessonId = 'LES_HSK1_01_TONES';

      await repository.startLesson(lessonId);
      await repository.completeLesson(lessonId: lessonId, score: 0.95);

      final progressMap = await repository.getLessonProgressMap();
      final progress = progressMap[lessonId];

      expect(progress, isNotNull);
      expect(progress!.status, LessonStatus.completed);
      expect(progress.isCompleted, isTrue);
      expect(progress.completionScore, 0.95);
      expect(progress.evidenceCount, 1);
      expect(progress.completedAt, isNotNull);

      // Verify atomic insertion into learner_evidence
      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'content_id = ?',
        whereArgs: [lessonId],
      );
      expect(evidenceRows, isNotEmpty);
      expect(evidenceRows.first['score'], 0.95);

      // Verify atomic insertion into learning_activities
      final activityRows = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'activity_type = ?',
        whereArgs: ['lesson'],
      );
      expect(activityRows, isNotEmpty);
    });

    test('5. skipLesson marks lesson as skipped in database with 0.0 score and null completed_at', () async {
      const lessonId = 'LES_HSK1_03_GREETINGS';

      await repository.skipLesson(lessonId);

      final progressMap = await repository.getLessonProgressMap();
      final progress = progressMap[lessonId];

      expect(progress, isNotNull);
      expect(progress!.status, LessonStatus.skipped);
      expect(progress.isCompleted, isFalse);
      expect(progress.completionScore, 0.0);
      expect(progress.completedAt, isNull);

      // Verify direct database persistence (BUG-NEW-002)
      final rows = await db.query(
        DatabaseConstants.tableLessonProgress,
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
      );
      expect(rows, isNotEmpty);
      expect(rows.first['status'], 'skipped');
      expect(rows.first['completion_score'], 0.0);
      expect(rows.first['completed_at'], isNull);
    });

    test('5b. completeLesson with score < 0.8 leaves status as inProgress without marking completed', () async {
      const lessonId = 'LES_HSK1_02_WRITING_BASICS';

      await repository.startLesson(lessonId);
      await repository.completeLesson(lessonId: lessonId, score: 0.0);

      final progressMap = await repository.getLessonProgressMap();
      final progress = progressMap[lessonId];

      expect(progress, isNotNull);
      expect(progress!.status, LessonStatus.inProgress);
      expect(progress.isCompleted, isFalse);
      expect(progress.completionScore, 0.0);
      expect(progress.completedAt, isNull);

      final rows = await db.query(
        DatabaseConstants.tableLessonProgress,
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
      );
      expect(rows, isNotEmpty);
      expect(rows.first['status'], 'inProgress');
      expect(rows.first['completion_score'], 0.0);
      expect(rows.first['completed_at'], isNull);
    });

    test('6. getAdaptiveRoadmapState calculates and snapshots state to SQLite', () async {
      final state = await repository.getAdaptiveRoadmapState();

      expect(state.activeGoal, isNotNull);
      expect(state.currentLevel, 1);
      expect(state.recommendations, isNotEmpty);

      // Verify snapshot recorded
      final snapshotRows = await db.query(
        DatabaseConstants.tableRoadmapSnapshots,
        orderBy: 'updated_at DESC',
      );
      expect(snapshotRows, isNotEmpty);
      expect(snapshotRows.first['current_level'], 1);
    });
  });
}
