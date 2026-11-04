import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  final dbDir = Directory.current.path;
  final dbPath = p.join(dbDir, 'hi_chinese_dev.db');
  print('[Importer] Opening target database: $dbPath');

  final db = await databaseFactory.openDatabase(dbPath);

  // Ensure Schema v12 tables exist
  await db.execute('''
    CREATE TABLE IF NOT EXISTS vocabularies (
      id TEXT PRIMARY KEY,
      simplified TEXT NOT NULL,
      traditional TEXT,
      pinyin TEXT NOT NULL,
      pinyin_clean TEXT,
      pinyin_numeric TEXT,
      hanviet TEXT,
      hsk_level INTEGER NOT NULL,
      stroke_count INTEGER,
      radicals TEXT,
      frequency_rank INTEGER,
      audio_uri TEXT,
      source TEXT,
      license TEXT,
      verification_status TEXT DEFAULT 'verified',
      is_polyphone INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_vocab_simplified ON vocabularies (simplified);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_vocab_hsk_level ON vocabularies (hsk_level);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_vocab_pinyin_clean ON vocabularies (pinyin_clean);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_vocab_hanviet ON vocabularies (hanviet);');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS vocabulary_senses (
      id TEXT PRIMARY KEY,
      vocabulary_id TEXT NOT NULL,
      part_of_speech TEXT,
      meaning_vi TEXT NOT NULL,
      meaning_en TEXT,
      example_cn TEXT,
      example_pinyin TEXT,
      example_vi TEXT,
      example_en TEXT,
      source TEXT,
      order_index INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (vocabulary_id) REFERENCES vocabularies (id) ON DELETE CASCADE
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_vocab_senses_vocab_id ON vocabulary_senses (vocabulary_id);');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS vocabulary_examples (
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
      FOREIGN KEY (vocabulary_id) REFERENCES vocabularies (id) ON DELETE CASCADE
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_vocab_examples_vocab_id ON vocabulary_examples (vocabulary_id);');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS dictionary_entries (
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
  await db.execute('CREATE INDEX IF NOT EXISTS idx_dict_simplified ON dictionary_entries (simplified);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_dict_pinyin_clean ON dictionary_entries (pinyin_clean);');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS knowledge_registry (
      id TEXT PRIMARY KEY,
      entity_type TEXT NOT NULL,
      canonical_id TEXT NOT NULL,
      hsk_level INTEGER NOT NULL,
      title TEXT NOT NULL,
      is_deprecated INTEGER DEFAULT 0,
      replaced_by_id TEXT,
      package_id TEXT,
      metadata_json TEXT DEFAULT '{}',
      created_at TEXT,
      updated_at TEXT
    );
  ''');

  final importAll = args.contains('--all') || args.isEmpty;

  if (importAll) {
    final vocabFile = File('data_pipeline/processed/hsk_all_vocab.json');
    if (!vocabFile.existsSync()) {
      print('[Importer:Error] File not found: ${vocabFile.path}. Run data_pipeline/build_hsk_vocabulary_dataset.py first.');
      exit(1);
    }

    print('[Importer] Reading ${vocabFile.path}...');
    final data = json.decode(await vocabFile.readAsString()) as Map<String, dynamic>;
    final vocabs = data['vocabularies'] as List<dynamic>;
    print('[Importer] Found ${vocabs.length} vocabulary items to import.');

    final stopwatch = Stopwatch()..start();
    final now = DateTime.now().toUtc().toIso8601String();
    const batchSize = 100;

    for (int i = 0; i < vocabs.length; i += batchSize) {
      final end = (i + batchSize < vocabs.length) ? i + batchSize : vocabs.length;
      final chunk = vocabs.sublist(i, end);

      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final item in chunk) {
          final v = item as Map<String, dynamic>;
          final vId = v['id'] as String;

          batch.rawInsert('''
            INSERT INTO vocabularies (
              id, simplified, traditional, pinyin, pinyin_clean, hanviet, hsk_level,
              stroke_count, radicals, frequency_rank, audio_uri, source, license,
              verification_status, is_polyphone, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              simplified = excluded.simplified,
              traditional = excluded.traditional,
              pinyin = excluded.pinyin,
              pinyin_clean = excluded.pinyin_clean,
              hanviet = excluded.hanviet,
              hsk_level = excluded.hsk_level,
              frequency_rank = excluded.frequency_rank,
              source = excluded.source,
              license = excluded.license,
              verification_status = excluded.verification_status,
              is_polyphone = excluded.is_polyphone,
              updated_at = excluded.updated_at;
          ''', [
            vId,
            v['simplified'],
            v['traditional'],
            v['pinyin'],
            v['pinyin_clean'],
            v['hanviet'],
            v['hsk_level'],
            v['stroke_count'],
            v['radicals'],
            v['frequency_rank'],
            v['audio_uri'],
            v['source'],
            v['license'],
            v['verification_status'] ?? 'verified',
            v['is_polyphone'] ?? 0,
            now,
            now,
          ]);

          // Upsert knowledge_registry
          final canonId = v['canonical_id'] as String? ?? 'KNOW_VOCAB_${v['simplified']}';
          batch.rawInsert('''
            INSERT INTO knowledge_registry (
              id, entity_type, canonical_id, hsk_level, title, package_id, created_at, updated_at
            ) VALUES (?, 'vocabulary', ?, ?, ?, 'open_source_hsk', ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              title = excluded.title,
              hsk_level = excluded.hsk_level,
              updated_at = excluded.updated_at;
          ''', [
            canonId,
            v['simplified'],
            v['hsk_level'],
            v['simplified'],
            now,
            now,
          ]);

          final senses = v['senses'] as List<dynamic>? ?? [];
          for (final s in senses) {
            final sMap = s as Map<String, dynamic>;
            batch.rawInsert('''
              INSERT INTO vocabulary_senses (
                id, vocabulary_id, part_of_speech, meaning_vi, meaning_en,
                example_cn, example_pinyin, example_en, source, order_index,
                created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                part_of_speech = excluded.part_of_speech,
                meaning_vi = excluded.meaning_vi,
                meaning_en = excluded.meaning_en,
                example_cn = excluded.example_cn,
                example_pinyin = excluded.example_pinyin,
                example_en = excluded.example_en,
                source = excluded.source,
                order_index = excluded.order_index,
                updated_at = excluded.updated_at;
            ''', [
              sMap['id'],
              vId,
              sMap['part_of_speech'],
              sMap['meaning_vi'],
              sMap['meaning_en'],
              sMap['example_cn'],
              sMap['example_pinyin'],
              sMap['example_en'],
              sMap['source'],
              sMap['order_index'] ?? 1,
              now,
              now,
            ]);
          }

          final examples = v['examples'] as List<dynamic>? ?? [];
          for (final ex in examples) {
            final exMap = ex as Map<String, dynamic>;
            batch.rawInsert('''
              INSERT INTO vocabulary_examples (
                id, vocabulary_id, hsk_level, example_cn, example_pinyin,
                example_vi, example_en, audio_uri, source, order_index,
                created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                example_cn = excluded.example_cn,
                example_pinyin = excluded.example_pinyin,
                example_vi = excluded.example_vi,
                example_en = excluded.example_en,
                audio_uri = excluded.audio_uri,
                source = excluded.source,
                order_index = excluded.order_index,
                updated_at = excluded.updated_at;
            ''', [
              exMap['id'],
              vId,
              exMap['hsk_level'],
              exMap['example_cn'],
              exMap['example_pinyin'],
              exMap['example_vi'],
              exMap['example_en'],
              exMap['audio_uri'],
              exMap['source'],
              exMap['order_index'] ?? 1,
              now,
              now,
            ]);
          }
        }
        await batch.commit(noResult: true);
      });

      stdout.write('\r[Importer] Imported $end / ${vocabs.length} vocabularies...');
    }
    print('\n[Importer] Finished importing 5,000 HSK vocabularies in ${stopwatch.elapsedMilliseconds}ms.');
  }

  // Print statistics
  final countRow = await db.rawQuery('SELECT COUNT(*) as cnt FROM vocabularies;');
  final sensesRow = await db.rawQuery('SELECT COUNT(*) as cnt FROM vocabulary_senses;');
  final examplesRow = await db.rawQuery('SELECT COUNT(*) as cnt FROM vocabulary_examples;');
  final hskCounts = await db.rawQuery('SELECT hsk_level, COUNT(*) as cnt FROM vocabularies GROUP BY hsk_level ORDER BY hsk_level;');

  print('\n=== HI CHINESE DATABASE VOCABULARY STATISTICS ===');
  print('Total Vocabularies: ${countRow.first['cnt']}');
  print('Total Senses: ${sensesRow.first['cnt']}');
  print('Total Verified Examples: ${examplesRow.first['cnt']}');
  print('Breakdown by HSK:');
  for (final row in hskCounts) {
    print('  - HSK ${row['hsk_level']}: ${row['cnt']} words');
  }
  print('================================================\n');

  await db.close();
  // Remove temporary dev db file
  if (File(dbPath).existsSync()) {
    File(dbPath).deleteSync();
  }
  print('[Importer] All operations completed successfully.');
}
