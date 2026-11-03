import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  final scriptPath = Platform.script.toFilePath();
  final projectRoot = p.dirname(p.dirname(scriptPath));

  String dbPath = p.join(projectRoot, 'hi_chinese_dev.db');
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--db' && i + 1 < args.length) {
      dbPath = args[i + 1];
    }
  }

  print('[SentencesImporter] Project root: $projectRoot');
  print('[SentencesImporter] Target database: $dbPath');
  final db = await databaseFactory.openDatabase(dbPath);

  // 1. Ensure Schema v15 tables exist
  await db.execute('''
    CREATE TABLE IF NOT EXISTS sentences (
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
    CREATE TABLE IF NOT EXISTS sentence_audio (
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
    CREATE TABLE IF NOT EXISTS sentence_practice_progress (
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

  await db.execute('CREATE INDEX IF NOT EXISTS idx_sentences_hsk ON sentences(hsk_level);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_sentences_topic ON sentences(topic);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_sent_audio_sent_id ON sentence_audio(sentence_id);');

  // 2. Load Sentences File
  final sentJsonFile = File(p.join(projectRoot, 'assets', 'data', 'sentences_corpus.json'));
  if (!sentJsonFile.existsSync()) {
    print('[SentencesImporter] Error: ${sentJsonFile.path} does not exist!');
    exit(1);
  }

  print('[SentencesImporter] Reading ${sentJsonFile.path}...');
  final rawJson = jsonDecode(await sentJsonFile.readAsString()) as Map<String, dynamic>;
  final sentences = rawJson['sentences'] as List;
  print('[SentencesImporter] Found ${sentences.length} sentences to import.');

  // 3. Batch import into database
  final batchSize = 100;
  int insertedCount = 0;

  for (int i = 0; i < sentences.length; i += batchSize) {
    final chunk = sentences.sublist(i, (i + batchSize < sentences.length) ? i + batchSize : sentences.length);
    final batch = db.batch();

    for (final item in chunk) {
      final map = item as Map<String, dynamic>;
      final sentId = map['id'] as String;

      batch.insert(
        'sentences',
        {
          'id': sentId,
          'chinese': map['chinese'],
          'traditional': map['traditional'] ?? '',
          'pinyin': map['pinyin'] ?? '',
          'pinyin_numbered': map['pinyin_numbered'] ?? '',
          'translation_vi': map['translation_vi'] ?? '',
          'translation_en': map['translation_en'] ?? '',
          'translation_vi_source': map['translation_vi_source'] ?? 'verified',
          'hsk_level': map['hsk_level'] ?? 1,
          'hsk_level_basis': map['hsk_level_basis'] ?? 'exact_match',
          'tokens_json': jsonEncode(map['tokens'] ?? []),
          'matched_vocab_ids_json': jsonEncode(map['matched_vocab_ids'] ?? []),
          'grammar_tags_json': jsonEncode(map['grammar_tags'] ?? []),
          'topic': map['topic'] ?? 'general',
          'contributor': map['contributor'] ?? '',
          'source': map['source'] ?? 'Tatoeba Project',
          'license': map['license'] ?? 'CC BY 2.0 FR',
          'has_human_audio': map['has_human_audio'] ?? 0,
          'has_tts_fallback': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final audios = map['audios'] as List? ?? [];
      for (final a in audios) {
        final aMap = a as Map<String, dynamic>;
        batch.insert(
          'sentence_audio',
          {
            'id': aMap['audio_id'] ?? '${sentId}_audio',
            'sentence_id': sentId,
            'audio_type': aMap['audio_type'] ?? 'studio_simulation',
            'speaker_name': aMap['speaker'] ?? aMap['speaker_name'] ?? '',
            'gender': aMap['gender'] ?? 'female',
            'accent': aMap['accent'] ?? 'zh-CN-Beijing',
            'speed_type': aMap['speed_type'] ?? 'normal',
            'url_remote': aMap['audio_url'] ?? aMap['url_remote'] ?? '',
            'local_path': aMap['local_path'],
            'status': aMap['status'] ?? 'remote',
            'file_format': aMap['file_format'] ?? 'mp3',
            'file_size_bytes': aMap['file_size_bytes'] ?? 0,
            'duration_ms': aMap['duration_ms'] ?? 0,
            'checksum_sha256': aMap['checksum_sha256'],
            'license': aMap['license'] ?? 'CC BY-NC 4.0',
            'attribution': aMap['attribution'] ?? aMap['attribution_url'] ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    await batch.commit(noResult: true);
    insertedCount += chunk.length;
    stdout.write('\r[SentencesImporter] Progress: $insertedCount / ${sentences.length} sentences inserted.');
  }

  print('\n[SentencesImporter] Successfully imported $insertedCount sentences into $dbPath.');
  await db.close();
}
