import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/grammar/grammar.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late GrammarRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('grammar_test_');
    final dbPath = '${tempDir.path}/test_grammar.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    repository = DefaultGrammarRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('GrammarRepository SQLite & Offline Integrity Tests', () {
    test('1. Auto seeds curated authentic grammar catalog into SQLite', () async {
      final items = await repository.getGrammarItems();
      expect(items, isNotEmpty);
      expect(items.length, greaterThanOrEqualTo(5));

      // Verify specific items exist
      expect(items.any((i) => i.id == 'GRM_HSK1_01_SHI'), isTrue);
      expect(items.any((i) => i.id == 'GRM_HSK2_01_BI_COMPARISON'), isTrue);

      final dbCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableGrammarItems}'),
      );
      expect(dbCount, items.length);
    });

    test('2. Filters grammar items accurately by HSK level', () async {
      final hsk1Items = await repository.getGrammarItems(hskLevel: 1);
      expect(hsk1Items, isNotEmpty);
      expect(hsk1Items.every((i) => i.hskLevel == 1), isTrue);

      final hsk2Items = await repository.getGrammarItems(hskLevel: 2);
      expect(hsk2Items, isNotEmpty);
      expect(hsk2Items.every((i) => i.hskLevel == 2), isTrue);

      final hsk5Items = await repository.getGrammarItems(hskLevel: 5);
      expect(hsk5Items, isEmpty);
    });

    test('3. Filters grammar items by topic tags', () async {
      final questionItems = await repository.getGrammarItems(tag: 'câu_hỏi');
      expect(questionItems, isNotEmpty);
      expect(questionItems.any((i) => i.id == 'GRM_HSK1_02_MA'), isTrue);

      final baItems = await repository.getGrammarItems(tag: 'câu_chữ_bả');
      expect(baItems, isNotEmpty);
      expect(baItems.first.id, 'GRM_HSK2_02_BA_SENTENCE');
    });

    test('4. Searches grammar items by keyword in title, pattern, and meaning', () async {
      final searchBi = await repository.getGrammarItems(query: '比');
      expect(searchBi, isNotEmpty);
      expect(searchBi.any((i) => i.id == 'GRM_HSK2_01_BI_COMPARISON'), isTrue);

      final searchLocative = await repository.getGrammarItems(query: 'nơi chốn');
      expect(searchLocative, isNotEmpty);
      expect(searchLocative.any((i) => i.id == 'GRM_HSK1_03_ZAI_PLACE'), isTrue);
    });

    test('5. Academic Honesty: zero evaluated exercises NEVER records evidence or activity', () async {
      const grammarId = 'GRM_HSK1_01_SHI';

      // Merely opening or viewing grammar rule should not record evidence!
      await repository.recordStudySession(
        grammarId: grammarId,
        score: 1.0,
        durationSeconds: 120,
        exercisesCount: 0, // No exercises actually attempted
      );

      final progress = await repository.getProgress(grammarId);
      expect(progress, isNull);

      final evidenceRows = await db.query(DatabaseConstants.tableLearnerEvidence);
      expect(evidenceRows, isEmpty);

      final activityRows = await db.query(DatabaseConstants.tableLearningActivities);
      expect(activityRows, isEmpty);
    });

    test('6. recordStudySession atomically writes progress, learner_evidence, and activity', () async {
      const grammarId = 'GRM_HSK1_01_SHI';

      await repository.recordStudySession(
        grammarId: grammarId,
        score: 0.90,
        durationSeconds: 180,
        exercisesCount: 3,
      );

      // Verify progress updated to mastered
      final progress = await repository.getProgress(grammarId);
      expect(progress, isNotNull);
      expect(progress!.status, GrammarProgressStatus.mastered);
      expect(progress.masteryScore, 0.90);
      expect(progress.exercisesCompleted, 3);
      expect(progress.lastStudiedAt, isNotNull);

      // Verify learner_evidence persisted
      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'content_id = ?',
        whereArgs: [grammarId],
      );
      expect(evidenceRows, isNotEmpty);
      expect(evidenceRows.first['content_type'], 'grammar');
      expect(evidenceRows.first['source'], 'grammar_practice');
      expect(evidenceRows.first['score'], 0.90);

      // Verify learning_activities recorded for streak
      final activityRows = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'activity_type = ?',
        whereArgs: ['grammar'],
      );
      expect(activityRows, isNotEmpty);
      expect(activityRows.first['items_count'], 3);
    });

    test('7. Score below 0.8 sets status to learning instead of mastered', () async {
      const grammarId = 'GRM_HSK1_03_ZAI_PLACE';

      await repository.recordStudySession(
        grammarId: grammarId,
        score: 0.60, // < 0.80
        durationSeconds: 150,
        exercisesCount: 2,
      );

      final progress = await repository.getProgress(grammarId);
      expect(progress, isNotNull);
      expect(progress!.status, GrammarProgressStatus.learning);
      expect(progress.masteryScore, 0.60);
    });
  });
}
