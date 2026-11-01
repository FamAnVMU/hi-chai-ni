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
    tempDir = await Directory.systemTemp.createTemp('dict_test_');
    final dbPath = '${tempDir.path}/test_dict.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    repository = DefaultDictionaryRepository(db);

    // Seed test vocabulary with multiple senses and traditional characters
    final now = DateTime.utc(2026, 11, 1).toIso8601String();
    await db.insert(DatabaseConstants.tableVocabularies, {
      'id': 'VOCAB_001_NIHAO',
      'simplified': '你好',
      'traditional': '你好',
      'pinyin': 'nǐ hǎo',
      'hsk_level': 1,
      'stroke_count': 13,
      'radicals': '亻, 女',
      'frequency_rank': 1,
      'audio_uri': 'audio/hsk1/nihao.mp3',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(DatabaseConstants.tableVocabularySenses, {
      'id': 'SENSE_001_1',
      'vocabulary_id': 'VOCAB_001_NIHAO',
      'part_of_speech': 'Thán từ',
      'meaning_vi': 'Chào bạn, xin chào',
      'example_cn': '你好！很高兴认识你。',
      'example_pinyin': 'Nǐ hǎo! Hěn gāoxìng rènshi nǐ.',
      'example_vi': 'Xin chào! Rất vui được quen biết bạn.',
      'created_at': now,
      'updated_at': now,
    });

    // Word with multiple senses: 行 (háng: ngành nghề, hàng lối; xíng: được, đi lại)
    await db.insert(DatabaseConstants.tableVocabularies, {
      'id': 'VOCAB_002_XING',
      'simplified': '行',
      'traditional': '行',
      'pinyin': 'xíng',
      'hsk_level': 2,
      'stroke_count': 6,
      'radicals': '行',
      'frequency_rank': 45,
      'audio_uri': null,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(DatabaseConstants.tableVocabularySenses, {
      'id': 'SENSE_002_1',
      'vocabulary_id': 'VOCAB_002_XING',
      'part_of_speech': 'Động từ',
      'meaning_vi': 'Đi, di chuyển, thực hiện',
      'example_cn': '千里之行，始于足下。',
      'example_pinyin': 'Qiānlǐ zhī xíng, shǐ yú zú xià.',
      'example_vi': 'Chuyến đi ngàn dặm bắt đầu từ một bước chân.',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(DatabaseConstants.tableVocabularySenses, {
      'id': 'SENSE_002_2',
      'vocabulary_id': 'VOCAB_002_XING',
      'part_of_speech': 'Tính từ',
      'meaning_vi': 'Được, ổn thỏa',
      'example_cn': '这样行吗？',
      'example_pinyin': 'Zhèyàng xíng ma?',
      'example_vi': 'Như thế này có được không?',
      'created_at': now,
      'updated_at': now,
    });

    // Word with distinct traditional character: 学习 / 學習
    await db.insert(DatabaseConstants.tableVocabularies, {
      'id': 'VOCAB_003_XUEXI',
      'simplified': '学习',
      'traditional': '學習',
      'pinyin': 'xuéxí',
      'hsk_level': 1,
      'stroke_count': 11,
      'radicals': '子',
      'frequency_rank': 20,
      'audio_uri': 'audio/hsk1/xuexi.mp3',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(DatabaseConstants.tableVocabularySenses, {
      'id': 'SENSE_003_1',
      'vocabulary_id': 'VOCAB_003_XUEXI',
      'part_of_speech': 'Động từ',
      'meaning_vi': 'Học tập, nghiên cứu',
      'example_cn': '我喜欢学习汉语。',
      'example_pinyin': 'Wǒ xǐhuan xuéxí Hànyǔ.',
      'example_vi': 'Tôi thích học tiếng Hán.',
      'created_at': now,
      'updated_at': now,
    });
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Dictionary Search Engine Tests', () {
    test('1. Search exact & prefix Hanzi (simplified & traditional)', () async {
      // Exact simplified
      final exact = await repository.search('你好');
      expect(exact, isNotEmpty);
      expect(exact.first.simplified, equals('你好'));
      expect(exact.first.senses, hasLength(1));

      // Prefix simplified
      final prefix = await repository.search('学');
      expect(prefix, isNotEmpty);
      expect(prefix.any((e) => e.simplified == '学习'), isTrue);

      // Traditional search
      final trad = await repository.search('學習');
      expect(trad, isNotEmpty);
      expect(trad.first.simplified, equals('学习'));
      expect(trad.first.traditional, equals('學習'));
    });

    test('2. Search Pinyin: accented, tone numbered, and tone-free', () async {
      // Accented Pinyin
      final accented = await repository.search('nǐ hǎo');
      expect(accented, isNotEmpty);
      expect(accented.first.simplified, equals('你好'));

      // Tone numbered Pinyin
      final numbered = await repository.search('ni3 hao3');
      expect(numbered, isNotEmpty);
      expect(numbered.first.simplified, equals('你好'));

      // Tone-free lowercase Pinyin
      final toneFree = await repository.search('nihao');
      expect(toneFree, isNotEmpty);
      expect(toneFree.first.simplified, equals('你好'));

      // Prefix pinyin
      final pinyinPrefix = await repository.search('xue');
      expect(pinyinPrefix, isNotEmpty);
      expect(pinyinPrefix.first.simplified, equals('学习'));
    });

    test('3. Search by Vietnamese meaning in senses', () async {
      final results = await repository.search('chào bạn');
      expect(results, isNotEmpty);
      expect(results.first.simplified, equals('你好'));
      expect(results.first.senses.first.meaningVi, contains('Chào bạn'));

      final studyResults = await repository.search('nghiên cứu');
      expect(studyResults, isNotEmpty);
      expect(studyResults.first.simplified, equals('学习'));
    });

    test('4. Entry with multiple senses returns all definitions', () async {
      final results = await repository.search('行');
      expect(results, isNotEmpty);
      final entry = results.first;
      expect(entry.senses, hasLength(2));
      expect(entry.senses[0].partOfSpeech, equals('Động từ'));
      expect(entry.senses[0].meaningVi, contains('Đi, di chuyển'));
      expect(entry.senses[1].partOfSpeech, equals('Tính từ'));
      expect(entry.senses[1].meaningVi, contains('Được, ổn thỏa'));
    });

    test('5. Non-existent word and long text search does not crash', () async {
      final empty = await repository.search('abcdefg_not_exist_word');
      expect(empty, isEmpty);

      final veryLongText = 'Đây là một câu tìm kiếm rất dài không có trong cơ sở dữ liệu tiếng Trung ' * 5;
      final longResults = await repository.search(veryLongText);
      expect(longResults, isEmpty);
    });

    test('6. User saved words and custom notes operations', () async {
      final entry = (await repository.search('你好')).first;
      expect(entry.isSaved, isFalse);

      // Toggle save
      final savedState = await repository.toggleSaveWord(entry, customNote: 'Từ vựng bài 1');
      expect(savedState, isTrue);

      final savedList = await repository.getSavedWords();
      expect(savedList, hasLength(1));
      expect(savedList.first.vocabularyId, equals(entry.id));
      expect(savedList.first.customNote, equals('Từ vựng bài 1'));

      // Update custom note
      await repository.updateWordNote(entry.id, 'Ghi chú đã cập nhật');
      final updatedList = await repository.getSavedWords();
      expect(updatedList.first.customNote, equals('Ghi chú đã cập nhật'));

      // Toggle unsave
      final unsavedState = await repository.toggleSaveWord(entry);
      expect(unsavedState, isFalse);
      expect(await repository.getSavedWords(), isEmpty);
    });

    test('7. Search history recording and clearing', () async {
      await repository.search('你好');
      await repository.search('学习');

      final history = await repository.getRecentSearches();
      expect(history, isNotEmpty);
      expect(history.first.query, equals('学习'));

      await repository.clearSearchHistory();
      final clearedHistory = await repository.getRecentSearches();
      expect(clearedHistory, isEmpty);
    });
  });
}
