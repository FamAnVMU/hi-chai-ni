import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_v1.dart';
import 'package:hi_chinese/core/database/migrations/migration_v5.dart';
import 'package:hi_chinese/core/database/migrations/migration_v9.dart';
import 'package:hi_chinese/core/database/migrations/migration_v10.dart';
import 'package:hi_chinese/core/database/migrations/migration_v12.dart';
import 'package:hi_chinese/core/database/dao/content_item_dao.dart';
import 'package:hi_chinese/core/database/dao/mastery_dao.dart';
import 'package:hi_chinese/core/database/dao/srs_dao.dart';
import 'package:hi_chinese/core/database/dao/vocabulary_dao.dart';
import 'package:hi_chinese/features/content_packs/data/content_pack_manager.dart';
import 'package:hi_chinese/features/vocabulary_srs/data/srs_repository.dart';
import 'package:hi_chinese/features/vocabulary_srs/domain/srs_models.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ContentPackManager packManager;
  late VocabularyDao vocabDao;
  late MasteryDao masteryDao;
  late SrsDao srsDao;
  late SrsRepository srsRepo;
  late ContentItemDao contentItemDao;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (d, v) async {
        await const MigrationV1().up(d);
        await const MigrationV5().up(d);
        await const MigrationV9().up(d);
        await const MigrationV10().up(d);
        await const MigrationV12().up(d);
      },
    );

    // Verify foreign keys active
    final fkPragma = await db.rawQuery('PRAGMA foreign_keys;');
    expect(Sqflite.firstIntValue(fkPragma), equals(1));

    packManager = ContentPackManager(db);
    vocabDao = VocabularyDao(db);
    masteryDao = MasteryDao(db);
    srsDao = SrsDao(db);
    srsRepo = SrsRepository(db);
    contentItemDao = ContentItemDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('P0-04: Non-Destructive Upsert & Foreign Key Cascade Prevention Tests', () {
    final samplePackV1 = json.encode({
      'manifest': {
        'pack_id': 'hsk1_core',
        'curriculum_id': 'curr_hsk1',
        'title': 'HSK 1 Core Curriculum',
        'version': '1.0.0',
        'hsk_level': 1,
        'author': 'HI Chinese Team',
        'description': 'HSK 1 Initial Pack',
        'package_size': 1024,
      },
      'curriculum': {
        'id': 'curr_hsk1',
        'code': 'HSK1',
        'standard_name': 'HSK Level 1',
        'units': [
          {
            'id': 'unit_1',
            'order_index': 1,
            'title_vi': 'Chào hỏi',
            'title_zh': '问候',
            'is_locked': 1,
            'lessons': [
              {
                'id': 'lesson_1_1',
                'order_index': 1,
                'title_vi': 'Xin chào',
                'title_zh': '你好',
                'pinyin': 'Nǐ hǎo',
                'is_locked': 1,
                'status': 'not_started',
                'segments': [
                  {
                    'id': 'seg_1_1_1',
                    'step_order': 1,
                    'segment_type': 'vocabulary',
                    'title': 'Từ vựng bài 1',
                    'content_ref_id': 'VOCAB_001',
                  }
                ],
              }
            ],
          }
        ],
      },
      'content_items': [
        {
          'content_id': 'VOCAB_001',
          'curriculum_id': 'curr_hsk1',
          'hsk_level': 1,
          'knowledge_type': 'vocabulary',
          'title': 'Từ vựng 你好',
          'content_json': {
            'words': [
              {
                'simplified': '你好',
                'pinyin': 'nǐhǎo',
                'meaning_vi': 'Xin chào',
                'part_of_speech': 'phrase',
              }
            ]
          },
        }
      ],
    });

    final samplePackV2 = json.encode({
      'manifest': {
        'pack_id': 'hsk1_core',
        'curriculum_id': 'curr_hsk1',
        'title': 'HSK 1 Core Curriculum (Updated)',
        'version': '1.1.0', // UPGRADE
        'hsk_level': 1,
        'author': 'HI Chinese Team',
        'description': 'HSK 1 Updated Pack with richer definitions',
        'package_size': 2048,
      },
      'curriculum': {
        'id': 'curr_hsk1',
        'code': 'HSK1',
        'standard_name': 'HSK Level 1 Standard',
        'units': [
          {
            'id': 'unit_1',
            'order_index': 1,
            'title_vi': 'Chào hỏi & Giao tiếp ban đầu', // Updated title
            'title_zh': '问候',
            'is_locked': 1,
            'lessons': [
              {
                'id': 'lesson_1_1',
                'order_index': 1,
                'title_vi': 'Xin chào (Bài học chuẩn)', // Updated title
                'title_zh': '你好',
                'pinyin': 'Nǐ hǎo',
                'is_locked': 1, // Notice pack says 1, but learner already unlocked!
                'status': 'not_started',
                'segments': [
                  {
                    'id': 'seg_1_1_1',
                    'step_order': 1,
                    'segment_type': 'vocabulary',
                    'title': 'Từ vựng trọng tâm bài 1',
                    'content_ref_id': 'VOCAB_001',
                  }
                ],
              }
            ],
          }
        ],
      },
      'content_items': [
        {
          'content_id': 'VOCAB_001',
          'curriculum_id': 'curr_hsk1',
          'hsk_level': 1,
          'knowledge_type': 'vocabulary',
          'title': 'Từ vựng 你好 (Tái bản)',
          'content_json': {
            'words': [
              {
                'simplified': '你好',
                'pinyin': 'nǐhǎo',
                'meaning_vi': 'Chào bạn / Xin chào',
                'part_of_speech': 'phrase',
              }
            ]
          },
        }
      ],
    });

    test('Full Lifecycle: Import pack -> Record learner progress & SRS -> Upgrade pack -> Zero data loss', () async {
      // Step 1: Initial import of Content Pack v1
      final res1 = await packManager.installOrUpdatePack(samplePackV1);
      expect(res1.isSuccess, isTrue);

      // Verify records inserted
      final lessons = await db.query(DatabaseConstants.tableCurriculumLessons, where: 'id = ?', whereArgs: ['lesson_1_1']);
      expect(lessons.length, equals(1));
      expect(lessons.first['title_vi'], equals('Xin chào'));

      // Step 2: Simulate User Learning Progress
      final nowIso = DateTime.now().toUtc().toIso8601String();
      // A. Unlock unit & lesson, mark completed
      await db.update(
        DatabaseConstants.tableCurriculumUnits,
        {'is_locked': 0},
        where: 'id = ?',
        whereArgs: ['unit_1'],
      );
      await db.update(
        DatabaseConstants.tableCurriculumLessons,
        {
          'status': 'completed',
          'is_locked': 0,
          'completed_at': nowIso,
          'credited_reason': 'quiz_passed',
        },
        where: 'id = ?',
        whereArgs: ['lesson_1_1'],
      );

      // B. Create personal Lesson Progress entry (in tableLessonProgress)
      await db.insert(DatabaseConstants.tableLessonProgress, {
        'id': 'prog_lesson_1_1',
        'lesson_id': 'lesson_1_1',
        'unit_id': 'unit_1',
        'hsk_level': 1,
        'status': 'completed',
        'completion_score': 0.95,
        'evidence_count': 3,
        'started_at': nowIso,
        'completed_at': nowIso,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // C. Create Curriculum Mastery entry (in tableCurriculumMastery)
      await masteryDao.upsertMastery({
        'id': 'mast_vocab_nihao',
        'item_id': 'KNOW_VOCAB_你好',
        'item_type': 'vocabulary',
        'mastery_state': 'mastered',
        'score': 0.98,
        'attempts_count': 5,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // D. Create SRS Flashcard State (in tableSrsItems)
      await srsRepo.processReview(
        contentId: 'vocab_你好',
        contentType: 'vocabulary',
        rating: SrsRating.good,
        reviewTime: DateTime.now().toUtc(),
      );

      // Verify SRS exists and interval > 0
      final srsCardBefore = await srsDao.getSrsItemByContent('vocab_你好', 'vocabulary');
      expect(srsCardBefore, isNotNull);
      expect(srsCardBefore!['repetitions'], equals(1));
      final srsOriginalId = srsCardBefore['id'];

      // Step 3: Upgrade Content Pack to v1.1.0 (Same pack_id, updated content)
      final res2 = await packManager.installOrUpdatePack(samplePackV2);
      expect(res2.isSuccess, isTrue);

      // Step 4: Verify Content updated in-place without deleting parent or child rows
      final updatedLesson = await db.query(DatabaseConstants.tableCurriculumLessons, where: 'id = ?', whereArgs: ['lesson_1_1']);
      expect(updatedLesson.first['title_vi'], equals('Xin chào (Bài học chuẩn)'));

      // CRITICAL ASSERTION 1: Unit unlock status preserved!
      final unitAfter = await db.query(DatabaseConstants.tableCurriculumUnits, where: 'id = ?', whereArgs: ['unit_1']);
      expect(unitAfter.first['is_locked'], equals(0));

      // CRITICAL ASSERTION 2: Lesson completion status preserved!
      expect(updatedLesson.first['status'], equals('completed'));
      expect(updatedLesson.first['is_locked'], equals(0));
      expect(updatedLesson.first['completed_at'], isNotNull);
      expect(updatedLesson.first['credited_reason'], equals('quiz_passed'));

      // CRITICAL ASSERTION 3: Personal Lesson Progress row remains untouched!
      final progressRows = await db.query(DatabaseConstants.tableLessonProgress, where: 'lesson_id = ?', whereArgs: ['lesson_1_1']);
      expect(progressRows.length, equals(1));
      expect(progressRows.first['completion_score'], equals(0.95));

      // CRITICAL ASSERTION 4: Curriculum Mastery progress remains untouched!
      final masteryRecord = await masteryDao.getMastery('KNOW_VOCAB_你好');
      expect(masteryRecord, isNotNull);
      expect(masteryRecord!['mastery_state'], equals('mastered'));
      expect(masteryRecord['score'], equals(0.98));
      expect(masteryRecord['attempts_count'], equals(5));

      // CRITICAL ASSERTION 5: SRS Flashcard is preserved with identical ID and interval!
      final srsCardAfter = await srsDao.getSrsItemByContent('vocab_你好', 'vocabulary');
      expect(srsCardAfter, isNotNull);
      expect(srsCardAfter!['id'], equals(srsOriginalId));
      expect(srsCardAfter['repetitions'], equals(1));

      // Step 5: Check SQLite Foreign Key Integrity
      final fkCheck = await db.rawQuery('PRAGMA foreign_key_check;');
      expect(fkCheck, isEmpty, reason: 'PRAGMA foreign_key_check must return 0 violations');

      // Step 6: Verify repeated import idempotency
      final res3 = await packManager.installOrUpdatePack(samplePackV2);
      expect(res3.isSuccess, isTrue);
      final lessonsCount = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableCurriculumLessons}');
      expect(Sqflite.firstIntValue(lessonsCount), equals(1));
    });

    test('VocabularyDao safe upsert preserves child senses and foreign key relationships', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // 1. Insert initial vocabulary
      await vocabDao.insertVocabulary({
        'id': 'VOC_TEST_1',
        'simplified': '看',
        'pinyin': 'kàn',
        'hsk_level': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // 2. Insert child sense (has FOREIGN KEY (vocabulary_id) REFERENCES vocabularies (id) ON DELETE CASCADE)
      await vocabDao.insertSense({
        'id': 'SENSE_TEST_1',
        'vocabulary_id': 'VOC_TEST_1',
        'part_of_speech': 'verb',
        'meaning_vi': 'nhìn, xem',
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // 3. Re-insert or update vocabulary with enriched attributes
      await vocabDao.insertVocabulary({
        'id': 'VOC_TEST_1',
        'simplified': '看',
        'pinyin': 'kàn',
        'pinyin_clean': 'kan',
        'hanviet': 'Khán',
        'hsk_level': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // 4. Verify sense WAS NOT cascade deleted!
      final senses = await vocabDao.getSensesByVocabularyId('VOC_TEST_1');
      expect(senses.length, equals(1));
      expect(senses.first['id'], equals('SENSE_TEST_1'));
      expect(senses.first['meaning_vi'], equals('nhìn, xem'));

      // 5. Verify PRAGMA foreign_key_check is completely clean
      final fkCheck = await db.rawQuery('PRAGMA foreign_key_check;');
      expect(fkCheck, isEmpty);
    });

    test('ContentItemDao safe upsert preserves original ID and content updates', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();

      await contentItemDao.insertContentItem({
        'id': 'ci_original_1',
        'content_id': 'CID_100',
        'curriculum_id': 'curr_hsk1',
        'hsk_level': 1,
        'knowledge_type': 'vocabulary',
        'title': 'Original Title',
        'content_json': '{"text":"first"}',
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // Insert again with different internal ID
      await contentItemDao.insertContentItem({
        'id': 'ci_new_attempt',
        'content_id': 'CID_100',
        'curriculum_id': 'curr_hsk1',
        'hsk_level': 1,
        'knowledge_type': 'vocabulary',
        'title': 'Updated Title',
        'content_json': '{"text":"second"}',
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      final item = await contentItemDao.getContentItemByContentId('CID_100');
      expect(item, isNotNull);
      // Preserves original primary key ID
      expect(item!['id'], equals('ci_original_1'));
      // Updates fields
      expect(item['title'], equals('Updated Title'));
      expect(item['content_json'], equals('{"text":"second"}'));
    });
  });
}
