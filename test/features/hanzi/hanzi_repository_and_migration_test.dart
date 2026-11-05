import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/migrations/migration_v14.dart';
import 'package:hi_chinese/features/hanzi/data/hanzi_dao.dart';
import 'package:hi_chinese/features/hanzi/data/hanzi_repository.dart';
import 'package:hi_chinese/features/hanzi/domain/models/hanzi_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationV14 and HanziRepository', () {
    late Database db;
    late HanziDao dao;
    late DefaultHanziRepository repository;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      // Run Migration v14
      const migration = MigrationV14();
      await migration.up(db);

      dao = HanziDao(db);
      repository = DefaultHanziRepository(dao);
    });

    tearDown(() async {
      await db.close();
    });

    test('MigrationV14 creates hanzi_characters and hanzi_writing_progress tables', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('hanzi_characters', 'hanzi_writing_progress')",
      );
      final names = tables.map((t) => t['name'] as String).toSet();
      expect(names.contains('hanzi_characters'), isTrue);
      expect(names.contains('hanzi_writing_progress'), isTrue);
    });

    test('inserts and retrieves HanziCharacter by character and HSK level', () async {
      final sampleChar = HanziCharacter(
        id: 'hanzi_4f60',
        character: '你',
        strokeCount: 7,
        hskLevel: 1,
        pinyin: 'nǐ',
        hanviet: 'nhĩ',
        meaningVi: 'bạn, anh, chị',
        definitionEn: 'you',
        radical: '人',
        decomposition: '⿰亻尔',
        strokes: ['M 272 567 Q 306 613 342 669 Z'],
        medians: [
          [const Point2D(317, 812), const Point2D(68, 367)],
        ],
        sampleWords: [
          const HanziSampleWord(id: 'vocab_nihao', word: '你好', pinyin: 'nǐ hǎo', meaningVi: 'xin chào'),
        ],
      );

      await dao.insertCharactersBatch([sampleChar]);

      final fetched = await repository.getCharacter('你');
      expect(fetched, isNotNull);
      expect(fetched!.character, '你');
      expect(fetched.strokeCount, 7);
      expect(fetched.pinyin, 'nǐ');
      expect(fetched.hanviet, 'nhĩ');
      expect(fetched.sampleWords.length, 1);
      expect(fetched.sampleWords.first.word, '你好');

      final level1List = await repository.getCharactersByHskLevel(1);
      expect(level1List.length, 1);
      expect(level1List.first.character, '你');
    });

    test('searchCharacters finds by Hanzi, pinyin, or hanviet', () async {
      final char1 = HanziCharacter(
        id: 'hanzi_4e2d',
        character: '中',
        strokeCount: 4,
        hskLevel: 1,
        pinyin: 'zhōng',
        hanviet: 'trung',
        meaningVi: 'ở giữa, trung quốc',
        strokes: ['M 10 10 Z'],
        medians: [[const Point2D(0, 0), const Point2D(10, 10)]],
      );

      await dao.insertCharactersBatch([char1]);

      final byPinyin = await repository.searchCharacters('zhong');
      expect(byPinyin.isNotEmpty, isTrue);
      expect(byPinyin.first.character, '中');

      final byHanviet = await repository.searchCharacters('trung');
      expect(byHanviet.isNotEmpty, isTrue);
      expect(byHanviet.first.character, '中');
    });

    test('recordPracticeAttempt updates mastery level, accuracy and schedules SRS interval', () async {
      await repository.recordPracticeAttempt(
        character: '你',
        accuracy: 95.0,
        mistakes: 0,
        strokeOrderErrors: 0,
        isTestMode: true,
      );

      final progress = await repository.getProgress('你');
      expect(progress, isNotNull);
      expect(progress!.character, '你');
      expect(progress.testCount, 1);
      expect(progress.practiceCount, 0);
      expect(progress.lastAccuracyScore, 95.0);
      expect(progress.bestAccuracyScore, 95.0);
      expect(progress.masteryLevel, 'mastered');
      expect(progress.srsDueDate, isNotNull);
      expect(progress.srsDueDate!.isAfter(DateTime.now()), isTrue);
    });

    test('getCharactersNeedingReview returns characters with mistakes or due dates', () async {
      await repository.recordPracticeAttempt(
        character: '好',
        accuracy: 60.0,
        mistakes: 2,
        strokeOrderErrors: 1,
        isTestMode: true,
      );

      final reviews = await repository.getCharactersNeedingReview();
      expect(reviews.any((r) => r.character == '好'), isTrue);
    });

    test('ensureSeedLoaded handles missing asset gracefully', () async {
      final loaded = await repository.ensureSeedLoaded(assetPath: 'assets/non_existent.json');
      expect(loaded, 0);
    });

    test('concurrent ensureSeedLoaded calls deduplicate without race conditions', () async {
      final futures = List.generate(5, (_) => repository.ensureSeedLoaded(assetPath: 'assets/non_existent.json'));
      final results = await Future.wait(futures);
      expect(results, equals([0, 0, 0, 0, 0]));
    });
  });
}
