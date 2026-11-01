import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v7: Creates practice_exercises, practice_sessions, and practice_attempts tables
/// for the shared interactive practice engine across all learning modules.
class MigrationV7 implements Migration {
  const MigrationV7();

  @override
  int get version => 7;

  @override
  String get description => 'Create practice_exercises, practice_sessions, and practice_attempts tables';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Practice Exercises Catalog
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePracticeExercises} (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        skill TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        prompt TEXT NOT NULL,
        stimulus TEXT,
        stimulus_pinyin TEXT,
        stimulus_audio_uri TEXT,
        payload_json TEXT NOT NULL,
        rubric_json TEXT,
        explanation_vi TEXT NOT NULL,
        metadata_json TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_practice_exercises_type_skill 
      ON ${DatabaseConstants.tablePracticeExercises} (type, skill, hsk_level);
    ''');

    // 2. Practice Sessions (Supports pausing & resumption)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePracticeSessions} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        skill TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        exercise_ids_json TEXT NOT NULL,
        current_index INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'inProgress',
        score REAL,
        started_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_practice_sessions_status_skill 
      ON ${DatabaseConstants.tablePracticeSessions} (status, skill);
    ''');

    // 3. Practice Attempts (Detailed per-question attempt log with idempotency tracking)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePracticeAttempts} (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        answer_json TEXT NOT NULL,
        score REAL NOT NULL,
        is_correct INTEGER NOT NULL,
        confidence REAL NOT NULL,
        needs_human_review INTEGER NOT NULL DEFAULT 0,
        evaluator_type TEXT NOT NULL DEFAULT 'deterministic',
        feedback_vi TEXT NOT NULL,
        ai_metadata_json TEXT,
        breakdown_json TEXT,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES ${DatabaseConstants.tablePracticeSessions} (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES ${DatabaseConstants.tablePracticeExercises} (id) ON DELETE CASCADE,
        UNIQUE (session_id, exercise_id)
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_practice_attempts_session 
      ON ${DatabaseConstants.tablePracticeAttempts} (session_id, created_at);
    ''');
  }
}
