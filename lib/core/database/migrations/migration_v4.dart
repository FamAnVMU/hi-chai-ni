import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v4: Adds tables for dictionary search history, user saved words (favorites & notes),
/// and reading passage comprehension progress.
class MigrationV4 implements Migration {
  const MigrationV4();

  @override
  int get version => 4;

  @override
  String get description => 'Add dictionary history, saved words, and reading progress tables';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Dictionary Search History table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableDictionaryHistory} (
        id TEXT PRIMARY KEY,
        query TEXT NOT NULL,
        search_type TEXT NOT NULL DEFAULT 'text',
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dict_history_created ON ${DatabaseConstants.tableDictionaryHistory} (created_at DESC);
    ''');

    // 2. User Saved Words table (Favorites & Custom Notes)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableUserSavedWords} (
        id TEXT PRIMARY KEY,
        vocabulary_id TEXT NOT NULL UNIQUE,
        simplified TEXT NOT NULL,
        pinyin TEXT NOT NULL,
        custom_note TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vocabulary_id) REFERENCES ${DatabaseConstants.tableVocabularies} (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_saved_words_vocab ON ${DatabaseConstants.tableUserSavedWords} (vocabulary_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_saved_words_favorite ON ${DatabaseConstants.tableUserSavedWords} (is_favorite, updated_at DESC);
    ''');

    // 3. Reading Progress table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableReadingProgress} (
        id TEXT PRIMARY KEY,
        passage_id TEXT NOT NULL UNIQUE,
        last_scroll_offset REAL NOT NULL DEFAULT 0.0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        reading_time_seconds INTEGER NOT NULL DEFAULT 0,
        answers_json TEXT,
        score REAL,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (passage_id) REFERENCES ${DatabaseConstants.tableReadingPassages} (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reading_progress_passage ON ${DatabaseConstants.tableReadingProgress} (passage_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reading_progress_status ON ${DatabaseConstants.tableReadingProgress} (is_completed, updated_at DESC);
    ''');
  }
}
