import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/placement_test/data/placement_test_repository.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_session_state.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_skill.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late PlacementTestRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hi_chinese_placement_repo_test_');
    final dbPath = '${tempDir.path}/placement_repo_test.db';

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

    repository = PlacementTestRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PlacementTestRepository SQLite Tests', () {
    test('1. Creates new session in in_progress status with initial item', () async {
      final session = await repository.startNewSession(customSessionId: 'TEST_SESSION_01');

      expect(session.sessionId, 'TEST_SESSION_01');
      expect(session.status, 'in_progress');
      expect(session.currentSkill, CatSkill.vocabulary);
      expect(session.activeItem, isNotNull);
      expect(session.stepIndex, 0);

      // Verify row in database
      final rows = await db.query(
        DatabaseConstants.tablePlacementTestSessions,
        where: 'id = ?',
        whereArgs: ['TEST_SESSION_01'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['status'], 'in_progress');
    });

    test('2. Saves individual turn response and updates session state', () async {
      final session = await repository.startNewSession(customSessionId: 'TEST_SESSION_02');

      final record = CatResponseRecord(
        itemId: 'VOCAB_001',
        skill: CatSkill.vocabulary,
        itemDifficulty: -1.8,
        hskTarget: 1,
        isCalibrationItem: true,
        userAnswer: 0,
        isCorrect: true,
        latencyMs: 1500,
        timestamp: DateTime.now().toUtc(),
      );

      await repository.saveTurnResponse(
        sessionId: session.sessionId,
        response: record,
        updatedTheta: -0.8,
        updatedSe: 0.9,
        stepIndex: 1,
      );

      // Verify response persisted
      final respRows = await db.query(
        DatabaseConstants.tablePlacementTestResponses,
        where: 'session_id = ?',
        whereArgs: ['TEST_SESSION_02'],
      );
      expect(respRows, hasLength(1));
      expect(respRows.first['item_id'], 'VOCAB_001');
      expect(respRows.first['is_correct'], 1);

      // Verify session updated
      final sRows = await db.query(
        DatabaseConstants.tablePlacementTestSessions,
        where: 'id = ?',
        whereArgs: ['TEST_SESSION_02'],
      );
      expect((sRows.first['estimated_theta'] as num).toDouble(), -0.8);
      expect(sRows.first['current_step_index'], 1);
    });

    test('3. Resumes in-progress session after app restart with exact step and historical answers', () async {
      final session = await repository.startNewSession(customSessionId: 'TEST_SESSION_03');

      // Save 2 responses
      await repository.saveTurnResponse(
        sessionId: session.sessionId,
        response: CatResponseRecord(
          itemId: 'VOCAB_001',
          skill: CatSkill.vocabulary,
          itemDifficulty: -1.8,
          hskTarget: 1,
          userAnswer: 0,
          isCorrect: true,
          timestamp: DateTime.now().toUtc(),
        ),
        updatedTheta: -0.7,
        updatedSe: 0.8,
        stepIndex: 1,
      );

      await repository.saveTurnResponse(
        sessionId: session.sessionId,
        response: CatResponseRecord(
          itemId: 'VOCAB_002',
          skill: CatSkill.vocabulary,
          itemDifficulty: -1.2,
          hskTarget: 1,
          userAnswer: 0,
          isCorrect: true,
          timestamp: DateTime.now().toUtc(),
        ),
        updatedTheta: -0.3,
        updatedSe: 0.7,
        stepIndex: 2,
      );

      // Simulate app restart and re-open active session
      final resumed = await repository.getActiveSession();

      expect(resumed, isNotNull);
      expect(resumed!.sessionId, 'TEST_SESSION_03');
      expect(resumed.status, 'in_progress');
      expect(resumed.stepIndex, 2);
      expect(resumed.responses, hasLength(2));
      expect(resumed.currentTheta, closeTo(-0.3, 0.01));
      expect(resumed.activeItem, isNotNull);
    });

    test('4. Finalizes session, writes evidence to learner_evidence, and stores diagnostic report', () async {
      final session = await repository.startNewSession(customSessionId: 'TEST_SESSION_04');

      final responses = [
        CatResponseRecord(
          itemId: 'VOCAB_001',
          skill: CatSkill.vocabulary,
          itemDifficulty: -1.8,
          hskTarget: 1,
          userAnswer: 0,
          isCorrect: true,
          latencyMs: 2000,
          timestamp: DateTime.now().toUtc(),
        ),
        CatResponseRecord(
          itemId: 'GRAM_001',
          skill: CatSkill.grammar,
          itemDifficulty: -1.7,
          hskTarget: 1,
          userAnswer: 0,
          isCorrect: true,
          latencyMs: 3000,
          timestamp: DateTime.now().toUtc(),
        ),
      ];

      final assessmentResult = repository.engine.generateAssessmentResult(
        sessionId: session.sessionId,
        overallTheta: -0.4,
        overallStandardError: 0.45,
        responses: responses,
        completedAt: DateTime.now().toUtc(),
      );

      final completedState = session.copyWith(
        status: 'completed',
        isCompleted: true,
        responses: responses,
        result: assessmentResult,
      );

      await repository.finalizeSession(
        sessionState: completedState,
        result: assessmentResult,
      );

      // Verify session marked completed
      final active = await repository.getActiveSession();
      expect(active, isNull); // No longer in_progress

      // Verify learner_evidence has entries with source 'cat_placement_test'
      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'source = ?',
        whereArgs: ['cat_placement_test'],
      );
      expect(evidenceRows, hasLength(2));

      // Verify activity logged in learning_activities
      final actRows = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'activity_type = ?',
        whereArgs: ['cat_placement_test'],
      );
      expect(actRows, hasLength(1));

      // Verify getLatestCompletedResult returns diagnostic report
      final latest = await repository.getLatestCompletedResult();
      expect(latest, isNotNull);
      expect(latest!.sessionId, 'TEST_SESSION_04');
      expect(latest.referenceHskBand, contains('HSK 2'));
      expect(latest.recommendedHskLevel, 2);
    });

    test('5. Abandoning an active session marks it abandoned and clears active session query', () async {
      final session = await repository.startNewSession(customSessionId: 'TEST_SESSION_05');
      expect(await repository.getActiveSession(), isNotNull);

      await repository.abandonSession(session.sessionId);
      expect(await repository.getActiveSession(), isNull);
    });

    test('6. Creates zero-Chinese beginner session with initialTheta = -2.0, starts in Listening, and restores blueprint_version', () async {
      final session = await repository.startNewSession(
        customSessionId: 'TEST_SESSION_BEGINNER_06',
        initialTheta: -2.0,
      );

      expect(session.sessionId, 'TEST_SESSION_BEGINNER_06');
      expect(session.status, 'in_progress');
      expect(session.currentSkill, CatSkill.listening);
      expect(session.currentTheta, -2.0);
      expect(session.blueprintVersion, 'v1.0-beginner');
      expect(session.activeItem, isNotNull);
      expect(session.activeItem!.difficulty, inInclusiveRange(-3.0, -1.0));

      // Verify row in database has blueprint_version = 'v1.0-beginner'
      final rows = await db.query(
        DatabaseConstants.tablePlacementTestSessions,
        where: 'id = ?',
        whereArgs: ['TEST_SESSION_BEGINNER_06'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['blueprint_version'], 'v1.0-beginner');

      // Verify getActiveSession restores session with blueprint_version
      final active = await repository.getActiveSession();
      expect(active, isNotNull);
      expect(active!.blueprintVersion, 'v1.0-beginner');
      expect(active.currentSkill, CatSkill.listening);
    });
  });
}
