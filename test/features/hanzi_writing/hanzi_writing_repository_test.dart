import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/hanzi_writing/hanzi_writing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late HanziWritingRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hanzi_writing_test_');
    final dbPath = '${tempDir.path}/test_hanzi_writing.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    repository = HanziWritingRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HanziWritingRepository SQLite Persistence Tests', () {
    test('1. recordWritingSession saves evaluation atomically to learner_evidence and learning_activities', () async {
      const evaluation = WritingEvaluationResult(
        strokeOrderAccuracy: 1.0,
        correctStrokeCount: 2,
        totalStandardStrokes: 2,
        userDrawnStrokesCount: 2,
        isTracingMode: true,
        strokeFeedbackList: ['Nét 1 chuẩn', 'Nét 2 chuẩn'],
        overallVerdict: 'Hoàn hảo!',
        hasStandardStrokeData: true,
      );

      final fixedTime = DateTime.utc(2026, 11, 1, 14, 0, 0);

      await repository.recordWritingSession(
        character: '十',
        evaluation: evaluation,
        durationMs: 8500,
        timestamp: fixedTime,
      );

      // Check learner_evidence
      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'source = ?',
        whereArgs: ['hanzi_writing'],
      );
      expect(evidenceRows.length, equals(1));
      expect(evidenceRows.first['content_id'], equals('十'));
      expect(evidenceRows.first['score'], equals(1.0));
      expect(evidenceRows.first['duration_ms'], equals(8500));
      expect(evidenceRows.first['metadata_json'], contains('is_tracing_mode'));

      // Check learning_activities (powers the Home Screen streak)
      final activityRows = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'activity_type = ?',
        whereArgs: ['hanzi_writing'],
      );
      expect(activityRows.length, equals(1));
      expect(activityRows.first['items_count'], equals(1));
      expect(activityRows.first['duration_seconds'], equals(9));
      expect(activityRows.first['activity_date'], equals('2026-11-01'));
    });

    test('2. Does not save heavy binary raw bitmaps into SQLite', () async {
      const evaluation = WritingEvaluationResult(
        strokeOrderAccuracy: 0.8,
        correctStrokeCount: 4,
        totalStandardStrokes: 5,
        userDrawnStrokesCount: 5,
        isTracingMode: false,
        strokeFeedbackList: ['Tốt'],
        overallVerdict: 'Khá tốt',
      );

      await repository.recordWritingSession(
        character: '水',
        evaluation: evaluation,
      );

      final rows = await repository.getRecentWritingSessions(character: '水');
      expect(rows.length, equals(1));

      // Payload size in metadata_json must be compact (< 1000 characters)
      final metadataJson = rows.first['metadata_json'] as String;
      expect(metadataJson.length, lessThan(1000));
      expect(metadataJson.contains('base64'), isFalse);
    });
  });
}
