import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/practice/practice.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late PracticeRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('practice_test_');
    final dbPath = '${tempDir.path}/test_practice.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    repository = DefaultPracticeRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PracticeRepository SQLite & Offline Integrity Tests', () {
    test('1. Auto seeds curated authentic exercises into SQLite', () async {
      final items = await repository.getExercises();
      expect(items, isNotEmpty);
      expect(items.length, greaterThanOrEqualTo(7));

      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tablePracticeExercises}'),
      );
      expect(count, items.length);
    });

    test('2. Filters exercises accurately by skill and type', () async {
      final vocabExercises = await repository.getExercises(skill: 'vocabulary');
      expect(vocabExercises, isNotEmpty);
      expect(vocabExercises.every((e) => e.skill == 'vocabulary'), isTrue);

      final mcExercises = await repository.getExercises(type: ExerciseType.multipleChoice);
      expect(mcExercises, isNotEmpty);
      expect(mcExercises.every((e) => e.type == ExerciseType.multipleChoice), isTrue);
    });

    test('3. Creates a session and pauses/resumes active session seamlessly', () async {
      final session = await repository.createSession(
        title: 'Phiên luyện HSK 1',
        skill: 'vocabulary',
        hskLevel: 1,
        exerciseIds: ['EX_MC_VOCAB_01', 'EX_PINYIN_VOCAB_02'],
      );

      expect(session.id, isNotEmpty);
      expect(session.status, PracticeSessionStatus.inProgress);
      expect(session.currentIndex, 0);

      // Simulate student answering question 1
      final attempt = ExerciseAttempt(
        id: 'att_01',
        sessionId: '', // set below
        exerciseId: 'EX_MC_VOCAB_01',
        answer: const ExerciseAnswer(exerciseId: 'EX_MC_VOCAB_01', selectedOptionIndex: 0),
        result: const ScoringResult(
          isCorrect: true,
          score: 1.0,
          confidence: 1.0,
          feedbackVi: 'Chính xác',
        ),
        durationMs: 4500,
        createdAt: DateTime.utc(2026, 11, 1),
      );

      final recorded = await repository.recordAttempt(
        sessionId: session.id,
        attempt: ExerciseAttempt(
          id: 'att_01',
          sessionId: session.id,
          exerciseId: 'EX_MC_VOCAB_01',
          answer: attempt.answer,
          result: attempt.result,
          durationMs: 4500,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      expect(recorded.result.isCorrect, isTrue);

      // Progress to question 2
      await repository.updateSessionProgress(session.id, currentIndex: 1);

      // Simulate app restart / interruption: fetch active session
      final active = await repository.getActiveSession(skill: 'vocabulary');
      expect(active, isNotNull);
      expect(active!.id, session.id);
      expect(active.currentIndex, 1);
      expect(active.attempts.length, 1);
      expect(active.attempts.first.exerciseId, 'EX_MC_VOCAB_01');
    });

    test('4. Double Submit Prevention: Repeated attempts for same question are deduped', () async {
      final session = await repository.createSession(
        title: 'Phiên kiểm tra double submit',
        skill: 'grammar',
        exerciseIds: ['EX_BLANK_GRAMMAR_04'],
      );

      final attempt1 = ExerciseAttempt(
        id: 'att_dup_1',
        sessionId: session.id,
        exerciseId: 'EX_BLANK_GRAMMAR_04',
        answer: const ExerciseAnswer(exerciseId: 'EX_BLANK_GRAMMAR_04', filledBlank: '是'),
        result: const ScoringResult(isCorrect: true, score: 1.0, confidence: 1.0, feedbackVi: 'Đúng'),
        durationMs: 2000,
        createdAt: DateTime.now().toUtc(),
      );

      final attempt2 = ExerciseAttempt(
        id: 'att_dup_2', // Different attempt id, but same (sessionId, exerciseId)
        sessionId: session.id,
        exerciseId: 'EX_BLANK_GRAMMAR_04',
        answer: const ExerciseAnswer(exerciseId: 'EX_BLANK_GRAMMAR_04', filledBlank: '在'),
        result: const ScoringResult(isCorrect: false, score: 0.0, confidence: 1.0, feedbackVi: 'Sai'),
        durationMs: 2200,
        createdAt: DateTime.now().toUtc(),
      );

      final res1 = await repository.recordAttempt(sessionId: session.id, attempt: attempt1);
      final res2 = await repository.recordAttempt(sessionId: session.id, attempt: attempt2);

      // Second attempt must return the original attempt, ignoring duplicate submit!
      expect(res2.id, res1.id);
      expect(res2.result.score, 1.0);

      // Verify SQLite row count in practice_attempts table is exactly 1!
      final count = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseConstants.tablePracticeAttempts} WHERE session_id = ?',
          [session.id],
        ),
      );
      expect(count, 1);
    });

    test('5. CompleteSession atomically saves progress, learner_evidence, and activity', () async {
      final session = await repository.createSession(
        title: 'Phiên hoàn thành',
        skill: 'writing',
        exerciseIds: ['EX_SHORT_ANSWER_07'],
      );

      await repository.recordAttempt(
        sessionId: session.id,
        attempt: ExerciseAttempt(
          id: 'att_comp_1',
          sessionId: session.id,
          exerciseId: 'EX_SHORT_ANSWER_07',
          answer: const ExerciseAnswer(exerciseId: 'EX_SHORT_ANSWER_07', textResponse: '今天比昨天冷'),
          result: const ScoringResult(isCorrect: true, score: 0.85, confidence: 0.85, feedbackVi: 'Tốt'),
          durationMs: 6000,
          createdAt: DateTime.now().toUtc(),
        ),
      );

      final completed = await repository.completeSession(
        sessionId: session.id,
        totalDurationMs: 6000,
      );

      expect(completed.status, PracticeSessionStatus.completed);
      expect(completed.score, 0.85);
      expect(completed.completedAt, isNotNull);

      // Verify Learner Evidence was atomically created
      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'content_id = ? AND content_type = ?',
        whereArgs: [session.id, 'practice'],
      );
      expect(evidenceRows, hasLength(1));
      expect(evidenceRows.first['score'], 0.85);

      // Verify Learning Activities was atomically recorded
      final activityRows = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'activity_type = ?',
        whereArgs: ['practice'],
      );
      expect(activityRows, hasLength(1));
    });
  });
}
