import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/dao/curriculum_dao.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/startup/app_startup_provider.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
  });

  group('Pack Upgrade Integrity & Casing-Insensitive Join Tests', () {
    late Directory tempDir;
    late Database db;
    late CurriculumDao curriculumDao;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pack_integrity_test_');
      final dbPath = '${tempDir.path}/pack_integrity.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
      curriculumDao = CurriculumDao(db);
    });

    tearDown(() async {
      if (AppDatabase.instance.isOpen) {
        await AppDatabase.instance.close();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. checkPackNeedsImport returns true when pack has lessons but 0 segments', () async {
      final pack = AppStartupNotifier.mandatoryPacks[0]; // hsk1_pack_v1, curr_hsk1
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // Insert bundled pack record
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': pack.packId,
        'title': pack.title,
        'version': '1.0.0',
        'hsk_level': 1,
        'status': 'bundled',
        'is_bundled': 1,
        'installed_at': nowUtc,
        'updated_at': nowUtc,
      });

      // Insert curriculum & unit
      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': pack.curriculumId,
        'pack_id': pack.packId,
        'code': 'HSK_2012_L1',
        'standard_name': 'HSK 2012 Level 1',
        'hsk_level': 1,
        'total_units': 1,
        'total_lessons': 1,
        'created_at': nowUtc,
      });

      await db.insert(DatabaseConstants.tableCurriculumUnits, {
        'id': 'unit_test_1',
        'curriculum_id': pack.curriculumId,
        'order_index': 1,
        'title_vi': 'Bài mở đầu',
        'title_zh': '入门',
        'created_at': nowUtc,
      });

      // Insert lesson without any segments
      await db.insert(DatabaseConstants.tableCurriculumLessons, {
        'id': 'lesson_test_1',
        'unit_id': 'unit_test_1',
        'order_index': 1,
        'title_vi': 'Chào hỏi',
        'title_zh': '问好',
        'pinyin': 'wèn hǎo',
        'status': 'available',
        'created_at': nowUtc,
      });

      // Segment count is 0. checkPackNeedsImport MUST return true to trigger repair
      final needsImport = await AppStartupNotifier.checkPackNeedsImport(db, pack);
      expect(needsImport, isTrue, reason: 'Pack with 0 segments must trigger re-import to repair missing data');

      // Now insert a segment for this lesson
      await db.insert(DatabaseConstants.tableLessonSegments, {
        'id': 'seg_test_1',
        'lesson_id': 'lesson_test_1',
        'step_order': 1,
        'segment_type': 'vocabulary',
        'title': 'Từ vựng 1',
        'content_ref_id': 'ci_001',
        'created_at': nowUtc,
      });

      // With segments present, checkPackNeedsImport should return false
      final needsImportAfterSegments = await AppStartupNotifier.checkPackNeedsImport(db, pack);
      expect(needsImportAfterSegments, isFalse, reason: 'Pack with lessons and segments should not re-import');
    });

    test('2. verifyDataIntegrity fails when curriculum has lessons but missing segments (< 90)', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // Content packs for HSK 1 and 2
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'hsk1_pack_v1',
        'title': 'HSK 1',
        'version': '1.0.0',
        'hsk_level': 1,
        'status': 'bundled',
        'is_bundled': 1,
        'updated_at': nowUtc,
      });
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'hsk2_pack_v1',
        'title': 'HSK 2',
        'version': '1.0.0',
        'hsk_level': 2,
        'status': 'bundled',
        'is_bundled': 1,
        'updated_at': nowUtc,
      });

      // Seed curr_hsk1 with 15 lessons but 0 segments
      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_hsk1',
        'pack_id': 'hsk1_pack_v1',
        'code': 'HSK_1',
        'standard_name': 'HSK Level 1',
        'hsk_level': 1,
        'total_units': 1,
        'total_lessons': 15,
        'created_at': nowUtc,
      });
      await db.insert(DatabaseConstants.tableCurriculumUnits, {
        'id': 'unit_hsk1_1',
        'curriculum_id': 'curr_hsk1',
        'order_index': 1,
        'title_vi': 'Unit 1',
        'title_zh': '单元 1',
        'created_at': nowUtc,
      });
      for (int i = 1; i <= 15; i++) {
        await db.insert(DatabaseConstants.tableCurriculumLessons, {
          'id': 'lesson_hsk1_$i',
          'unit_id': 'unit_hsk1_1',
          'order_index': i,
          'title_vi': 'Lesson $i',
          'title_zh': '第 $i 课',
          'pinyin': 'dì $i kè',
          'status': 'available',
          'created_at': nowUtc,
        });
      }

      // Seed curr_hsk2 with 15 lessons and 0 segments
      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_hsk2',
        'pack_id': 'hsk2_pack_v1',
        'code': 'HSK_2',
        'standard_name': 'HSK Level 2',
        'hsk_level': 2,
        'total_units': 1,
        'total_lessons': 15,
        'created_at': nowUtc,
      });
      await db.insert(DatabaseConstants.tableCurriculumUnits, {
        'id': 'unit_hsk2_1',
        'curriculum_id': 'curr_hsk2',
        'order_index': 1,
        'title_vi': 'Unit 1',
        'title_zh': '单元 1',
        'created_at': nowUtc,
      });
      for (int i = 1; i <= 15; i++) {
        await db.insert(DatabaseConstants.tableCurriculumLessons, {
          'id': 'lesson_hsk2_$i',
          'unit_id': 'unit_hsk2_1',
          'order_index': i,
          'title_vi': 'Lesson $i',
          'title_zh': '第 $i 课',
          'pinyin': 'dì $i kè',
          'status': 'available',
          'created_at': nowUtc,
        });
      }

      // Seed a content item
      await db.insert(DatabaseConstants.tableContentItems, {
        'id': 'item_001',
        'content_id': 'ci_001',
        'curriculum_id': 'curr_hsk1',
        'hsk_level': 1,
        'knowledge_type': 'vocabulary',
        'title': 'Test Item',
        'content_json': '{"text":"test"}',
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      // verifyDataIntegrity must throw StateError because segments count is 0 (< 90)
      expect(
        () => AppStartupNotifier.verifyDataIntegrity(db),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('segments'),
        )),
      );
    });

    test('3. CurriculumDao.getSegmentsByLessonId joins content_items case-insensitively with trimmed refs', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // Insert content pack, curriculum, unit, lesson
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'pack_join_test',
        'title': 'Pack Test',
        'version': '1.0.0',
        'hsk_level': 1,
        'status': 'bundled',
        'is_bundled': 1,
        'updated_at': nowUtc,
      });
      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_test',
        'pack_id': 'pack_join_test',
        'code': 'HSK_TEST',
        'standard_name': 'Standard Test',
        'hsk_level': 1,
        'total_units': 1,
        'total_lessons': 1,
        'created_at': nowUtc,
      });
      await db.insert(DatabaseConstants.tableCurriculumUnits, {
        'id': 'unit_join_test',
        'curriculum_id': 'curr_test',
        'order_index': 1,
        'title_vi': 'Unit Join Test',
        'title_zh': '单元测试',
        'created_at': nowUtc,
      });
      await db.insert(DatabaseConstants.tableCurriculumLessons, {
        'id': 'lesson_join_test',
        'unit_id': 'unit_join_test',
        'order_index': 1,
        'title_vi': 'Lesson Join Test',
        'title_zh': '课程测试',
        'pinyin': 'kè chéng cè shì',
        'status': 'available',
        'created_at': nowUtc,
      });

      // Insert target content items with UPPERCASE or normal IDs
      await db.insert(DatabaseConstants.tableContentItems, {
        'id': 'ci_row_1',
        'content_id': 'CI_VOCAB_APPLE',
        'curriculum_id': 'curr_test',
        'knowledge_type': 'vocabulary',
        'hsk_level': 1,
        'title': 'Apple',
        'content_json': '{"word":"苹果","pinyin":"píngguǒ"}',
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      await db.insert(DatabaseConstants.tableContentItems, {
        'id': 'ci_row_2',
        'content_id': 'ci_grammar_le',
        'curriculum_id': 'curr_test',
        'knowledge_type': 'grammar',
        'hsk_level': 1,
        'title': 'Grammar Le',
        'content_json': '{"structure":"verb + 了"}',
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      // Insert segments with varying case and whitespace
      // 1. Lowercase ref for UPPERCASE content_id
      await db.insert(DatabaseConstants.tableLessonSegments, {
        'id': 'seg_casing_1',
        'lesson_id': 'lesson_join_test',
        'step_order': 1,
        'segment_type': 'vocabulary',
        'title': 'Từ vựng Quả táo',
        'content_ref_id': 'ci_vocab_apple',
        'created_at': nowUtc,
      });

      // 2. Whitespace padded + uppercase ref for lowercase content_id
      await db.insert(DatabaseConstants.tableLessonSegments, {
        'id': 'seg_casing_2',
        'lesson_id': 'lesson_join_test',
        'step_order': 2,
        'segment_type': 'grammar',
        'title': 'Ngữ pháp Trợ từ ngữ khí',
        'content_ref_id': '  CI_GRAMMAR_LE   ',
        'created_at': nowUtc,
      });

      // 3. Segment with null content_ref_id (should not crash and payload should be null)
      await db.insert(DatabaseConstants.tableLessonSegments, {
        'id': 'seg_casing_3',
        'lesson_id': 'lesson_join_test',
        'step_order': 3,
        'segment_type': 'intro',
        'title': 'Phần giới thiệu',
        'content_ref_id': null,
        'created_at': nowUtc,
      });

      final segments = await curriculumDao.getSegmentsByLessonId('lesson_join_test');
      expect(segments.length, equals(3));

      // Segment 1: matched case-insensitively
      expect(segments[0]['id'], equals('seg_casing_1'));
      expect(segments[0]['content_payload'], isNotNull);
      expect(segments[0]['content_payload'], contains('苹果'));

      // Segment 2: matched with trimmed + uppercase
      expect(segments[1]['id'], equals('seg_casing_2'));
      expect(segments[1]['content_payload'], isNotNull);
      expect(segments[1]['content_payload'], contains('verb + 了'));

      // Segment 3: null ref stays null payload
      expect(segments[2]['id'], equals('seg_casing_3'));
      expect(segments[2]['content_payload'], isNull);
    });
  });
}
