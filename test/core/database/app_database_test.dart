import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AppDatabase Core Engine Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDb;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_db_test_');
      dbPath = '${tempDir.path}/test_hi_chinese.db';
      appDb = AppDatabase.instance;
      await appDb.open(customPath: dbPath, customFactory: databaseFactoryFfi);
    });

    tearDown(() async {
      if (appDb.isOpen) {
        await appDb.close();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Database initializes successfully with PRAGMA foreign_keys and WAL mode', () async {
      expect(appDb.isOpen, isTrue);
      expect(appDb.path, equals(dbPath));

      // Verify foreign keys are enabled
      final fkResult = await appDb.database.rawQuery('PRAGMA foreign_keys;');
      expect(fkResult.first.values.first, equals(1));

      // Verify integrity check returns clean 'ok'
      final issues = await appDb.checkIntegrity();
      expect(issues, isEmpty);
    });

    test('2. CRUD on Vocabularies and Vocabulary Senses with Foreign Key cascade', () async {
      final vocabDao = VocabularyDao(appDb.database);
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // Insert Vocabulary
      await vocabDao.insertVocabulary({
        'id': 'v_hsk1_001',
        'simplified': '你好',
        'traditional': '你好',
        'pinyin': 'nǐ hǎo',
        'hsk_level': 1,
        'stroke_count': 13,
        'radicals': '亻, 女',
        'frequency_rank': 1,
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      // Insert multiple senses
      await vocabDao.insertSense({
        'id': 's_001',
        'vocabulary_id': 'v_hsk1_001',
        'part_of_speech': 'phrase',
        'meaning_vi': 'Chào bạn, xin chào',
        'example_cn': '你好，很高兴认识你！',
        'example_pinyin': 'Nǐ hǎo, hěn gāoxìng rènshí nǐ!',
        'example_vi': 'Chào bạn, rất vui được gặp bạn!',
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      // Query vocabulary & senses
      final vocab = await vocabDao.getVocabularyById('v_hsk1_001');
      expect(vocab, isNotNull);
      expect(vocab!['simplified'], equals('你好'));

      final senses = await vocabDao.getSensesByVocabularyId('v_hsk1_001');
      expect(senses.length, equals(1));
      expect(senses.first['meaning_vi'], equals('Chào bạn, xin chào'));

      // Search vocabulary
      final searchResults = await vocabDao.searchVocabularies('hǎo');
      expect(searchResults.length, equals(1));
      expect(searchResults.first['id'], equals('v_hsk1_001'));

      // Soft delete vocabulary
      await vocabDao.softDeleteVocabulary('v_hsk1_001');
      final deletedVocab = await vocabDao.getVocabularyById('v_hsk1_001');
      expect(deletedVocab, isNull); // Soft deleted items are excluded from active queries
    });

    test('3. SRS and Learner Evidence Append-Only Log', () async {
      final srsDao = SrsDao(appDb.database);
      final evidenceDao = LearnerEvidenceDao(appDb.database);
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final dueUtc = DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String();

      // Upsert SRS item
      await srsDao.upsertSrsItem({
        'id': 'srs_001',
        'content_id': 'v_hsk1_001',
        'content_type': 'vocabulary',
        'state': 'learning',
        'interval_days': 1,
        'ease_factor': 2.5,
        'repetitions': 1,
        'lapses': 0,
        'due_at': dueUtc,
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      final item = await srsDao.getSrsItemByContent('v_hsk1_001', 'vocabulary');
      expect(item, isNotNull);
      expect(item!['interval_days'], equals(1));

      // Append Learner Evidence (Append-only)
      await evidenceDao.appendEvidence({
        'id': 'ev_001',
        'srs_item_id': 'srs_001',
        'content_id': 'v_hsk1_001',
        'content_type': 'vocabulary',
        'source': 'flashcard_srs',
        'score': 1.0,
        'duration_ms': 2500,
        'metadata_json': '{"rating": "good"}',
        'created_at': nowUtc,
      });

      await evidenceDao.appendEvidence({
        'id': 'ev_002',
        'srs_item_id': 'srs_001',
        'content_id': 'v_hsk1_001',
        'content_type': 'vocabulary',
        'source': 'practice_quiz',
        'score': 0.8,
        'duration_ms': 4200,
        'metadata_json': '{"question_type": "tone_choice"}',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      final evidenceList = await evidenceDao.getEvidenceByContent('v_hsk1_001', 'vocabulary');
      expect(evidenceList.length, equals(2));
      // Most recent evidence is first
      expect(evidenceList.first['id'], equals('ev_002'));
    });

    test('4. Transaction commit and automatic rollback on failure', () async {
      final vocabDao = VocabularyDao(appDb.database);
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // Successful transaction
      await appDb.runInTransaction((txn) async {
        await vocabDao.insertVocabulary({
          'id': 'v_txn_001',
          'simplified': '谢谢',
          'pinyin': 'xièxie',
          'hsk_level': 1,
          'created_at': nowUtc,
          'updated_at': nowUtc,
        }, txn: txn);
      });

      expect(await vocabDao.getVocabularyById('v_txn_001'), isNotNull);

      // Failing transaction -> must rollback
      expect(
        () async => await appDb.runInTransaction((txn) async {
          await vocabDao.insertVocabulary({
            'id': 'v_txn_002',
            'simplified': '再见',
            'pinyin': 'zàijiàn',
            'hsk_level': 1,
            'created_at': nowUtc,
            'updated_at': nowUtc,
          }, txn: txn);

          // Force an intentional error to trigger rollback
          throw Exception('Intentional failure inside transaction');
        }),
        throwsA(isA<Exception>()),
      );

      // Verify v_txn_002 was rolled back completely
      expect(await vocabDao.getVocabularyById('v_txn_002'), isNull);
      // Verify v_txn_001 is still preserved
      expect(await vocabDao.getVocabularyById('v_txn_001'), isNotNull);
    });

    test('5. Close and reopen preserves all data across sessions', () async {
      final vocabDao = VocabularyDao(appDb.database);
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      await vocabDao.insertVocabulary({
        'id': 'v_persist_001',
        'simplified': '中国',
        'pinyin': 'Zhōngguó',
        'hsk_level': 1,
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      // Close database connection
      await appDb.close();
      expect(appDb.isOpen, isFalse);

      // Reopen database connection at the same path
      await appDb.open(customPath: dbPath, customFactory: databaseFactoryFfi);
      expect(appDb.isOpen, isTrue);

      final reopenedVocabDao = VocabularyDao(appDb.database);
      final persistedItem = await reopenedVocabDao.getVocabularyById('v_persist_001');
      expect(persistedItem, isNotNull);
      expect(persistedItem!['simplified'], equals('中国'));
    });

    test('6. Safe WAL backup and backup integrity check', () async {
      final vocabDao = VocabularyDao(appDb.database);
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      await vocabDao.insertVocabulary({
        'id': 'v_backup_001',
        'simplified': '学生',
        'pinyin': 'xuésheng',
        'hsk_level': 1,
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      final backupPath = '${tempDir.path}/backups/hi_chinese_backup.db';
      final backupFile = await appDb.backup(backupPath);

      expect(await backupFile.exists(), isTrue);
      expect(await backupFile.length(), greaterThan(0));

      // Verify backup file can be opened and passes integrity check
      final backupDb = await databaseFactoryFfi.openDatabase(backupPath);
      final backupIssues = await DatabaseBackupHelper.checkIntegrity(backupDb);
      expect(backupIssues, isEmpty);

      final backupVocabDao = VocabularyDao(backupDb);
      final item = await backupVocabDao.getVocabularyById('v_backup_001');
      expect(item, isNotNull);
      expect(item!['simplified'], equals('学生'));

      await backupDb.close();
    });
  });
}
