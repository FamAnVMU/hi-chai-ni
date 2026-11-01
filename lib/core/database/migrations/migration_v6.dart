import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v6: Enhances grammar_items with rich pedagogical attributes
/// and creates grammar_progress table for tracking mastery, exercises, and evidence.
class MigrationV6 implements Migration {
  const MigrationV6();

  @override
  int get version => 6;

  @override
  String get description => 'Enhance grammar_items with contrastive examples, rules, and add grammar_progress table';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Add rich pedagogical columns to grammar_items if not already present
    final columnsToAdd = <String, String>{
      'title': "TEXT NOT NULL DEFAULT ''",
      'structure': "TEXT NOT NULL DEFAULT ''",
      'meaning_vi': "TEXT NOT NULL DEFAULT ''",
      'usage_conditions_vi': "TEXT NOT NULL DEFAULT ''",
      'sentence_position_vi': "TEXT NOT NULL DEFAULT ''",
      'source': "TEXT NOT NULL DEFAULT ''",
      'tags_json': "TEXT NOT NULL DEFAULT '[]'",
      'related_vocab_ids_json': "TEXT NOT NULL DEFAULT '[]'",
      'related_grammar_ids_json': "TEXT NOT NULL DEFAULT '[]'",
      'prerequisite_grammar_ids_json': "TEXT NOT NULL DEFAULT '[]'",
      'contrastive_examples_json': "TEXT NOT NULL DEFAULT '[]'",
      'exercises_json': "TEXT NOT NULL DEFAULT '[]'",
    };

    // Check existing columns
    final tableInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableGrammarItems})');
    final existingColumns = tableInfo.map((row) => row['name'] as String).toSet();

    for (final entry in columnsToAdd.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE ${DatabaseConstants.tableGrammarItems} ADD COLUMN ${entry.key} ${entry.value};',
        );
      }
    }

    // 2. Grammar Progress table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableGrammarProgress} (
        id TEXT PRIMARY KEY,
        grammar_id TEXT NOT NULL UNIQUE,
        hsk_level INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'unlearned',
        mastery_score REAL,
        exercises_completed INTEGER NOT NULL DEFAULT 0,
        last_studied_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (grammar_id) REFERENCES ${DatabaseConstants.tableGrammarItems} (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_grammar_progress_status ON ${DatabaseConstants.tableGrammarProgress} (status, hsk_level);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_grammar_items_hsk ON ${DatabaseConstants.tableGrammarItems} (hsk_level);
    ''');
  }
}
