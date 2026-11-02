import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v8: Adds tables for user profile, goal change history, and app settings.
class MigrationV8 implements Migration {
  const MigrationV8();

  @override
  int get version => 8;

  @override
  String get description => 'Add user profile, goal change history, and app settings tables';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. User Profiles table (Local Standalone Learner Profile)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableUserProfiles} (
        id TEXT PRIMARY KEY,
        display_name TEXT,
        current_hsk_level INTEGER NOT NULL DEFAULT 1,
        target_hsk_level INTEGER NOT NULL DEFAULT 3,
        purpose TEXT NOT NULL DEFAULT 'daily_communication',
        timeframe TEXT NOT NULL DEFAULT 'standard',
        daily_minutes INTEGER NOT NULL DEFAULT 30,
        start_date TEXT NOT NULL,
        interests_json TEXT NOT NULL DEFAULT '[]',
        avatar_style TEXT NOT NULL DEFAULT 'panda',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 2. Goal History table (Meaningful historical records of learning goal adjustments)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableGoalHistory} (
        id TEXT PRIMARY KEY,
        previous_target_hsk INTEGER NOT NULL,
        new_target_hsk INTEGER NOT NULL,
        previous_daily_minutes INTEGER NOT NULL,
        new_daily_minutes INTEGER NOT NULL,
        previous_purpose TEXT NOT NULL,
        new_purpose TEXT NOT NULL,
        reason TEXT NOT NULL,
        changed_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_goal_history_date ON ${DatabaseConstants.tableGoalHistory} (changed_at DESC);
    ''');

    // 3. App Settings key-value table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableAppSettings} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
  }
}
