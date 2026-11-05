import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/dao/reading_dao.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/core/database/seed/seed_loader.dart';
import 'package:hi_chinese/features/reading/reading.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late ReadingDao readingDao;
  late ReadingRepository readingRepo;
  late SeedLoader seedLoader;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('graded_reading_test_');
    final dbPath = '${tempDir.path}/test_graded_reading.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    readingDao = ReadingDao(db);
    readingRepo = DefaultReadingRepository(db);
    seedLoader = SeedLoader(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Graded Reading Dataset & Anki Ingestion Audit Tests', () {
    test('1. Verify anki_extracted_dialogues.json has >= 30 dialogues with valid audio files', () async {
      final dialoguesFile = File('assets/data/anki_extracted_dialogues.json');
      expect(dialoguesFile.existsSync(), isTrue);

      final content = dialoguesFile.readAsStringSync();
      final List<dynamic> list = json.decode(content);
      expect(list.length, greaterThanOrEqualTo(30));

      for (final item in list) {
        expect(item['id'], isNotNull);
        expect(item['hsk_level'], inInclusiveRange(1, 6));
        expect((item['hanzi'] as String).isNotEmpty, isTrue);
        expect((item['pinyin'] as String).isNotEmpty, isTrue);
        expect((item['translation_vi'] as String).isNotEmpty, isTrue);
        expect((item['audio_file'] as String).isNotEmpty, isTrue);

        final audioFile = File('assets/audio/curriculum/${item['audio_file']}');
        expect(audioFile.existsSync(), isTrue);
        expect(audioFile.lengthSync(), greaterThan(0));
      }
    });

    test('2. Verify graded_reading_passages.json integrity and distribution across HSK 1-4', () async {
      final passagesFile = File('assets/data/graded_reading_passages.json');
      expect(passagesFile.existsSync(), isTrue);

      final content = passagesFile.readAsStringSync();
      final List<dynamic> list = json.decode(content);
      expect(list.length, greaterThanOrEqualTo(60));

      final levelCounts = <int, int>{};
      for (final item in list) {
        final level = item['hsk_level'] as int;
        levelCounts[level] = (levelCounts[level] ?? 0) + 1;

        expect(item['id'], startsWith('RDG_C3_'));
        expect((item['title_cn'] as String).isNotEmpty, isTrue);
        expect((item['content_cn'] as String).isNotEmpty, isTrue);
        expect((item['pinyin'] as String).isNotEmpty, isTrue);
        expect((item['translation_vi'] as String).isNotEmpty, isTrue);

        final questions = item['questions'] as List<dynamic>;
        expect(questions.length, inInclusiveRange(2, 4));

        for (final q in questions) {
          expect((q['question'] as String).isNotEmpty, isTrue);
          final options = q['options'] as List<dynamic>;
          expect(options.length, equals(4));
          final answer = q['answer'] as int;
          expect(answer, inInclusiveRange(0, 3));
          expect((q['citationText'] as String).isNotEmpty, isTrue);
          expect((q['explanationVi'] as String).isNotEmpty, isTrue);
        }
      }

      for (int lvl = 1; lvl <= 4; lvl++) {
        expect(levelCounts[lvl], isNotNull);
        expect(levelCounts[lvl]!, greaterThanOrEqualTo(15));
      }
    });

    test('3. SeedLoader seeds graded passages into SQLite and verifies query richness', () async {
      final passagesFile = File('assets/data/graded_reading_passages.json');
      final rawJson = passagesFile.readAsStringSync();

      final result = await seedLoader.seedGradedReadingPassages(rawJson: rawJson);
      expect(result.success, isTrue);
      expect(result.totalItems, greaterThanOrEqualTo(60));

      final count = await readingDao.countPassages();
      expect(count, greaterThanOrEqualTo(60));

      final allPassages = await readingRepo.getPassages();
      expect(allPassages.length, greaterThanOrEqualTo(60));

      for (int lvl = 1; lvl <= 4; lvl++) {
        final levelPassages = await readingRepo.getPassages(hskLevel: lvl);
        expect(levelPassages.length, greaterThanOrEqualTo(15));
        expect(levelPassages.every((p) => p.hskLevel == lvl), isTrue);
        expect(levelPassages.first.questions.length, inInclusiveRange(2, 4));
        expect(levelPassages.first.questions.first.options.length, equals(4));
      }
    });

    test('4. SeedLoader idempotency runs in < 20ms and avoids duplicates', () async {
      final passagesFile = File('assets/data/graded_reading_passages.json');
      final rawJson = passagesFile.readAsStringSync();

      final firstRun = await seedLoader.seedGradedReadingPassages(rawJson: rawJson);
      expect(firstRun.success, isTrue);

      final sw = Stopwatch()..start();
      final secondRun = await seedLoader.seedGradedReadingPassages(rawJson: rawJson);
      sw.stop();

      expect(secondRun.skipped, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(20));

      final count = await readingDao.countPassages();
      expect(count, equals(firstRun.totalItems));
    });

    test('5. Re-seeding preserves user reading progress and answers', () async {
      final passagesFile = File('assets/data/graded_reading_passages.json');
      final rawJson = passagesFile.readAsStringSync();

      await seedLoader.seedGradedReadingPassages(rawJson: rawJson);

      const testPassageId = 'RDG_C3_001';
      await readingRepo.saveReadingSession(
        passageId: testPassageId,
        readingTimeSeconds: 150,
        lastScrollOffset: 450.0,
        answers: const {'q_c3_001_1': 1, 'q_c3_001_2': 3},
        isCompleted: true,
        score: 100.0,
      );

      final progressBefore = await readingRepo.getProgress(testPassageId);
      expect(progressBefore, isNotNull);
      expect(progressBefore!.isCompleted, isTrue);
      expect(progressBefore.score, equals(100.0));

      await seedLoader.seedGradedReadingPassages(rawJson: rawJson, forceReload: true);

      final progressAfter = await readingRepo.getProgress(testPassageId);
      expect(progressAfter, isNotNull);
      expect(progressAfter!.isCompleted, isTrue);
      expect(progressAfter.readingTimeSeconds, equals(150));
      expect(progressAfter.lastScrollOffset, equals(450.0));
      expect(progressAfter.score, equals(100.0));
      expect(progressAfter.answers['q_c3_001_1'], equals(1));
    });
  });
}
