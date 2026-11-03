import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/sentences/data/audio_pack_manager.dart';
import 'package:hi_chinese/features/sentences/data/sentence_dao.dart';
import 'package:hi_chinese/features/sentences/domain/models/sentence_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AudioPack CDN & Auto-Extract Integration Tests', () {
    late Database db;
    late SentenceDao dao;
    late AudioPackManager packManager;
    late Directory tempStorageDir;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath, version: DatabaseConstants.currentDatabaseVersion,
          onCreate: (db, version) async {
        final engine = MigrationEngine();
        await engine.executeMigrations(db, 0, version);
      });
      dao = SentenceDao(db);

      tempStorageDir = Directory.systemTemp.createTempSync('audio_packs_test_');
      packManager = AudioPackManager(
        dao,
        storageDirectory: tempStorageDir.path,
      );

      // Seed 2 sample sentences for HSK 3
      await dao.insertSentencesBatch([
        SentenceItem(
          id: 'test_sent_3_1',
          chinese: '你假期有什么打算？',
          pinyin: 'Nǐ jiàqī yǒu shénme dǎsuàn?',
          translationVi: 'Kỳ nghỉ bạn có dự định gì?',
          hskLevel: 3,
          hasHumanAudio: true,
          audios: [
            SentenceAudio(
              id: '1276694',
              sentenceId: 'test_sent_3_1',
              audioType: AudioType.humanRecording,
              fileFormat: 'mp3',
              status: 'remote',
            )
          ],
        ),
      ]);
    });

    tearDown(() async {
      if (tempStorageDir.existsSync()) {
        tempStorageDir.deleteSync(recursive: true);
      }
      await db.close();
    });

    test('HSK 1 and HSK 2 are bundled by default in APK', () async {
      final packs = await packManager.getAvailablePacks();

      expect(packs.length, 6);

      // HSK 1
      expect(packs[0].hskLevel, 1);
      expect(packs[0].isBundled, isTrue);
      expect(packs[0].isDownloaded, isTrue);
      expect(packs[0].downloadStatus, 'bundled');

      // HSK 2
      expect(packs[1].hskLevel, 2);
      expect(packs[1].isBundled, isTrue);
      expect(packs[1].isDownloaded, isTrue);
      expect(packs[1].downloadStatus, 'bundled');

      // HSK 3
      expect(packs[2].hskLevel, 3);
      expect(packs[2].isBundled, isFalse);
      expect(packs[2].isDownloaded, isFalse);
      expect(packs[2].downloadStatus, 'not_downloaded');
    });

    test('HSK 3 downloads and auto-extracts zip archive from GitHub CDN', () async {
      double lastProgress = 0.0;

      await packManager.downloadPack(
        'audio_pack_hsk3',
        onProgress: (prog) {
          lastProgress = prog;
        },
      );

      expect(lastProgress, 1.0);

      // Check extracted directory
      final hsk3Dir = Directory('${tempStorageDir.path}/hsk3');
      expect(hsk3Dir.existsSync(), isTrue);

      final extractedFiles = hsk3Dir.listSync();
      expect(extractedFiles.isNotEmpty, isTrue);

      // Check database update
      final sents = await dao.getSentencesByHskLevel(3);
      expect(sents.isNotEmpty, isTrue);
      final audio = sents.first.audios.first;
      expect(audio.status, 'downloaded');
      expect(audio.localPath, isNotNull);
      expect(audio.localPath!.contains('hsk3'), isTrue);

      // Check available packs now reflects downloaded status
      final packs = await packManager.getAvailablePacks();
      expect(packs[2].isDownloaded, isTrue);
      expect(packs[2].downloadStatus, 'downloaded');
    });
  });
}
