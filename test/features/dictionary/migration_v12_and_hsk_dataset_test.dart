import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/dictionary/dictionary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late DictionaryRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('v12_test_');
    final dbPath = '${tempDir.path}/test_v12.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    repository = DefaultDictionaryRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Migration V12 & Open Source Vocabulary Tests', () {
    test('1. Migration v12 creates new tables and columns without breaking schema', () async {
      // Verify vocabularies columns
      final tableInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableVocabularies});');
      final columnNames = tableInfo.map((c) => c['name'] as String).toSet();

      expect(columnNames.contains('hanviet'), isTrue);
      expect(columnNames.contains('pinyin_clean'), isTrue);
      expect(columnNames.contains('pinyin_numeric'), isTrue);
      expect(columnNames.contains('source'), isTrue);
      expect(columnNames.contains('license'), isTrue);
      expect(columnNames.contains('verification_status'), isTrue);
      expect(columnNames.contains('is_polyphone'), isTrue);

      // Verify vocabulary_examples table
      final exTableInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableVocabularyExamples});');
      expect(exTableInfo, isNotEmpty);

      // Verify dictionary_entries table
      final dictTableInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableDictionaryEntries});');
      expect(dictTableInfo, isNotEmpty);
    });

    test('2. Insert and search word with Han-Viet and clean Pinyin', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'VOC_HSK1_爱_ai',
        'simplified': '爱',
        'traditional': '愛',
        'pinyin': 'ài',
        'pinyin_clean': 'ai',
        'hanviet': 'Ái',
        'hsk_level': 1,
        'stroke_count': 10,
        'source': 'clem109;drkameleon;CVDICT;no7z',
        'license': 'MIT;CC-BY-SA-4.0',
        'verification_status': 'verified',
        'is_polyphone': 0,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(DatabaseConstants.tableVocabularySenses, {
        'id': 'SNS_VOC_HSK1_爱_ai_1',
        'vocabulary_id': 'VOC_HSK1_爱_ai',
        'part_of_speech': 'v, vn, b',
        'meaning_vi': 'yêu; thích; tình cảm',
        'meaning_en': 'to love; affection; to be fond of; to like',
        'source': 'CVDICT;CC-CEDICT',
        'order_index': 1,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(DatabaseConstants.tableVocabularyExamples, {
        'id': 'EX_VOC_HSK1_爱_ai_1',
        'vocabulary_id': 'VOC_HSK1_爱_ai',
        'hsk_level': 1,
        'example_cn': '我们都爱我们的国家。',
        'example_pinyin': 'wǒ men dōu ài wǒ men de guó jiā',
        'example_vi': null,
        'example_en': 'We all love our country.',
        'source': 'no7z/hsk-sentences-audio (Apache-2.0/MIT)',
        'order_index': 1,
        'created_at': now,
        'updated_at': now,
      });

      // Search by Han-Viet
      final hvResults = await repository.search('Ái');
      expect(hvResults, isNotEmpty);
      expect(hvResults.first.simplified, equals('爱'));
      expect(hvResults.first.hanviet, equals('Ái'));
      expect(hvResults.first.examples, isNotEmpty);
      expect(hvResults.first.examples.first.exampleCn, equals('我们都爱我们的国家。'));

      // Search by clean Pinyin
      final pinyinResults = await repository.search('ai');
      expect(pinyinResults, isNotEmpty);
      expect(pinyinResults.first.simplified, equals('爱'));

      // Search by Vietnamese meaning
      final viResults = await repository.search('tình cảm');
      expect(viResults, isNotEmpty);
      expect(viResults.first.simplified, equals('爱'));
    });

    test('3. Open Source HSK fixture v2 exists and contains 5,000 verified words', () async {
      final fixtureFile = File('data_pipeline/processed/hsk_all_vocab.json');
      expect(await fixtureFile.exists(), isTrue, reason: 'hsk_all_vocab.json must exist');

      final content = await fixtureFile.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      expect(data['total_count'], equals(5000));
      expect(data['by_level']['1'], equals(150));
      expect(data['by_level']['2'], equals(150));
      expect(data['by_level']['3'], equals(299));
      expect(data['by_level']['4'], equals(601));
      expect(data['by_level']['5'], equals(1300));
      expect(data['by_level']['6'], equals(2500));

      final vocabs = data['vocabularies'] as List<dynamic>;
      expect(vocabs.length, equals(5000));

      // Check first item integrity
      final first = vocabs.first as Map<String, dynamic>;
      expect(first['simplified'], isNotEmpty);
      expect(first['pinyin'], isNotEmpty);
      expect(first['hanviet'], isNotEmpty);
      expect(first['senses'], isNotEmpty);
      expect(first['source'], isNotEmpty);
      expect(first['license'], isNotEmpty);
    });
  });
}
