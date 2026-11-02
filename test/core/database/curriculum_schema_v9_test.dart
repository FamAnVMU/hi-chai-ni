import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/core/database/dao/curriculum_dao.dart';
import 'package:hi_chinese/core/database/dao/content_item_dao.dart';
import 'package:hi_chinese/core/database/dao/mastery_dao.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Schema v9 & Curriculum Content Catalog Tests', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('curriculum_v9_test_');
      dbPath = '${tempDir.path}/test_v9.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Database opens at version 9 and creates all curriculum tables', () async {
      final version = await db.getVersion();
      expect(version, 9);

      // Verify tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames.contains(DatabaseConstants.tableContentPacks), isTrue);
      expect(tableNames.contains(DatabaseConstants.tableCurriculums), isTrue);
      expect(tableNames.contains(DatabaseConstants.tableCurriculumUnits), isTrue);
      expect(tableNames.contains(DatabaseConstants.tableCurriculumLessons), isTrue);
      expect(tableNames.contains(DatabaseConstants.tableLessonSegments), isTrue);
      expect(tableNames.contains(DatabaseConstants.tableContentItems), isTrue);
      expect(tableNames.contains(DatabaseConstants.tableCurriculumMastery), isTrue);
      expect(tableNames.contains(DatabaseConstants.tableLevelExitExams), isTrue);
    });

    test('2. CurriculumDao CRUD for ContentPack, Curriculum, Unit, Lesson, and Segments', () async {
      final dao = CurriculumDao(db);
      final now = DateTime.now().toUtc().toIso8601String();

      // Insert Content Pack
      await dao.insertContentPack({
        'id': 'pack_hsk1',
        'hsk_level': 1,
        'version': '1.0.0',
        'title': 'HSK 1 Standard Curriculum',
        'is_bundled': 1,
        'status': 'bundled',
        'size_bytes': 15728640,
        'checksum_sha256': 'mock_sha256_hash',
        'installed_at': now,
        'updated_at': now,
      });

      final pack = await dao.getContentPack('pack_hsk1');
      expect(pack, isNotNull);
      expect(pack!['hsk_level'], 1);
      expect(pack['is_bundled'], 1);

      // Insert Curriculum
      await dao.insertCurriculum({
        'id': 'curr_hsk1',
        'pack_id': 'pack_hsk1',
        'code': 'HSK_2012_L1',
        'standard_name': 'HSK 2.0 Level 1',
        'hsk_level': 1,
        'total_units': 5,
        'total_lessons': 15,
        'created_at': now,
      });

      // Insert Unit
      await dao.insertUnit({
        'id': 'unit_1',
        'curriculum_id': 'curr_hsk1',
        'order_index': 1,
        'title_vi': 'Chào hỏi căn bản',
        'title_zh': '问候',
        'description_vi': 'Làm quen với các cách chào hỏi',
        'is_locked': 0,
        'created_at': now,
      });

      // Insert Lesson
      await dao.insertLesson({
        'id': 'lesson_1_1',
        'unit_id': 'unit_1',
        'order_index': 1,
        'title_vi': 'Xin chào',
        'title_zh': '你好',
        'pinyin': 'Nǐ hǎo',
        'estimated_minutes': 15,
        'is_locked': 0,
        'unlock_score_threshold': 0.8,
        'prerequisites_json': '[]',
        'status': 'not_started',
        'created_at': now,
      });

      // Insert Lesson Segments (6 steps)
      for (int i = 1; i <= 6; i++) {
        await dao.insertSegment({
          'id': 'seg_1_1_$i',
          'lesson_id': 'lesson_1_1',
          'step_order': i,
          'segment_type': ['warmup', 'vocabulary', 'grammar', 'dialogue', 'practice', 'mastery_check'][i - 1],
          'title': 'Chặng $i',
          'created_at': now,
        });
      }

      final lessons = await dao.getLessonsByUnitId('unit_1');
      expect(lessons.length, 1);
      expect(lessons.first['title_zh'], '你好');

      final segments = await dao.getSegmentsByLessonId('lesson_1_1');
      expect(segments.length, 6);
      expect(segments.first['segment_type'], 'warmup');
      expect(segments.last['segment_type'], 'mastery_check');
    });

    test('3. ContentItemDao inserts and queries multi-type content catalog', () async {
      final dao = ContentItemDao(db);
      final now = DateTime.now().toUtc().toIso8601String();

      await dao.insertContentItem({
        'id': 'ci_vocab_nihao',
        'content_id': 'VOCAB_NIHAO',
        'curriculum_id': 'curr_hsk1',
        'hsk_level': 1,
        'knowledge_type': 'vocabulary',
        'title': '你好',
        'content_json': '{"simplified":"你好","pinyin":"nǐ hǎo","meaning_vi":"Xin chào"}',
        'objectives_json': '["chao_hoi_can_ban"]',
        'source_reference': 'HSK 2.0 Official Vocabulary List',
        'audit_status': 'verified',
        'content_version': '1.0.0',
        'created_at': now,
        'updated_at': now,
      });

      final item = await dao.getContentItemByContentId('VOCAB_NIHAO');
      expect(item, isNotNull);
      expect(item!['title'], '你好');
      expect(item['knowledge_type'], 'vocabulary');
      expect(item['audit_status'], 'verified');

      final items = await dao.getContentItemsByLevelAndType(1, 'vocabulary');
      expect(items.length, 1);
    });

    test('4. MasteryDao tracks 5 states and updates mastery progression', () async {
      final dao = MasteryDao(db);
      final now = DateTime.now().toUtc().toIso8601String();

      await dao.upsertMastery({
        'id': 'mastery_lesson_1',
        'item_id': 'lesson_1_1',
        'item_type': 'lesson',
        'mastery_state': 'in_progress',
        'score': 0.75,
        'attempts_count': 1,
        'last_attempt_at': now,
        'created_at': now,
        'updated_at': now,
      });

      var record = await dao.getMastery('lesson_1_1');
      expect(record, isNotNull);
      expect(record!['mastery_state'], 'in_progress');
      expect(record['score'], 0.75);

      // Complete lesson with score >= 0.8
      await dao.upsertMastery({
        'id': 'mastery_lesson_1',
        'item_id': 'lesson_1_1',
        'item_type': 'lesson',
        'mastery_state': 'completed',
        'score': 0.90,
        'attempts_count': 2,
        'last_attempt_at': now,
        'created_at': now,
        'updated_at': now,
      });

      record = await dao.getMastery('lesson_1_1');
      expect(record!['mastery_state'], 'completed');
      expect(record['score'], 0.90);
      expect(record['attempts_count'], 2);
    });
  });
}
