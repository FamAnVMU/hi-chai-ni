import 'package:sqflite/sqflite.dart';
import 'migration.dart';

/// Migration v2: Adds `seed_history` table for tracking idempotent asset datasets,
/// versioning, checksum validation, and safe retry state.
class MigrationV2 implements Migration {
  const MigrationV2();

  @override
  int get version => 2;

  @override
  String get description => 'Add seed_history table for idempotent asset seed tracking';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS seed_history (
        bundle_name TEXT PRIMARY KEY,
        version INTEGER NOT NULL,
        checksum TEXT NOT NULL,
        status TEXT NOT NULL,
        total_items INTEGER NOT NULL DEFAULT 0,
        applied_items INTEGER NOT NULL DEFAULT 0,
        applied_at TEXT NOT NULL,
        error_message TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_seed_history_status ON seed_history(status);
    ''');

    // Performance composite indexes for rapid retrieval in AI Tutor & Context Builder
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_evidence_type_score ON learner_evidence (content_type, score, created_at);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_chat_messages_lookup ON chat_messages (session_id, role, created_at);
    ''');
  }
}
