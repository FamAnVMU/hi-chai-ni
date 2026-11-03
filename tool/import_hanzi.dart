import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  // Resolve project root from script location
  final scriptPath = Platform.script.toFilePath();
  final projectRoot = p.dirname(p.dirname(scriptPath));

  String dbPath = p.join(projectRoot, 'hi_chinese_dev.db');
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--db' && i + 1 < args.length) {
      dbPath = args[i + 1];
    }
  }

  print('[HanziImporter] Project root: $projectRoot');
  print('[HanziImporter] Target database: $dbPath');
  final db = await databaseFactory.openDatabase(dbPath);

  // 1. Ensure Schema v14 tables exist
  await db.execute('''
    CREATE TABLE IF NOT EXISTS hanzi_characters (
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
    CREATE TABLE IF NOT EXISTS hanzi_writing_progress (
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

  await db.execute('CREATE INDEX IF NOT EXISTS idx_hanzi_char ON hanzi_characters(character);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_hanzi_hsk ON hanzi_characters(hsk_level);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_hanzi_prog_char ON hanzi_writing_progress(character);');

  // 2. Load Hanzi Dataset
  final hanziJsonFile = File(p.join(projectRoot, 'data_pipeline', 'processed', 'hanzi_all.json'));
  if (!hanziJsonFile.existsSync()) {
    print('[HanziImporter] Error: ${hanziJsonFile.path} does not exist!');
    exit(1);
  }

  print('[HanziImporter] Reading ${hanziJsonFile.path}...');
  final rawJson = jsonDecode(await hanziJsonFile.readAsString()) as Map<String, dynamic>;
  final characters = rawJson['characters'] as List;
  print('[HanziImporter] Found ${characters.length} characters to import.');

  // 3. Batch import into database
  final batchSize = 100;
  int insertedCount = 0;

  for (int i = 0; i < characters.length; i += batchSize) {
    final chunk = characters.sublist(i, (i + batchSize < characters.length) ? i + batchSize : characters.length);
    final batch = db.batch();

    for (final item in chunk) {
      final map = item as Map<String, dynamic>;
      batch.insert(
        'hanzi_characters',
        {
          'id': map['id'],
          'character': map['character'],
          'stroke_count': map['stroke_count'],
          'hsk_level': map['hsk_level'],
          'all_hsk_levels': jsonEncode(map['all_hsk_levels'] ?? [map['hsk_level']]),
          'pinyin': map['pinyin'] ?? '',
          'hanviet': map['hanviet'] ?? '',
          'meaning_vi': map['meaning_vi'] ?? '',
          'definition_en': map['definition_en'] ?? '',
          'radical': map['radical'] ?? '',
          'decomposition': map['decomposition'] ?? '',
          'strokes_json': jsonEncode(map['strokes']),
          'medians_json': jsonEncode(map['medians']),
          'sample_words_json': jsonEncode(map['sample_words'] ?? []),
          'is_supported': map['is_supported'] ?? 1,
          'source': map['source'] ?? 'Make Me a Hanzi',
          'license': map['license'] ?? 'Arphic Public License / OFL',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    insertedCount += chunk.length;
    stdout.write('\r[HanziImporter] Progress: $insertedCount / ${characters.length} characters inserted.');
  }

  print('\n[HanziImporter] Successfully imported $insertedCount characters into $dbPath.');
  await db.close();
}
