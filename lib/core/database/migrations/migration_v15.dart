import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v15: Sentence Library, Offline Audio Packs & Shadowing Engine
/// Adds relational storage for Chinese example sentences (Tatoeba + HSK Corpus),
/// multi-source audio tracks (Human recording, Native OS TTS, Studio simulation),
/// and learner practice/shadowing progress decoupled from curriculum content packs.
class MigrationV15 implements Migration {
  const MigrationV15();

  @override
  int get version => 15;

  @override
  String get description =>
      'Create sentences, sentence_audio, and sentence_practice_progress tables';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Create sentences table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSentences} (
        id TEXT PRIMARY KEY,
        chinese TEXT NOT NULL,
        traditional TEXT,
        pinyin TEXT NOT NULL,
        pinyin_numbered TEXT,
        translation_vi TEXT,
        translation_en TEXT,
        translation_vi_source TEXT NOT NULL DEFAULT 'verified',
        hsk_level INTEGER NOT NULL DEFAULT 1,
        hsk_level_basis TEXT NOT NULL DEFAULT 'exact_match',
        tokens_json TEXT,
        matched_vocab_ids_json TEXT,
        grammar_tags_json TEXT,
        topic TEXT NOT NULL DEFAULT 'general',
        contributor TEXT,
        source TEXT NOT NULL DEFAULT 'Tatoeba Project',
        license TEXT NOT NULL DEFAULT 'CC BY 2.0 FR',
        has_human_audio INTEGER NOT NULL DEFAULT 0,
        has_tts_fallback INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sentences_hsk 
      ON ${DatabaseConstants.tableSentences}(hsk_level);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sentences_topic 
      ON ${DatabaseConstants.tableSentences}(topic);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sentences_audio 
      ON ${DatabaseConstants.tableSentences}(has_human_audio);
    ''');

    // 2. Create sentence_audio table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSentenceAudio} (
        id TEXT PRIMARY KEY,
        sentence_id TEXT NOT NULL,
        audio_type TEXT NOT NULL,
        speaker_name TEXT,
        gender TEXT DEFAULT 'female',
        accent TEXT DEFAULT 'zh-CN-Beijing',
        speed_type TEXT NOT NULL DEFAULT 'normal',
        url_remote TEXT,
        local_path TEXT,
        status TEXT NOT NULL DEFAULT 'remote',
        file_format TEXT NOT NULL DEFAULT 'mp3',
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        checksum_sha256 TEXT,
        license TEXT NOT NULL DEFAULT 'CC BY-NC 4.0',
        attribution TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sent_audio_sent_id 
      ON ${DatabaseConstants.tableSentenceAudio}(sentence_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sent_audio_type 
      ON ${DatabaseConstants.tableSentenceAudio}(audio_type);
    ''');

    // 3. Create sentence_practice_progress table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSentencePracticeProgress} (
        id TEXT PRIMARY KEY,
        sentence_id TEXT NOT NULL UNIQUE,
        hsk_level INTEGER NOT NULL DEFAULT 1,
        listening_attempts INTEGER NOT NULL DEFAULT 0,
        shadowing_attempts INTEGER NOT NULL DEFAULT 0,
        reading_attempts INTEGER NOT NULL DEFAULT 0,
        last_score REAL NOT NULL DEFAULT 0.0,
        best_score REAL NOT NULL DEFAULT 0.0,
        last_practiced_at TEXT,
        last_shadowing_audio_path TEXT,
        mastery_level TEXT NOT NULL DEFAULT 'new',
        srs_due_date TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sent_prog_sent_id 
      ON ${DatabaseConstants.tableSentencePracticeProgress}(sentence_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sent_prog_due 
      ON ${DatabaseConstants.tableSentencePracticeProgress}(srs_due_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sent_prog_mastery 
      ON ${DatabaseConstants.tableSentencePracticeProgress}(mastery_level);
    ''');
  }

  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableSentencePracticeProgress};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableSentenceAudio};');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseConstants.tableSentences};');
  }
}
