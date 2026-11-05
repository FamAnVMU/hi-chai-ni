import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/migrations/migration_v15.dart';
import 'package:hi_chinese/features/sentences/data/sentence_dao.dart';
import 'package:hi_chinese/features/sentences/data/sentence_repository.dart';
import 'package:hi_chinese/features/sentences/domain/models/sentence_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationV15 and SentenceRepository', () {
    late Database db;
    late SentenceDao dao;
    late DefaultSentenceRepository repository;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      // Run Migration v15
      const migration = MigrationV15();
      await migration.up(db);

      dao = SentenceDao(db);
      repository = DefaultSentenceRepository(dao);
    });

    tearDown(() async {
      await db.close();
    });

    test('MigrationV15 creates sentences, sentence_audio, and sentence_practice_progress tables', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('sentences', 'sentence_audio', 'sentence_practice_progress')",
      );
      final names = tables.map((t) => t['name'] as String).toSet();
      expect(names.contains('sentences'), isTrue);
      expect(names.contains('sentence_audio'), isTrue);
      expect(names.contains('sentence_practice_progress'), isTrue);
    });

    test('inserts and retrieves SentenceItem with audios and level filtering', () async {
      final sample = SentenceItem(
        id: 'tat_42',
        chinese: '你好吗？',
        pinyin: 'nǐ hǎo ma',
        translationVi: 'Bạn khỏe không?',
        translationEn: 'How are you?',
        hskLevel: 1,
        hasHumanAudio: true,
        audios: [
          const SentenceAudio(
            id: 'audio_42',
            sentenceId: 'tat_42',
            audioType: AudioType.humanRecording,
            speakerName: 'fucongcong',
            urlRemote: 'https://tatoeba.org/audio/download/42',
            license: 'CC BY-NC 4.0',
          ),
        ],
      );

      await dao.insertSentencesBatch([sample]);

      final fetched = await repository.getSentenceById('tat_42');
      expect(fetched, isNotNull);
      expect(fetched!.chinese, '你好吗？');
      expect(fetched.hskLevel, 1);
      expect(fetched.hasHumanAudio, isTrue);
      expect(fetched.audios.length, 1);
      expect(fetched.audios.first.speakerName, 'fucongcong');

      final level1List = await repository.getSentencesByHskLevel(1);
      expect(level1List.length, 1);
      expect(level1List.first.id, 'tat_42');

      final humanAudioList = await repository.getSentencesByHskLevel(1, humanAudioOnly: true);
      expect(humanAudioList.length, 1);
    });

    test('searchSentences matches Chinese, Pinyin, or Vietnamese', () async {
      final sample = const SentenceItem(
        id: 's_100',
        chinese: '明天天气很好。',
        pinyin: 'míng tiān tiān qì hěn hǎo',
        translationVi: 'Ngày mai thời tiết rất đẹp.',
        hskLevel: 2,
      );

      await dao.insertSentencesBatch([sample]);

      final byZh = await repository.searchSentences('天气');
      expect(byZh.length, 1);

      final byPinyin = await repository.searchSentences('tianqi');
      expect(byPinyin.isNotEmpty, isTrue);

      final byVi = await repository.searchSentences('thời tiết');
      expect(byVi.length, 1);
    });

    test('recordPracticeAttempt updates listening, shadowing, and schedules SRS', () async {
      await repository.recordPracticeAttempt(
        sentenceId: 's_100',
        practiceType: 'listening',
        score: 100.0,
      );

      final progress = await repository.getProgress('s_100');
      expect(progress, isNotNull);
      expect(progress!.listeningAttempts, 1);
      expect(progress.lastScore, 100.0);
      expect(progress.masteryLevel, 'mastered');
      expect(progress.srsDueDate, isNotNull);
      expect(progress.srsDueDate!.isAfter(DateTime.now()), isTrue);

      await repository.recordPracticeAttempt(
        sentenceId: 's_100',
        practiceType: 'shadowing',
        score: 75.0,
        recordedAudioPath: '/mock/user_shadow.m4a',
      );

      final updatedProgress = await repository.getProgress('s_100');
      expect(updatedProgress!.listeningAttempts, 1);
      expect(updatedProgress.shadowingAttempts, 1);
      expect(updatedProgress.lastShadowingAudioPath, '/mock/user_shadow.m4a');
    });

    test('ensureSeedLoaded handles missing asset gracefully', () async {
      final loaded = await repository.ensureSeedLoaded(assetPath: 'assets/non_existent_sentences.json');
      expect(loaded, 0);
    });

    test('concurrent ensureSeedLoaded calls deduplicate without race conditions', () async {
      final futures = List.generate(5, (_) => repository.ensureSeedLoaded(assetPath: 'assets/non_existent_sentences.json'));
      final results = await Future.wait(futures);
      expect(results, equals([0, 0, 0, 0, 0]));
    });
  });
}
