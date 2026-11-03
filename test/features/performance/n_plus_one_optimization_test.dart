import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/hanzi/data/hanzi_dao.dart';
import 'package:hi_chinese/features/hanzi/data/hanzi_repository.dart';
import 'package:hi_chinese/features/hanzi/domain/models/hanzi_models.dart';
import 'package:hi_chinese/features/sentences/data/sentence_dao.dart';
import 'package:hi_chinese/features/sentences/data/sentence_repository.dart';
import 'package:hi_chinese/features/sentences/domain/models/sentence_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CountingDatabaseExecutor implements DatabaseExecutor {
  final Database _realDb;
  int queryCount = 0;

  CountingDatabaseExecutor(this._realDb);

  void reset() => queryCount = 0;

  @override
  Database get database => _realDb;

  @override
  Batch batch() => _realDb.batch();

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    return _realDb.execute(sql, arguments);
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) {
    return _realDb.insert(table, values, nullColumnHack: nullColumnHack, conflictAlgorithm: conflictAlgorithm);
  }

  @override
  Future<List<Map<String, Object?>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) {
    queryCount++;
    return _realDb.query(table, distinct: distinct, columns: columns, where: where, whereArgs: whereArgs, groupBy: groupBy, having: having, orderBy: orderBy, limit: limit, offset: offset);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) {
    queryCount++;
    return _realDb.rawQuery(sql, arguments);
  }

  @override
  Future<QueryCursor> queryCursor(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset, int? bufferSize}) {
    queryCount++;
    return _realDb.queryCursor(table, distinct: distinct, columns: columns, where: where, whereArgs: whereArgs, groupBy: groupBy, having: having, orderBy: orderBy, limit: limit, offset: offset, bufferSize: bufferSize);
  }

  @override
  Future<QueryCursor> rawQueryCursor(String sql, List<Object?>? arguments, {int? bufferSize}) {
    queryCount++;
    return _realDb.rawQueryCursor(sql, arguments, bufferSize: bufferSize);
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    return _realDb.rawInsert(sql, arguments);
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    return _realDb.rawUpdate(sql, arguments);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    return _realDb.rawDelete(sql, arguments);
  }

  @override
  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) {
    return _realDb.update(table, values, where: where, whereArgs: whereArgs, conflictAlgorithm: conflictAlgorithm);
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    return _realDb.delete(table, where: where, whereArgs: whereArgs);
  }
}

