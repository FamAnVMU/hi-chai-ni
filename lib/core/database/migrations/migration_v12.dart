import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v12: Adds normalized vocabulary enhancement columns (Han-Viet, clean Pinyin,
/// polyphone flags, source & license attribution), the vocabulary_examples table,
/// and the offline dictionary_entries table.
class MigrationV12 implements Migration {
  const MigrationV12();

  @override
  int get version => 12;

  @override
  String get description =>
      'Enhance vocabularies with Han-Viet & clean Pinyin, add vocabulary_examples and dictionary_entries tables';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Add enhancement columns to vocabularies table
    final vocabColumns = [
      'ALTER TABLE ${DatabaseConstants.tableVocabularies} ADD COLUMN hanviet TEXT;',
      'ALTER TABLE ${DatabaseConstants.tableVocabularies} ADD COLUMN pinyin_clean TEXT;',
      'ALTER TABLE ${DatabaseConstants.tableVocabularies} ADD COLUMN pinyin_numeric TEXT;',
      'ALTER TABLE ${DatabaseConstants.tableVocabularies} ADD COLUMN source TEXT;',
      'ALTER TABLE ${DatabaseConstants.tableVocabularies} ADD COLUMN license TEXT;',
      'ALTER TABLE ${DatabaseConstants.tableVocabularies} ADD COLUMN verification_status TEXT DEFAULT "verified";',
      'ALTER TABLE ${DatabaseConstants.tableVocabularies} ADD COLUMN is_polyphone INTEGER DEFAULT 0;',
    ];

    for (final sql in vocabColumns) {
      try {
        await db.execute(sql);
      } catch (e) {
        // Safe skip if column already added in fresh creation
      }
    }

    // 2. Add enhancement columns to vocabulary_senses table
    final senseColumns = [
      'ALTER TABLE ${DatabaseConstants.tableVocabularySenses} ADD COLUMN meaning_en TEXT;',
      'ALTER TABLE ${DatabaseConstants.tableVocabularySenses} ADD COLUMN example_en TEXT;',
      'ALTER TABLE ${DatabaseConstants.tableVocabularySenses} ADD COLUMN source TEXT;',
      'ALTER TABLE ${DatabaseConstants.tableVocabularySenses} ADD COLUMN order_index INTEGER DEFAULT 1;',
    ];

    for (final sql in senseColumns) {
      try {
        await db.execute(sql);
      } catch (e) {
        // Safe skip if column already exists
      }
    }

    // 3. Create vocabulary_examples table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableVocabularyExamples} (
        id TEXT PRIMARY KEY,
        vocabulary_id TEXT NOT NULL,
        sense_id TEXT,
        hsk_level INTEGER NOT NULL,
        example_cn TEXT NOT NULL,
        example_pinyin TEXT NOT NULL,
        example_vi TEXT,
        example_en TEXT,
        audio_uri TEXT,
        source TEXT,
        order_index INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vocabulary_id) REFERENCES ${DatabaseConstants.tableVocabularies} (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_vocab_examples_vocab_id 
      ON ${DatabaseConstants.tableVocabularyExamples} (vocabulary_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_vocab_examples_hsk_level 
      ON ${DatabaseConstants.tableVocabularyExamples} (hsk_level);
    ''');

    // 4. Create offline dictionary_entries table for general lexicon lookup
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableDictionaryEntries} (
        id TEXT PRIMARY KEY,
        simplified TEXT NOT NULL,
        traditional TEXT,
        pinyin TEXT NOT NULL,
        pinyin_clean TEXT NOT NULL,
        pinyin_numeric TEXT,
        hanviet TEXT,
        hsk_level INTEGER DEFAULT 0,
        meaning_vi TEXT NOT NULL,
        meaning_en TEXT,
        source TEXT DEFAULT 'CVDICT',
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dict_simplified 
      ON ${DatabaseConstants.tableDictionaryEntries} (simplified);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dict_pinyin_clean 
      ON ${DatabaseConstants.tableDictionaryEntries} (pinyin_clean);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dict_hsk_level 
      ON ${DatabaseConstants.tableDictionaryEntries} (hsk_level);
    ''');

    // 5. Add search indexes to vocabularies
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_vocab_pinyin_clean 
      ON ${DatabaseConstants.tableVocabularies} (pinyin_clean);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_vocab_hanviet 
      ON ${DatabaseConstants.tableVocabularies} (hanviet);
    ''');
  }
}
