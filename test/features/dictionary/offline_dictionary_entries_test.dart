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
    tempDir = await Directory.systemTemp.createTemp('dict_offline_test_');
    final dbPath = '${tempDir.path}/test_offline_dict.db';
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

  group('Offline Comprehensive Dictionary (119k entries) Tests', () {
    test('1. Verified dataset file exists and adheres to CVDICT & CC-CEDICT schema', () async {
      final assetFile = File('assets/data/offline_dictionary_entries.json');
      expect(await assetFile.exists(), isTrue, reason: 'assets/data/offline_dictionary_entries.json must exist');

      final content = await assetFile.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      expect(data['total_entries'], equals(119044));
      expect(data['license'], contains('CVDICT'));
      expect(data['entries'], isNotEmpty);

      final entries = data['entries'] as List<dynamic>;
      expect(entries.length, equals(119044));

      // Check first item integrity
      final first = entries.first as Map<String, dynamic>;
      expect(first['simplified'], isNotEmpty);
      expect(first['pinyin'], isNotEmpty);
      expect(first['pinyin_clean'], isNotEmpty);
      expect(first['meaning_vi'], isNotEmpty);
      expect(first['source'], isNotEmpty);
    });

    test('2. ensureDictionarySeedLoaded seeds entries into dictionary_entries and enables search', () async {
      // Seed with fixture subset for ultra-fast unit test execution
      const testJson = '''
      {
        "total_entries": 3,
        "license": "CVDICT (CC BY-SA 4.0)",
        "entries": [
          {
            "simplified": "猫儿",
            "traditional": "貓兒",
            "pinyin": "mao1 er2",
            "pinyin_clean": "maoer",
            "meaning_vi": "mèo con",
            "source": "CVDICT (CC BY-SA 4.0)"
          },
          {
            "simplified": "X光",
            "traditional": "X光",
            "pinyin": "X guang1",
            "pinyin_clean": "xguang",
            "meaning_vi": "tia X",
            "source": "CVDICT (CC BY-SA 4.0)"
          },
          {
            "simplified": "V沟",
            "traditional": "V溝",
            "pinyin": "V gou1",
            "pinyin_clean": "vgou",
            "meaning_vi": "đường viền cổ áo thấp",
            "source": "CVDICT (CC BY-SA 4.0)"
          }
        ]
      }
      ''';

      final seededCount = await repository.ensureDictionarySeedLoaded(
        jsonString: testJson,
      );
      expect(seededCount, equals(3));

      // 1. Search by Hanzi
      final searchHanzi = await repository.search('猫儿');
      expect(searchHanzi, isNotEmpty);
      expect(searchHanzi.first.simplified, equals('猫儿'));
      expect(searchHanzi.first.pinyin, equals('mao1 er2'));
      expect(searchHanzi.first.senses.first.meaningVi, equals('mèo con'));

      // 2. Search by clean Pinyin
      final searchPinyin = await repository.search('xguang');
      expect(searchPinyin, isNotEmpty);
      expect(searchPinyin.first.simplified, equals('X光'));
      expect(searchPinyin.first.senses.first.meaningVi, equals('tia X'));

      // 3. Search by Vietnamese meaning
      final searchVi = await repository.search('đường viền');
      expect(searchVi, isNotEmpty);
      expect(searchVi.first.simplified, equals('V沟'));
    });

    test('3. getWordById and getWordByExactHanzi resolve non-HSK offline dictionary entries', () async {
      const testJson = '''
      {
        "total_entries": 1,
        "license": "CVDICT (CC BY-SA 4.0)",
        "entries": [
          {
            "simplified": "猫儿",
            "traditional": "貓兒",
            "pinyin": "mao1 er2",
            "pinyin_clean": "maoer",
            "meaning_vi": "mèo con",
            "source": "CVDICT (CC BY-SA 4.0)"
          }
        ]
      }
      ''';

      await repository.ensureDictionarySeedLoaded(jsonString: testJson);

      final byHanzi = await repository.getWordByExactHanzi('猫儿');
      expect(byHanzi, isNotNull);
      expect(byHanzi!.simplified, equals('猫儿'));
      expect(byHanzi.pinyin, equals('mao1 er2'));

      final byId = await repository.getWordById(byHanzi.id);
      expect(byId, isNotNull);
      expect(byId!.simplified, equals('猫儿'));
    });

    test('4. toggleSaveWord on offline dictionary entry passes without FK error and persists', () async {
      const testJson = '''
      {
        "total_entries": 1,
        "license": "CVDICT (CC BY-SA 4.0)",
        "entries": [
          {
            "simplified": "猫儿",
            "traditional": "貓兒",
            "pinyin": "mao1 er2",
            "pinyin_clean": "maoer",
            "meaning_vi": "mèo con",
            "source": "CVDICT (CC BY-SA 4.0)"
          }
        ]
      }
      ''';

      await repository.ensureDictionarySeedLoaded(jsonString: testJson);
      final entry = await repository.getWordByExactHanzi('猫儿');
      expect(entry, isNotNull);

      // Bookmark / save word
      final saved = await repository.toggleSaveWord(entry!, customNote: 'Từ yêu thích');
      expect(saved, isTrue);

      final savedList = await repository.getSavedWords();
      expect(savedList, isNotEmpty);
      expect(savedList.first.simplified, equals('猫儿'));
      expect(savedList.first.customNote, equals('Từ yêu thích'));

      // Check entry has isSaved = true
      final entryAfterSave = await repository.getWordById(entry.id);
      expect(entryAfterSave, isNotNull);
      expect(entryAfterSave!.isSaved, isTrue);

      // Unsave word
      final unsaved = await repository.toggleSaveWord(entryAfterSave);
      expect(unsaved, isFalse);

      final emptyList = await repository.getSavedWords();
      expect(emptyList, isEmpty);
    });

    test('5. Full dataset seeding and idempotency verification', () async {
      // Seed full 119k entries from file
      final stopwatch = Stopwatch()..start();
      final totalSeeded = await repository.ensureDictionarySeedLoaded(
        filePath: 'assets/data/offline_dictionary_entries.json',
      );
      stopwatch.stop();

      expect(totalSeeded, equals(119044));
      expect(stopwatch.elapsedMilliseconds, lessThan(30000)); // Should take <30s

      // Verify idempotency: second call should skip immediately
      final idempotentSw = Stopwatch()..start();
      final secondCallCount = await repository.ensureDictionarySeedLoaded(
        filePath: 'assets/data/offline_dictionary_entries.json',
      );
      idempotentSw.stop();

      expect(secondCallCount, equals(119044));
      expect(idempotentSw.elapsedMilliseconds, lessThan(500)); // Should skip in <500ms

      // Search real non-HSK words from the 119k dictionary
      final searchResult = await repository.search('猫儿');
      expect(searchResult, isNotEmpty);
      expect(searchResult.any((e) => e.simplified == '猫儿'), isTrue);

      final searchBiang = await repository.search('biangbiangmian');
      expect(searchBiang, isNotEmpty);
      expect(searchBiang.first.simplified, equals('𰻝𰻝面'));
    });
  });
}
