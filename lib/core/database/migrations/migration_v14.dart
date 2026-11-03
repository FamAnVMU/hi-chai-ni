import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v14: Offline Hanzi Stroke Order & Handwriting Engine
/// Adds relational storage for verified Chinese character vector graphics,
/// stroke order medians (Make Me a Hanzi / Hanzi Writer), and an independent
/// handwriting learning progress and SRS review table.
class MigrationV14 implements Migration {
  const MigrationV14();

  @override
  int get version => 14;

  @override
  String get description =>
      'Create hanzi_characters and hanzi_writing_progress tables with offline vector stroke data';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Create hanzi_characters table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableHanziCharacters} (
        id TEXT PRIMARY KEY,
        character TEXT NOT NULL UNIQUE,
        stroke_count INTEGER NOT NULL,
        hsk_level INTEGER NOT NULL DEFAULT 1,
        all_hsk_levels TEXT,
        pinyin TEXT,
        hanviet TEXT,
        meaning_vi TEXT,
        definition_en TEXT,
        radical TEXT,
        decomposition TEXT,
        strokes_json TEXT NOT NULL,
        medians_json TEXT NOT NULL,
        sample_words_json TEXT,
        is_supported INTEGER NOT NULL DEFAULT 1,
        source TEXT NOT NULL DEFAULT 'Make Me a Hanzi',
        license TEXT NOT NULL DEFAULT 'Arphic Public License / OFL',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hanzi_char 
      ON ${DatabaseConstants.tableHanziCharacters}(character);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hanzi_hsk 
      ON ${DatabaseConstants.tableHanziCharacters}(hsk_level);
    ''');

    // 2. Create hanzi_writing_progress table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableHanziWritingProgress} (
        id TEXT PRIMARY KEY,
        character TEXT NOT NULL UNIQUE,
        hsk_level INTEGER NOT NULL DEFAULT 1,
        practice_count INTEGER NOT NULL DEFAULT 0,
        test_count INTEGER NOT NULL DEFAULT 0,
        last_accuracy_score REAL NOT NULL DEFAULT 0.0,
        best_accuracy_score REAL NOT NULL DEFAULT 0.0,
        mistakes_count INTEGER NOT NULL DEFAULT 0,
        stroke_order_errors INTEGER NOT NULL DEFAULT 0,
        last_practiced_at TEXT,
        mastery_level TEXT NOT NULL DEFAULT 'new',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        srs_due_date TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hanzi_prog_char 
      ON ${DatabaseConstants.tableHanziWritingProgress}(character);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hanzi_prog_due 
      ON ${DatabaseConstants.tableHanziWritingProgress}(srs_due_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hanzi_prog_mastery 
      ON ${DatabaseConstants.tableHanziWritingProgress}(mastery_level);
    ''');
  }

  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableHanziWritingProgress};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableHanziCharacters};');
  }
}
