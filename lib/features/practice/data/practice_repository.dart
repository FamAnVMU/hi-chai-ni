import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_constants.dart';
import '../../learning_pipeline/data/learning_pipeline_coordinator.dart';
import '../domain/catalog/practice_seed_catalog.dart';
import '../domain/models/practice_models.dart';

abstract class PracticeRepository {
  Future<List<ExerciseDefinition>> getExercises({String? skill, int? hskLevel, ExerciseType? type});
  Future<ExerciseDefinition?> getExerciseById(String id);
  Future<void> saveExercise(ExerciseDefinition def);

  Future<PracticeSession> createSession({
    required String title,
    required String skill,
    int hskLevel = 1,
    required List<String> exerciseIds,
  });

  Future<PracticeSession?> getActiveSession({String? skill});
  Future<PracticeSession?> getSessionById(String sessionId);
  Future<void> updateSessionProgress(String sessionId, {required int currentIndex});

  Future<ExerciseAttempt> recordAttempt({
    required String sessionId,
    required ExerciseAttempt attempt,
  });

  Future<PracticeSession> completeSession({
    required String sessionId,
    required int totalDurationMs,
  });

  Future<List<ExerciseAttempt>> getAttemptHistory(String exerciseId);
}

class DefaultPracticeRepository implements PracticeRepository {
  final DatabaseExecutor _db;
  final LearningPipelineCoordinator _pipelineCoordinator;

  DefaultPracticeRepository(
    this._db, {
    LearningPipelineCoordinator? pipelineCoordinator,
  }) : _pipelineCoordinator = pipelineCoordinator ?? LearningPipelineCoordinator(_db);

