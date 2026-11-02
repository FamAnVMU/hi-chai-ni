import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v11: Adds audio asset management table and Pinyin progress tracking table.
class MigrationV11 implements Migration {
  const MigrationV11();

  @override
  int get version => 11;

  @override
  String get description =>
      'Add offline audio asset management table and Pinyin foundation progress tracking table';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Audio Assets Table (Metadata, offline storage paths, checksums, licenses)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableAudioAssets} (
        id TEXT PRIMARY KEY,
        package_id TEXT NOT NULL,
        content_id TEXT NOT NULL,
        audio_type TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        speaker_id TEXT DEFAULT 'native_zh',
        file_format TEXT NOT NULL DEFAULT 'mp3',
        sample_rate INTEGER NOT NULL DEFAULT 44100,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        checksum_sha256 TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        local_path TEXT,
        status TEXT NOT NULL DEFAULT 'remote',
        source TEXT,
        license TEXT,
        transcript_zh TEXT,
        transcript_vi TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_audio_assets_package 
      ON ${DatabaseConstants.tableAudioAssets} (package_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_audio_assets_content 
      ON ${DatabaseConstants.tableAudioAssets} (content_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_audio_assets_status 
      ON ${DatabaseConstants.tableAudioAssets} (status);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_audio_assets_level_type 
      ON ${DatabaseConstants.tableAudioAssets} (hsk_level, audio_type);
    ''');

    // 2. Pinyin Foundation Progress Tracking Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePinyinProgress} (
        id TEXT PRIMARY KEY,
        pinyin_item_id TEXT NOT NULL UNIQUE,
        item_type TEXT NOT NULL,
        mastery_state TEXT NOT NULL DEFAULT 'not_started',
        attempts_count INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        score REAL NOT NULL DEFAULT 0.0,
        last_practiced_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pinyin_progress_state 
      ON ${DatabaseConstants.tablePinyinProgress} (item_type, mastery_state);
    ''');
  }
}