void main() {
  late Database db;
  late Directory tempDir;
  late CountingDatabaseExecutor countingDb;
  late HanziDao hanziDao;
  late DefaultHanziRepository hanziRepo;
  late SentenceDao sentenceDao;
  late DefaultSentenceRepository sentenceRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hi_chinese_n_plus_one_test_');
    final dbPath = '${tempDir.path}/perf_test.db';

    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseConstants.currentDatabaseVersion,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON;');
          final engine = MigrationEngine();
          await engine.executeMigrations(db, 0, version);
        },
      ),
    );

    countingDb = CountingDatabaseExecutor(db);
    hanziDao = HanziDao(countingDb);
    hanziRepo = DefaultHanziRepository(hanziDao);
    sentenceDao = SentenceDao(countingDb);
    sentenceRepo = DefaultSentenceRepository(sentenceDao);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Hanzi Module N+1 Optimization Benchmarks', () {
    test('1. Empty input produces 0 database queries', () async {
      countingDb.reset();
      final map = await hanziRepo.getProgressForCharacters([]);
      expect(map, isEmpty);
      expect(countingDb.queryCount, 0);
    });

    test('2. Single character query produces exactly 1 database query', () async {
      await db.insert(DatabaseConstants.tableHanziWritingProgress, {
        'id': 'prog_你',
        'character': '你',
        'hsk_level': 1,
        'practice_count': 3,
        'best_accuracy_score': 95.0,
      });

      countingDb.reset();
      final map = await hanziRepo.getProgressForCharacters(['你']);
      expect(countingDb.queryCount, 1);
      expect(map.containsKey('你'), isTrue);
      expect(map['你']!.bestAccuracyScore, 95.0);
    });

    test('3. 100 characters with partial progress execute in 1 query instead of 100 queries', () async {
      final chars = List.generate(100, (i) => '字_$i');
      for (int i = 0; i < 50; i++) {
        await db.insert(DatabaseConstants.tableHanziWritingProgress, {
          'id': 'prog_字_$i',
          'character': '字_$i',
          'hsk_level': 1,
          'practice_count': 1,
          'best_accuracy_score': 80.0 + i,
        });
      }

      countingDb.reset();
      final map = await hanziRepo.getProgressForCharacters(chars);

      expect(countingDb.queryCount, 1);
      expect(map.length, 50);
      expect(map['字_0']!.bestAccuracyScore, 80.0);
      expect(map.containsKey('字_75'), isFalse);
    });

    test('4. 300 characters execute in 1 batch query instead of 300 sequential queries', () async {
      final chars = List.generate(300, (i) => '汉_$i');
      for (int i = 0; i < 300; i += 3) {
        await db.insert(DatabaseConstants.tableHanziWritingProgress, {
          'id': 'prog_汉_$i',
          'character': '汉_$i',
          'hsk_level': 1,
          'practice_count': 2,
          'best_accuracy_score': 85.0,
        });
      }

      countingDb.reset();
      final stopwatch = Stopwatch()..start();
      final map = await hanziRepo.getProgressForCharacters(chars);
      stopwatch.stop();

      expect(countingDb.queryCount, 1);
      expect(map.length, 100);
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('5. Duplicate IDs and nonexistent IDs are sanitized cleanly', () async {
      await db.insert(DatabaseConstants.tableHanziWritingProgress, {
        'id': 'prog_好',
        'character': '好',
        'hsk_level': 1,
        'practice_count': 5,
        'best_accuracy_score': 92.0,
      });

      final duplicates = ['好', '好', '好', 'khong_ton_tai_1', 'khong_ton_tai_2', ''];
      countingDb.reset();
      final map = await hanziRepo.getProgressForCharacters(duplicates);

      expect(countingDb.queryCount, 1);
      expect(map.length, 1);
      expect(map['好']!.bestAccuracyScore, 92.0);
    });

    test('6. Review filter uses bulk getCharactersByGlyphs instead of loop query', () async {
      for (int i = 0; i < 20; i++) {
        final char = HanziCharacter(
          id: 'char_$i',
          character: '字_$i',
          strokeCount: 5,
          hskLevel: 1,
          pinyin: 'zi',
          strokes: const ['M 0 0'],
          medians: const [[Point2D(0, 0)]],
        );
        await db.insert(DatabaseConstants.tableHanziCharacters, char.toMap());
      }

      final glyphs = List.generate(20, (i) => '字_$i');
      countingDb.reset();
      final chars = await hanziDao.getCharactersByGlyphs(glyphs);

      expect(countingDb.queryCount, 1);
      expect(chars.length, 20);
    });
  });

  group('Sentence Module N+1 Optimization Benchmarks', () {
    test('1. Empty sentence IDs produce 0 queries', () async {
      countingDb.reset();
      final map = await sentenceRepo.getProgressForSentences([]);
      expect(map, isEmpty);
      expect(countingDb.queryCount, 0);
    });

    test('2. Single sentence query produces exactly 1 database query', () async {
      await db.insert(DatabaseConstants.tableSentencePracticeProgress, {
        'id': 'prog_s_1',
        'sentence_id': 's_1',
        'hsk_level': 1,
        'listening_attempts': 2,
        'best_score': 90.0,
      });

      countingDb.reset();
      final map = await sentenceRepo.getProgressForSentences(['s_1']);
      expect(countingDb.queryCount, 1);
      expect(map['s_1']!.bestScore, 90.0);
    });

    test('3. 501 sentences chunk safely into 2 batches (batchSize 300) instead of 501 queries', () async {
      final sentenceIds = List.generate(501, (i) => 'sentence_$i');
      for (int i = 0; i < 501; i += 2) {
        await db.insert(DatabaseConstants.tableSentencePracticeProgress, {
          'id': 'prog_sentence_$i',
          'sentence_id': 'sentence_$i',
          'hsk_level': 1,
          'listening_attempts': 1,
          'best_score': 88.0,
        });
      }

      countingDb.reset();
      final stopwatch = Stopwatch()..start();
      final map = await sentenceRepo.getProgressForSentences(sentenceIds);
      stopwatch.stop();

      // 501 items / 300 batchSize = ceil(501/300) = 2 queries!
      expect(countingDb.queryCount, 2);
      expect(map.length, 251);
      expect(stopwatch.elapsedMilliseconds, lessThan(300));
    });

    test('4. 1,000 sentences chunk safely into 4 batches (batchSize 300) instead of 1,000 queries', () async {
      final sentenceIds = List.generate(1000, (i) => 'sent_$i');
      for (int i = 0; i < 1000; i += 4) {
        await db.insert(DatabaseConstants.tableSentencePracticeProgress, {
          'id': 'prog_sent_$i',
          'sentence_id': 'sent_$i',
          'hsk_level': 1,
          'best_score': 95.0,
        });
      }

      countingDb.reset();
      final map = await sentenceRepo.getProgressForSentences(sentenceIds);

      // 1000 items / 300 batchSize = 4 queries!
      expect(countingDb.queryCount, 4);
      expect(map.length, 250);
    });

    test('5. Bulk audios fetch eliminates internal N+1 in getSentencesByHskLevel', () async {
      for (int i = 0; i < 30; i++) {
        final sentence = SentenceItem(
          id: 'tat_$i',
          chinese: '句子 $i',
          pinyin: 'jù zi $i',
          translationVi: 'Câu $i',
          hskLevel: 1,
          hasHumanAudio: true,
        );
        await db.insert(DatabaseConstants.tableSentences, sentence.toMap());
        await db.insert(DatabaseConstants.tableSentenceAudio, {
          'id': 'aud_$i',
          'sentence_id': 'tat_$i',
          'audio_type': 'human_recording',
          'speaker_name': 'Speaker',
        });
      }

      countingDb.reset();
      final list = await sentenceDao.getSentencesByHskLevel(1, limit: 30);

      // Previously: 1 query for sentences + 30 queries for audios = 31 queries!
      // Optimized: 1 query for sentences + 1 bulk query for audios = 2 queries!
      expect(countingDb.queryCount, 2);
      expect(list.length, 30);
      expect(list.first.audios.length, 1);
    });

    test('6. getSentencesByIds loads sentences and audios in bulk for review mode', () async {
      for (int i = 0; i < 3; i++) {
        final sentence = SentenceItem(
          id: 'tat_$i',
          chinese: '句子 $i',
          pinyin: 'jù zi $i',
          translationVi: 'Câu $i',
          hskLevel: 1,
          hasHumanAudio: true,
        );
        await db.insert(DatabaseConstants.tableSentences, sentence.toMap());
        await db.insert(DatabaseConstants.tableSentenceAudio, {
          'id': 'aud_$i',
          'sentence_id': 'tat_$i',
          'audio_type': 'human_recording',
          'speaker_name': 'Speaker',
        });
      }

      final ids = ['tat_0', 'tat_1', 'tat_2', 'tat_nonexistent'];
      countingDb.reset();
      final list = await sentenceDao.getSentencesByIds(ids);

      // 1 query for sentences + 1 query for audios = 2 queries
      expect(countingDb.queryCount, 2);
      expect(list.length, 3);
    });
  });
}