  /// Automatically ensures curated seed catalog is populated in SQLite
  Future<void> _ensureCatalogSeeded() async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tablePracticeExercises}'),
    );

    if (count == null || count == 0) {
      for (final item in PracticeSeedCatalog.items) {
        await _db.insert(
          DatabaseConstants.tablePracticeExercises,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  @override
  Future<List<ExerciseDefinition>> getExercises({String? skill, int? hskLevel, ExerciseType? type}) async {
    await _ensureCatalogSeeded();

    final where = <String>['is_active = 1'];
    final whereArgs = <dynamic>[];

    if (skill != null && skill.isNotEmpty) {
      where.add('skill = ?');
      whereArgs.add(skill);
    }
    if (hskLevel != null) {
      where.add('hsk_level = ?');
      whereArgs.add(hskLevel);
    }
    if (type != null) {
      where.add('type = ?');
      whereArgs.add(type.name);
    }

    final rows = await _db.query(
      DatabaseConstants.tablePracticeExercises,
      where: where.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'hsk_level ASC, id ASC',
    );

    return rows.map((r) => ExerciseDefinition.fromMap(r)).toList();
  }

  @override
  Future<ExerciseDefinition?> getExerciseById(String id) async {
    await _ensureCatalogSeeded();
    final rows = await _db.query(
      DatabaseConstants.tablePracticeExercises,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ExerciseDefinition.fromMap(rows.first);
  }

  @override
  Future<void> saveExercise(ExerciseDefinition def) async {
    await _db.insert(
      DatabaseConstants.tablePracticeExercises,
      def.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<PracticeSession> createSession({
    required String title,
    required String skill,
    int hskLevel = 1,
    required List<String> exerciseIds,
  }) async {
    final session = PracticeSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      skill: skill,
      hskLevel: hskLevel,
      exerciseIds: exerciseIds,
      currentIndex: 0,
      attempts: const [],
      status: PracticeSessionStatus.inProgress,
      startedAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    await _db.insert(
      DatabaseConstants.tablePracticeSessions,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return session;
  }

  @override
  Future<PracticeSession?> getActiveSession({String? skill}) async {
    final where = <String>["status = 'inProgress'"];
    final whereArgs = <dynamic>[];

    if (skill != null && skill.isNotEmpty) {
      where.add('skill = ?');
      whereArgs.add(skill);
    }

    final rows = await _db.query(
      DatabaseConstants.tablePracticeSessions,
      where: where.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final sessionMap = rows.first;
    final sessionId = sessionMap['id'] as String;

    // Load corresponding attempts
    final attemptRows = await _db.query(
      DatabaseConstants.tablePracticeAttempts,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    final attempts = attemptRows.map((r) => ExerciseAttempt.fromMap(r)).toList();

    return PracticeSession.fromMap(sessionMap, attempts: attempts);
  }

  @override
  Future<PracticeSession?> getSessionById(String sessionId) async {
    final rows = await _db.query(
      DatabaseConstants.tablePracticeSessions,
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final attemptRows = await _db.query(
      DatabaseConstants.tablePracticeAttempts,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    final attempts = attemptRows.map((r) => ExerciseAttempt.fromMap(r)).toList();

    return PracticeSession.fromMap(rows.first, attempts: attempts);
  }

  @override
  Future<void> updateSessionProgress(String sessionId, {required int currentIndex}) async {
    await _db.update(
      DatabaseConstants.tablePracticeSessions,
      {
        'current_index': currentIndex,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<ExerciseAttempt> recordAttempt({
    required String sessionId,
    required ExerciseAttempt attempt,
  }) async {
    final exercise = await getExerciseById(attempt.exerciseId);
    if (exercise != null) {
      return await _pipelineCoordinator.recordExerciseAttempt(
        sessionId: sessionId,
        attempt: attempt,
        exercise: exercise,
      );
    }

    // 1. Debounce and idempotency guard: check if attempt for (sessionId, exerciseId) already exists
    final existing = await _db.query(
      DatabaseConstants.tablePracticeAttempts,
      where: 'session_id = ? AND exercise_id = ?',
      whereArgs: [sessionId, attempt.exerciseId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // Return existing recorded attempt, preventing double score and duplicate evidence!
      return ExerciseAttempt.fromMap(existing.first);
    }

    // 2. Insert new attempt
    await _db.insert(
      DatabaseConstants.tablePracticeAttempts,
      attempt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 3. Update session updated_at
    await _db.update(
      DatabaseConstants.tablePracticeSessions,
      {'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    return attempt;
  }

  @override
  Future<PracticeSession> completeSession({
    required String sessionId,
    required int totalDurationMs,
  }) async {
    final attemptRows = await _db.query(
      DatabaseConstants.tablePracticeAttempts,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    final attempts = attemptRows.map((r) => ExerciseAttempt.fromMap(r)).toList();

    double meanScore = 0.0;
    if (attempts.isNotEmpty) {
      final total = attempts.fold<double>(0.0, (acc, a) => acc + a.result.score);
      meanScore = total / attempts.length;
    }

    final nowUtc = DateTime.now().toUtc();

    Future<void> executeCompletion(DatabaseExecutor executor) async {
      // 1. Update session to completed
      await executor.update(
        DatabaseConstants.tablePracticeSessions,
        {
          'status': PracticeSessionStatus.completed.name,
          'score': meanScore,
          'completed_at': nowUtc.toIso8601String(),
          'updated_at': nowUtc.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      // 2. Insert Learner Evidence only if attempts were made
      if (attempts.isNotEmpty) {
        await executor.insert(
          DatabaseConstants.tableLearnerEvidence,
          {
            'id': 'evi_practice_${DateTime.now().millisecondsSinceEpoch}',
            'content_id': sessionId,
            'content_type': 'practice',
            'source': 'practice_engine',
            'score': meanScore,
            'duration_ms': totalDurationMs,
            'metadata_json': json.encode({
              'attempts_count': attempts.length,
              'correct_count': attempts.where((a) => a.result.isCorrect).length,
              'exercise_ids': attempts.map((a) => a.exerciseId).toList(),
            }),
            'created_at': nowUtc.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 3. Record Learning Activity
        await executor.insert(
          DatabaseConstants.tableLearningActivities,
          {
            'id': 'act_practice_${DateTime.now().millisecondsSinceEpoch}',
            'activity_type': 'practice',
            'duration_seconds': (totalDurationMs / 1000).round(),
            'items_count': attempts.length,
            'activity_date': nowUtc.toIso8601String().substring(0, 10),
            'created_at': nowUtc.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    if (_db is Database) {
      await _db.transaction((txn) async {
        await executeCompletion(txn);
      });
    } else {
      await executeCompletion(_db);
    }

    final updatedSession = await getSessionById(sessionId);
    return updatedSession!;
  }

  @override
  Future<List<ExerciseAttempt>> getAttemptHistory(String exerciseId) async {
    final rows = await _db.query(
      DatabaseConstants.tablePracticeAttempts,
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => ExerciseAttempt.fromMap(r)).toList();
  }
}
