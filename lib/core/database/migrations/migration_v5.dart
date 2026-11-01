import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v5: Adds tables for adaptive learning roadmap, learner goals,
/// lesson progress, and recommendations snapshots.
class MigrationV5 implements Migration {
  const MigrationV5();

  @override
  int get version => 5;

  @override
  String get description => 'Add learner goals, lesson progress, and roadmap snapshots tables for adaptive learning roadmap';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Learner Goals table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableLearnerGoals} (
        id TEXT PRIMARY KEY,
        target_hsk_level INTEGER NOT NULL DEFAULT 1,
        purpose TEXT NOT NULL DEFAULT 'daily_communication',
        timeframe TEXT NOT NULL DEFAULT 'standard',
        daily_minutes INTEGER NOT NULL DEFAULT 30,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_goals_active ON ${DatabaseConstants.tableLearnerGoals} (is_active, updated_at DESC);
    ''');

    // 2. Lesson Progress table (Personal learner progress decoupled from curriculum)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableLessonProgress} (
        id TEXT PRIMARY KEY,
        lesson_id TEXT NOT NULL UNIQUE,
        unit_id TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'locked',
        completion_score REAL,
        evidence_count INTEGER NOT NULL DEFAULT 0,
        started_at TEXT,
        completed_at TEXT,
        last_studied_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_lesson_progress_id ON ${DatabaseConstants.tableLessonProgress} (lesson_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_lesson_progress_status ON ${DatabaseConstants.tableLessonProgress} (status, hsk_level);
    ''');

    // 3. Roadmap Snapshots table (Cached calculated recommendations & mastery state)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableRoadmapSnapshots} (
        id TEXT PRIMARY KEY,
        current_level INTEGER NOT NULL,
        active_goal_id TEXT,
        recommendations_json TEXT NOT NULL,
        skill_mastery_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_roadmap_snapshots_date ON ${DatabaseConstants.tableRoadmapSnapshots} (updated_at DESC);
    ''');
  }
}
