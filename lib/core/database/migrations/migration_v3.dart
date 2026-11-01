import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v3: Adds `placement_test_sessions` and `placement_test_responses` tables
/// for Computerized Adaptive Testing (CAT) across 6 skill dimensions.
class MigrationV3 implements Migration {
  const MigrationV3();

  @override
  int get version => 3;

  @override
  String get description => 'Add placement test sessions and responses tables for CAT assessment';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Placement Test Sessions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePlacementTestSessions} (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        current_step_index INTEGER NOT NULL DEFAULT 0,
        estimated_theta REAL NOT NULL DEFAULT 0.0,
        standard_error REAL NOT NULL DEFAULT 1.0,
        overall_hsk_band TEXT,
        confidence_level REAL NOT NULL DEFAULT 0.0,
        skill_scores_json TEXT NOT NULL,
        knowledge_gaps_json TEXT NOT NULL,
        recommended_level INTEGER NOT NULL DEFAULT 1,
        recommended_roadmap_code TEXT,
        blueprint_version TEXT NOT NULL DEFAULT 'v1.0',
        started_at TEXT NOT NULL,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cat_sessions_status ON ${DatabaseConstants.tablePlacementTestSessions} (status, updated_at);
    ''');

    // 2. Placement Test Responses table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePlacementTestResponses} (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        skill TEXT NOT NULL,
        writing_sub_type TEXT,
        speaking_evaluation_mode TEXT,
        item_difficulty REAL NOT NULL,
        hsk_target INTEGER NOT NULL,
        is_calibration_item INTEGER NOT NULL DEFAULT 0,
        user_answer TEXT,
        is_correct INTEGER,
        is_skipped INTEGER NOT NULL DEFAULT 0,
        latency_ms INTEGER NOT NULL DEFAULT 0,
        metadata_json TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES ${DatabaseConstants.tablePlacementTestSessions} (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cat_responses_session ON ${DatabaseConstants.tablePlacementTestResponses} (session_id, skill);
    ''');
  }
}
