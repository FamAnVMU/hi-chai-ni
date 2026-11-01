import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

class MigrationV1 implements Migration {
  const MigrationV1();

  @override
  int get version => 1;

  @override
  String get description => 'Initial core offline-first schema v1 for HI Chinese';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Vocabularies table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableVocabularies} (
        id TEXT PRIMARY KEY,
        simplified TEXT NOT NULL,
        traditional TEXT,
        pinyin TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        stroke_count INTEGER,
        radicals TEXT,
        frequency_rank INTEGER,
        audio_uri TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');
    await db.execute('CREATE INDEX idx_vocab_simplified ON ${DatabaseConstants.tableVocabularies} (simplified);');
    await db.execute('CREATE INDEX idx_vocab_hsk_level ON ${DatabaseConstants.tableVocabularies} (hsk_level);');
    await db.execute('CREATE INDEX idx_vocab_deleted_at ON ${DatabaseConstants.tableVocabularies} (deleted_at);');

    // 2. Vocabulary Senses table (one-to-many relationship for multiple definitions/meanings)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableVocabularySenses} (
        id TEXT PRIMARY KEY,
        vocabulary_id TEXT NOT NULL,
        part_of_speech TEXT,
        meaning_vi TEXT NOT NULL,
        example_cn TEXT,
        example_pinyin TEXT,
        example_vi TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (vocabulary_id) REFERENCES ${DatabaseConstants.tableVocabularies} (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX idx_vocab_senses_vocab_id ON ${DatabaseConstants.tableVocabularySenses} (vocabulary_id);');

    // 3. Grammar Items table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableGrammarItems} (
        id TEXT PRIMARY KEY,
        hsk_level INTEGER NOT NULL,
        code TEXT NOT NULL UNIQUE,
        pattern TEXT NOT NULL,
        title_vi TEXT NOT NULL,
        explanation_vi TEXT NOT NULL,
        examples_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');
    await db.execute('CREATE INDEX idx_grammar_hsk_level ON ${DatabaseConstants.tableGrammarItems} (hsk_level);');

    // 4. Reading Passages table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableReadingPassages} (
        id TEXT PRIMARY KEY,
        hsk_level INTEGER NOT NULL,
        title_cn TEXT NOT NULL,
        content_cn TEXT NOT NULL,
        pinyin TEXT,
        translation_vi TEXT NOT NULL,
        audio_uri TEXT,
        questions_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');
    await db.execute('CREATE INDEX idx_reading_hsk_level ON ${DatabaseConstants.tableReadingPassages} (hsk_level);');

    // 5. SRS Items table (Spaced Repetition System state)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSrsItems} (
        id TEXT PRIMARY KEY,
        content_id TEXT NOT NULL,
        content_type TEXT NOT NULL,
        state TEXT NOT NULL DEFAULT 'new',
        interval_days INTEGER NOT NULL DEFAULT 0,
        ease_factor REAL NOT NULL DEFAULT 2.5,
        repetitions INTEGER NOT NULL DEFAULT 0,
        lapses INTEGER NOT NULL DEFAULT 0,
        due_at TEXT NOT NULL,
        last_reviewed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');
    await db.execute('CREATE INDEX idx_srs_content ON ${DatabaseConstants.tableSrsItems} (content_id, content_type);');
    await db.execute('CREATE INDEX idx_srs_due_state ON ${DatabaseConstants.tableSrsItems} (due_at, state);');

    // 6. Learner Evidence table (Append-only learning history log)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableLearnerEvidence} (
        id TEXT PRIMARY KEY,
        srs_item_id TEXT,
        content_id TEXT NOT NULL,
        content_type TEXT NOT NULL,
        source TEXT NOT NULL,
        score REAL NOT NULL,
        duration_ms INTEGER NOT NULL,
        metadata_json TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (srs_item_id) REFERENCES ${DatabaseConstants.tableSrsItems} (id) ON DELETE SET NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_evidence_content ON ${DatabaseConstants.tableLearnerEvidence} (content_id, content_type);');
    await db.execute('CREATE INDEX idx_evidence_created_at ON ${DatabaseConstants.tableLearnerEvidence} (created_at);');

    // 7. Mastery Snapshots table (Calculated aggregated mastery state per HSK level)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableMasterySnapshots} (
        id TEXT PRIMARY KEY,
        hsk_level INTEGER NOT NULL,
        total_items INTEGER NOT NULL,
        mastered_items INTEGER NOT NULL,
        review_items INTEGER NOT NULL,
        accuracy_rate REAL NOT NULL,
        snapshot_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (hsk_level, snapshot_date)
      );
    ''');
    await db.execute('CREATE INDEX idx_mastery_snapshot_date ON ${DatabaseConstants.tableMasterySnapshots} (snapshot_date);');

    // 8. Chat Sessions table (AI Tutor conversations)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableChatSessions} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        scenario_code TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');
    await db.execute('CREATE INDEX idx_chat_sessions_updated ON ${DatabaseConstants.tableChatSessions} (updated_at);');

    // 9. Chat Messages table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableChatMessages} (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        pinyin TEXT,
        translation_vi TEXT,
        audio_uri TEXT,
        tokens_used INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES ${DatabaseConstants.tableChatSessions} (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX idx_chat_messages_session ON ${DatabaseConstants.tableChatMessages} (session_id, created_at);');

    // 10. Learning Activities table (Daily streaks & study duration)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableLearningActivities} (
        id TEXT PRIMARY KEY,
        activity_type TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        items_count INTEGER NOT NULL DEFAULT 0,
        activity_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_activity_date ON ${DatabaseConstants.tableLearningActivities} (activity_date);');
  }
}
