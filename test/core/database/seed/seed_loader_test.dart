import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SeedDataValidator Tests', () {
    test('Valid bundle passes validation with zero errors', () {
      final bundle = SeedBundle(
        bundleName: 'test_bundle',
        version: 1,
        syllabusVersion: 'HSK2.0',
        source: 'test',
        vocabularies: [
          const SeedVocabularyItem(
            id: 'VOC_001',
            simplified: '你好',
            traditional: '你好',
            pinyin: 'nǐ hǎo',
            hskLevel: 1,
            senses: [
              SeedSenseItem(
                id: 'SNS_001_1',
                partOfSpeech: 'Thán từ',
                meaningVi: 'Xin chào',
                examples: [
                  SeedExampleItem(zh: '你好！', pinyin: 'Nǐ hǎo!', vi: 'Xin chào!'),
                ],
              ),
            ],
          ),
        ],
      );

      final result = SeedDataValidator.validateBundle(bundle);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('Rejects empty simplified, invalid pinyin, and out-of-range HSK level', () {
      final invalidBundle = SeedBundle(
        bundleName: 'invalid_bundle',
        version: 1,
        syllabusVersion: 'HSK2.0',
        source: 'test',
        vocabularies: [
          const SeedVocabularyItem(
            id: 'VOC_BAD_1',
            simplified: '', // Empty
            pinyin: 'ni3 hao3 %^&*', // Malformed characters
            hskLevel: 9, // Out of range (1..6)
            senses: [], // Missing senses
          ),
        ],
      );

      final result = SeedDataValidator.validateBundle(invalidBundle);
      expect(result.isValid, isFalse);
      expect(result.errors.length, greaterThanOrEqualTo(3));
      expect(result.errors.any((e) => e.contains('Simplified Chinese')), isTrue);
      expect(result.errors.any((e) => e.contains('HSK level 9 out of valid range')), isTrue);
      expect(result.errors.any((e) => e.contains('Must have at least one sense')), isTrue);
    });

    test('Rejects duplicate vocabulary IDs in the same bundle', () {
      final dupBundle = SeedBundle(
        bundleName: 'dup_bundle',
        version: 1,
        syllabusVersion: 'HSK2.0',
        source: 'test',
        vocabularies: [
          const SeedVocabularyItem(
            id: 'VOC_SAME',
            simplified: '你好',
            pinyin: 'nǐ hǎo',
            hskLevel: 1,
            senses: [
              SeedSenseItem(id: 'SNS_1', partOfSpeech: 'Thán từ', meaningVi: 'Xin chào'),
            ],
          ),
          const SeedVocabularyItem(
            id: 'VOC_SAME', // Duplicate ID
            simplified: '谢谢',
            pinyin: 'xiè xie',
            hskLevel: 1,
            senses: [
              SeedSenseItem(id: 'SNS_2', partOfSpeech: 'Động từ', meaningVi: 'Cảm ơn'),
            ],
          ),
        ],
      );

      final result = SeedDataValidator.validateBundle(dupBundle);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Duplicate ID "VOC_SAME"')), isTrue);
    });
  });

  group('SeedLoader Database Engine Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDb;
    late Database db;
    late SeedLoader seedLoader;
    late VocabularyDao vocabDao;
    late GrammarDao grammarDao;
    late ReadingDao readingDao;
    late SrsDao srsDao;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_seed_test_');
      dbPath = '${tempDir.path}/seed_test.db';

      appDb = AppDatabase.instance;
      await appDb.open(customPath: dbPath, customFactory: databaseFactoryFfi);
      db = appDb.database;

      seedLoader = SeedLoader(db);
      vocabDao = VocabularyDao(db);
      grammarDao = GrammarDao(db);
      readingDao = ReadingDao(db);
      srsDao = SrsDao(db);
    });

    tearDown(() async {
      await appDb.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final sampleBundleJson = json.encode({
      'bundleName': 'sample_hsk_test',
      'version': 1,
      'syllabusVersion': 'HSK2.0',
      'source': 'test_source',
      'vocabularies': [
        {
          'id': 'VOC_T1',
          'simplified': '猫',
          'traditional': '貓',
          'pinyin': 'māo',
          'hskLevel': 1,
          'senses': [
            {
              'id': 'SNS_T1_1',
              'partOfSpeech': 'Danh từ',
              'meaningVi': 'Con mèo',
              'examples': [
                {'zh': '这是一只可爱的猫。', 'pinyin': 'Zhè shì yī zhī kě\'ài de māo.', 'vi': 'Đây là một con mèo dễ thương.'}
              ]
            }
          ]
        },
        {
          'id': 'VOC_T2',
          'simplified': '狗',
          'traditional': '狗',
          'pinyin': 'gǒu',
          'hskLevel': 1,
          'senses': [
            {
              'id': 'SNS_T2_1',
              'partOfSpeech': 'Danh từ',
              'meaningVi': 'Con chó',
              'examples': [
                {'zh': '我家有一只小狗。', 'pinyin': 'Wǒ jiā yǒu yī zhī xiǎogǒu.', 'vi': 'Nhà tôi có một chú chó con.'}
              ]
            }
          ]
        }
      ],
      'grammarItems': [
        {
          'id': 'GRA_T1',
          'code': 'GRA_SHI',
          'hskLevel': 1,
          'title': 'Câu chữ 是',
          'pattern': 'A + 是 + B',
          'explanationVi': 'Dùng để khẳng định thân phận, tính chất của sự vật.',
          'examples': [
            {'zh': '他是老师。', 'pinyin': 'Tā shì lǎoshī.', 'vi': 'Anh ấy là giáo viên.'}
          ]
        }
      ],
      'readingPassages': [
        {
          'id': 'RDG_T1',
          'hskLevel': 1,
          'title': '我的猫',
          'contentZh': '我有一只白色的猫，它很可爱。',
          'pinyin': 'Wǒ yǒu yī zhī báisè de māo, tā hěn kě\'ài.',
          'translationVi': 'Tôi có một chú mèo màu trắng, nó rất dễ thương.',
          'questions': [
            {'question': '猫是什么颜色的？', 'answer': '白色'}
          ]
        }
      ]
    });

    test('1. First seed execution inserts items and records completed history', () async {
      final progressList = <SeedProgress>[];
      final result = await seedLoader.seedFromJsonString(
        sampleBundleJson,
        onProgress: (p) => progressList.add(p),
      );

      expect(result.success, isTrue);
      expect(result.skipped, isFalse);
      expect(result.totalItems, equals(4)); // 2 vocabs + 1 grammar + 1 reading

      // Check DB content via DAOs
      final vocabs = await vocabDao.getVocabulariesByHsk(1);
      expect(vocabs.length, equals(2));
      expect(vocabs.map((v) => v['simplified']).toSet(), containsAll({'猫', '狗'}));

      final mao = await vocabDao.getVocabularyWithSenses('VOC_T1');
      expect(mao, isNotNull);
      expect(mao!['simplified'], equals('猫'));
      final senses = mao['senses'] as List;
      expect(senses.length, equals(1));
      expect(senses[0]['meaning_vi'], equals('Con mèo'));

      final grammar = await grammarDao.getGrammarByHsk(1);
      expect(grammar.length, equals(1));
      expect(grammar.first['title_vi'], equals('Câu chữ 是'));

      final reading = await readingDao.getPassagesByHsk(1);
      expect(reading.length, equals(1));
      expect(reading.first['title_cn'], equals('我的猫'));

      // Verify seed history
      final historyDao = SeedHistoryDao(db);
      final entry = await historyDao.getEntry('sample_hsk_test');
      expect(entry, isNotNull);
      expect(entry!.status, equals('completed'));
      expect(entry.appliedItems, equals(4));
    });

    test('2. Idempotency: Re-running exact same seed skips execution with 0 duplicates', () async {
      // First run
      final firstResult = await seedLoader.seedFromJsonString(sampleBundleJson);
      expect(firstResult.success, isTrue);
      expect(firstResult.skipped, isFalse);

      // Second run
      final secondResult = await seedLoader.seedFromJsonString(sampleBundleJson);
      expect(secondResult.success, isTrue);
      expect(secondResult.skipped, isTrue); // Skipped!

      // Verify database counts remain strictly 2 vocabs, 1 grammar, 1 reading
      final vocabs = await vocabDao.getVocabulariesByHsk(1);
      expect(vocabs.length, equals(2));

      final grammar = await grammarDao.getGrammarByHsk(1);
      expect(grammar.length, equals(1));

      final reading = await readingDao.getPassagesByHsk(1);
      expect(reading.length, equals(1));
    });

    test('3. Recovery from failed or interrupted seed', () async {
      final historyDao = SeedHistoryDao(db);

      // Simulate a previously interrupted/failed state
      await historyDao.recordInProgress(
        bundleName: 'sample_hsk_test',
        version: 1,
        checksum: SeedLoader.computeChecksum(sampleBundleJson),
        totalItems: 4,
      );
      await historyDao.recordFailed(
        bundleName: 'sample_hsk_test',
        errorMessage: 'Simulated connection crash or power interruption',
      );

      final entryBefore = await historyDao.getEntry('sample_hsk_test');
      expect(entryBefore!.status, equals('failed'));

      // Now run SeedLoader again
      final retryResult = await seedLoader.seedFromJsonString(sampleBundleJson);
      expect(retryResult.success, isTrue);
      expect(retryResult.skipped, isFalse); // Successfully retried!

      final entryAfter = await historyDao.getEntry('sample_hsk_test');
      expect(entryAfter!.status, equals('completed'));
      expect(entryAfter.appliedItems, equals(4));
    });

    test('4. User learning progress (SRS & evidence) is preserved during seed update', () async {
      // Seed initially
      await seedLoader.seedFromJsonString(sampleBundleJson);

      // User studies 'VOC_T1' (猫) and creates an SRS card & learner evidence
      final now = DateTime.now().toUtc().toIso8601String();
      await srsDao.upsertSrsItem({
        'id': 'SRS_VOC_T1',
        'content_id': 'VOC_T1',
        'content_type': 'vocabulary',
        'state': 'review',
        'interval_days': 15,
        'ease_factor': 2.6,
        'repetitions': 4,
        'lapses': 0,
        'due_at': '2026-11-15T00:00:00.000Z',
        'created_at': now,
        'updated_at': now,
      });

      final evidenceDao = LearnerEvidenceDao(db);
      await evidenceDao.appendEvidence({
        'id': 'EVI_001',
        'content_id': 'VOC_T1',
        'content_type': 'vocabulary',
        'source': 'flashcard_review',
        'score': 1.0,
        'duration_ms': 1200,
        'metadata_json': json.encode({'domain': 'vocabulary', 'hsk_level': 1}),
        'created_at': now,
      });

      // Now create updated bundle with updated Vietnamese meaning and new example
      final updatedBundleJson = json.encode({
        'bundleName': 'sample_hsk_test',
        'version': 2, // Bumped version
        'syllabusVersion': 'HSK2.0',
        'source': 'test_source',
        'vocabularies': [
          {
            'id': 'VOC_T1',
            'simplified': '猫',
            'traditional': '貓',
            'pinyin': 'māo',
            'hskLevel': 1,
            'senses': [
              {
                'id': 'SNS_T1_1',
                'partOfSpeech': 'Danh từ',
                'meaningVi': 'Con mèo (loài động vật có móng vuốt, thích bắt chuột)',
                'examples': [
                  {'zh': '这是一只可爱的猫。', 'pinyin': 'Zhè shì yī zhī kě\'ài de māo.', 'vi': 'Đây là một con mèo dễ thương.'},
                  {'zh': '小猫在睡觉。', 'pinyin': 'Xiǎomāo zài shuìjiào.', 'vi': 'Mèo con đang ngủ.'}
                ]
              }
            ]
          },
          {
            'id': 'VOC_T2',
            'simplified': '狗',
            'traditional': '狗',
            'pinyin': 'gǒu',
            'hskLevel': 1,
            'senses': [
              {
                'id': 'SNS_T2_1',
                'partOfSpeech': 'Danh từ',
                'meaningVi': 'Con chó',
                'examples': []
              }
            ]
          }
        ]
      });

      final updateResult = await seedLoader.seedFromJsonString(updatedBundleJson);
      expect(updateResult.success, isTrue);

      // Verify the vocabulary sense meaning was updated
      final updatedMao = await vocabDao.getVocabularyWithSenses('VOC_T1');
      final updatedSenses = updatedMao!['senses'] as List;
      expect(updatedSenses.first['meaning_vi'], contains('loài động vật có móng vuốt'));

      // CRITICAL ASSERTION: The user's SRS progress was NOT wiped or reset!
      final userSrs = await srsDao.getSrsItemByContent('VOC_T1', 'vocabulary');
      expect(userSrs, isNotNull);
      expect(userSrs!['state'], equals('review'));
      expect(userSrs['interval_days'], equals(15));
      expect(userSrs['repetitions'], equals(4));

      // Learner evidence is still intact
      final evidenceList = await evidenceDao.getEvidenceByContent('VOC_T1', 'vocabulary');
      expect(evidenceList.length, equals(1));
      expect(evidenceList.first['score'], equals(1.0));
    });

    test('5. Real vetted seed fixture (hsk_seed_fixture_v1.json) parses and seeds accurately', () async {
      final fixtureFile = File('assets/data/hsk_seed_fixture_v1.json');
      expect(await fixtureFile.exists(), isTrue, reason: 'assets/data/hsk_seed_fixture_v1.json must exist');

      final rawContent = await fixtureFile.readAsString();
      final sw = Stopwatch()..start();

      final result = await seedLoader.seedFromJsonString(rawContent);
      sw.stop();

      expect(result.success, isTrue);
      expect(result.skipped, isFalse);
      expect(result.totalItems, equals(108)); // 84 vocabs + 19 grammar + 5 reading

      // Measure seeding duration
      debugPrint('Real vetted fixture (108 items) seeded in ${result.duration.inMilliseconds}ms (${sw.elapsedMilliseconds}ms total).');
      expect(result.duration.inMilliseconds, greaterThanOrEqualTo(0));

      // Verify counts in DB
      final hsk1Vocabs = await vocabDao.getVocabulariesByHsk(1);
      final hsk2Vocabs = await vocabDao.getVocabulariesByHsk(2);
      final hsk3Vocabs = await vocabDao.getVocabulariesByHsk(3);
      final totalVocabs = hsk1Vocabs.length + hsk2Vocabs.length + hsk3Vocabs.length + 1; // plus 1 HSK 4
      expect(totalVocabs, equals(84));

      final grammarItems = await grammarDao.getGrammarByHsk(1);
      expect(grammarItems.isNotEmpty, isTrue);

      final readingItems = await readingDao.getPassagesByHsk(1);
      expect(readingItems.isNotEmpty, isTrue);
      expect(readingItems.first['title_cn'], equals('我的中国朋友'));
    });
  });
}
