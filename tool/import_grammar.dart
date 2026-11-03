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

  print('[GrammarImporter] Project root: $projectRoot');
  print('[GrammarImporter] Target database: $dbPath');
  final db = await databaseFactory.openDatabase(dbPath);

  // 1. Ensure Schema v13 tables exist
  await db.execute('''
    CREATE TABLE IF NOT EXISTS grammar_items (
      id TEXT PRIMARY KEY,
      grammar_id TEXT NOT NULL DEFAULT '',
      hsk_level INTEGER NOT NULL,
      code TEXT NOT NULL UNIQUE,
      pattern TEXT NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      title_vi TEXT NOT NULL,
      structure TEXT NOT NULL DEFAULT '',
      meaning_vi TEXT NOT NULL DEFAULT '',
      usage_conditions_vi TEXT NOT NULL DEFAULT '',
      sentence_position_vi TEXT NOT NULL DEFAULT '',
      explanation_vi TEXT NOT NULL,
      source TEXT NOT NULL DEFAULT '',
      topic_category TEXT NOT NULL DEFAULT 'other',
      topic_name_vi TEXT NOT NULL DEFAULT '',
      category_chinese TEXT NOT NULL DEFAULT '',
      category_english TEXT NOT NULL DEFAULT '',
      original_level TEXT NOT NULL DEFAULT '',
      hsk_level_mapped INTEGER NOT NULL DEFAULT 1,
      mapping_basis TEXT NOT NULL DEFAULT '',
      is_reference_only INTEGER NOT NULL DEFAULT 0,
      verification_status TEXT NOT NULL DEFAULT 'verified_open_source',
      license TEXT NOT NULL DEFAULT '',
      attribution TEXT NOT NULL DEFAULT '',
      wiki_link TEXT,
      tags_json TEXT NOT NULL DEFAULT '[]',
      related_vocab_ids_json TEXT NOT NULL DEFAULT '[]',
      related_grammar_ids_json TEXT NOT NULL DEFAULT '[]',
      prerequisite_grammar_ids_json TEXT NOT NULL DEFAULT '[]',
      examples_json TEXT NOT NULL DEFAULT '[]',
      contrastive_examples_json TEXT NOT NULL DEFAULT '[]',
      exercises_json TEXT NOT NULL DEFAULT '[]',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT
    );
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS grammar_examples (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      grammar_id TEXT NOT NULL,
      chinese TEXT NOT NULL,
      chinese_segmented TEXT,
      pinyin TEXT,
      translation_en TEXT,
      translation_vi TEXT,
      sound_ref TEXT,
      source TEXT,
      order_index INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY (grammar_id) REFERENCES grammar_items (id) ON DELETE CASCADE
    );
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS grammar_topics (
      code TEXT PRIMARY KEY,
      name_vi TEXT NOT NULL,
      name_zh TEXT NOT NULL,
      description_vi TEXT,
      display_order INTEGER NOT NULL DEFAULT 0
    );
  ''');

  await db.execute('CREATE INDEX IF NOT EXISTS idx_grammar_items_hsk ON grammar_items (hsk_level);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_grammar_items_mapped_hsk ON grammar_items (hsk_level_mapped);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_grammar_items_topic ON grammar_items (topic_category);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_grammar_examples_gid ON grammar_examples (grammar_id);');

  // 2. Read grammar_all.json
  final grammarJsonPath = p.join(projectRoot, 'data_pipeline', 'processed', 'grammar_all.json');
  if (!File(grammarJsonPath).existsSync()) {
    print('[GrammarImporter] ERROR: $grammarJsonPath does not exist. Run build_hsk_grammar_dataset.py first.');
    exit(1);
  }

  print('[GrammarImporter] Loading grammar data from $grammarJsonPath...');
  final rawJson = json.decode(await File(grammarJsonPath).readAsString()) as List<dynamic>;
  print('[GrammarImporter] Ingesting ${rawJson.length} grammar points...');

  final nowUtc = DateTime.now().toUtc().toIso8601String();
  int totalPoints = 0;
  int totalExamples = 0;
  final levelStats = <int, int>{};
  final topicStats = <String, int>{};

  await db.transaction((txn) async {
    for (final raw in rawJson) {
      final map = Map<String, dynamic>.from(raw as Map);
      final id = map['id'] as String;
      final hskLevel = map['hsk_level'] as int? ?? 1;
      final code = map['code'] as String? ?? id;
      final title = map['title'] as String? ?? '';
      final structure = map['structure'] as String? ?? '';
      final explanation = map['explanation'] as String? ?? '';
      final topicCategory = map['topic_category'] as String? ?? 'other';
      final topicNameVi = map['topic_name_vi'] as String? ?? '';
      final categoryCn = map['category_chinese'] as String? ?? '';
      final categoryEn = map['category_english'] as String? ?? '';
      final originalLevel = map['original_level'] as String? ?? '';
      final mappingBasis = map['mapping_basis'] as String? ?? '';
      final isRef = (map['is_reference_only'] == true) ? 1 : 0;
      final status = map['verification_status'] as String? ?? 'verified_open_source';
      final source = map['source'] as String? ?? '';
      final license = map['license'] as String? ?? '';
      final attribution = map['attribution'] as String? ?? '';
      final wikiLink = map['wiki_link'] as String?;
      final rawExamples = (map['examples'] as List?) ?? [];

      levelStats[hskLevel] = (levelStats[hskLevel] ?? 0) + 1;
      topicStats[topicCategory] = (topicStats[topicCategory] ?? 0) + 1;

      // Insert/replace grammar_item
      await txn.insert(
        'grammar_items',
        {
          'id': id,
          'grammar_id': id,
          'hsk_level': hskLevel,
          'code': code,
          'pattern': structure,
          'structure': structure,
          'title': title,
          'title_vi': title,
          'meaning_vi': explanation,
          'explanation_vi': explanation,
          'usage_conditions_vi': '',
          'sentence_position_vi': '',
          'source': source,
          'topic_category': topicCategory,
          'topic_name_vi': topicNameVi,
          'category_chinese': categoryCn,
          'category_english': categoryEn,
          'original_level': originalLevel,
          'hsk_level_mapped': hskLevel,
          'mapping_basis': mappingBasis,
          'is_reference_only': isRef,
          'verification_status': status,
          'license': license,
          'attribution': attribution,
          'wiki_link': wikiLink,
          'tags_json': json.encode(categoryEn.split(',')),
          'related_vocab_ids_json': '[]',
          'related_grammar_ids_json': '[]',
          'prerequisite_grammar_ids_json': '[]',
          'examples_json': json.encode(rawExamples),
          'contrastive_examples_json': '[]',
          'exercises_json': '[]',
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      totalPoints++;

      // Insert relational examples
      int orderIdx = 0;
      for (final exRaw in rawExamples) {
        final ex = Map<String, dynamic>.from(exRaw as Map);
        final zh = ex['chinese'] as String? ?? ex['hanzi'] as String? ?? '';
        final segZh = ex['chinese_segmented'] as String?;
        final py = ex['pinyin'] as String? ?? '';
        final en = ex['translation_en'] as String? ?? '';
        final vi = ex['translation_vi'] as String? ?? '';
        final sound = ex['sound_ref'] as String? ?? '';
        final exSource = ex['source'] as String? ?? source;

        await txn.insert(
          'grammar_examples',
          {
            'grammar_id': id,
            'chinese': zh,
            'chinese_segmented': segZh,
            'pinyin': py,
            'translation_en': en,
            'translation_vi': vi,
            'sound_ref': sound,
            'source': exSource,
            'order_index': orderIdx++,
            'created_at': nowUtc,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        totalExamples++;
      }
    }
  });

  print('\n=== IMPORT SUMMARY ===');
  print('Total Grammar Items: $totalPoints');
  print('Total Grammar Examples: $totalExamples');
  print('\nDistribution by HSK Level:');
  for (final lvl in [1, 2, 3, 4, 5, 6]) {
    print('  HSK $lvl: ${levelStats[lvl] ?? 0} points');
  }
  print('\nDistribution by Topic:');
  for (final entry in topicStats.entries) {
    print('  ${entry.key}: ${entry.value} points');
  }

  await db.close();
  print('\nDatabase import completed successfully!');
}
