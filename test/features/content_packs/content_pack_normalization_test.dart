import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/database.dart';
import 'package:hi_chinese/features/content_packs/data/content_pack_manager.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Learning Content Database Normalization & Content Pack Tests (Tests A–G)', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;
    late ContentPackManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('content_pack_test_');
      dbPath = '${tempDir.path}/test_pack.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
      manager = ContentPackManager(db);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    // TEST A: Migration from Old Structure (v9 to v10 Backfill)
    test('Test A - Migration from Old Structure backfills knowledge_registry and links lessons', () async {
      // Create a test DB at version 9
      final v9Dir = await Directory.systemTemp.createTemp('v9_mig_test_');
      final v9Path = '${v9Dir.path}/v9.db';
      final v9Db = await databaseFactoryFfi.openDatabase(
        v9Path,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: (database, ver) async {
            final engine = MigrationEngine();
            await engine.executeMigrations(database, 0, 9);
          },
        ),
      );

      final now = DateTime.now().toUtc().toIso8601String();

      // Insert v9 curriculum, unit, lesson, segments, and content_items
      await v9Db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'pack_old',
        'hsk_level': 1,
        'version': '1.0.0',
        'title': 'HSK 1 Old Pack',
        'status': 'bundled',
        'updated_at': now,
      });

      await v9Db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_old',
        'pack_id': 'pack_old',
        'code': 'HSK1',
        'standard_name': 'HSK 1',
        'hsk_level': 1,
        'created_at': now,
      });

      await v9Db.insert(DatabaseConstants.tableCurriculumUnits, {
        'id': 'unit_old_1',
        'curriculum_id': 'curr_old',
        'order_index': 1,
        'title_vi': 'Unit 1',
        'title_zh': '第一单元',
        'created_at': now,
      });

      await v9Db.insert(DatabaseConstants.tableCurriculumLessons, {
        'id': 'lesson_old_1',
        'unit_id': 'unit_old_1',
        'order_index': 1,
        'title_vi': 'Lesson 1',
        'title_zh': '第一课',
        'pinyin': 'Dì yī kè',
        'created_at': now,
      });

      await v9Db.insert(DatabaseConstants.tableLessonSegments, {
        'id': 'seg_old_1',
        'lesson_id': 'lesson_old_1',
        'step_order': 1,
        'segment_type': 'vocabulary',
        'title': 'Từ vựng',
        'content_ref_id': 'VOCAB_OLD_1',
        'created_at': now,
      });

      // Insert un-normalized JSON into content_items
      await v9Db.insert(DatabaseConstants.tableContentItems, {
        'id': 'ci_VOCAB_OLD_1',
        'content_id': 'VOCAB_OLD_1',
        'curriculum_id': 'curr_old',
        'hsk_level': 1,
        'knowledge_type': 'vocabulary',
        'title': 'Từ vựng bài 1',
        'content_json': json.encode({
          'words': [
            {
              'simplified': '你',
              'pinyin': 'nǐ',
              'meaning_vi': 'bạn, anh, chị',
              'part_of_speech': 'đại từ',
              'example_sentence': '你好！',
              'audio_uri': 'assets/audio/ni.mp3',
            },
            {
              'simplified': '好',
              'pinyin': 'hǎo',
              'meaning_vi': 'tốt, đẹp',
              'part_of_speech': 'tính từ',
              'example_sentence': '很好。',
              'audio_uri': 'assets/audio/hao.mp3',
            }
          ]
        }),
        'created_at': now,
        'updated_at': now,
      });

      // Execute Migration v10
      const migV10 = MigrationV10();
      await migV10.up(v9Db);

      // Verify knowledge_registry contains canonical items
      final knowDao = KnowledgeRegistryDao(v9Db);
      final niItem = await knowDao.getKnowledgeItemById('KNOW_VOCAB_你');
      expect(niItem, isNotNull);
      expect(niItem!['canonical_id'], '你');
      expect(niItem['entity_type'], 'vocabulary');

      // Verify normalized vocabularies table has entries
      final vocabDao = VocabularyDao(v9Db);
      final vocab = await vocabDao.getVocabularyWithSenses('vocab_你');
      expect(vocab, isNotNull);
      expect(vocab!['simplified'], '你');
      expect(vocab['senses'], isNotEmpty);

      // Verify lesson_knowledge_items linked the lesson to the knowledge item
      final lessonItems = await knowDao.getKnowledgeItemsForLesson('lesson_old_1');
      expect(lessonItems.length, 2);
      expect(lessonItems.first['canonical_id'], '你');
      expect(lessonItems.first['role'], 'instruction');

      await v9Db.close();
      await v9Dir.delete(recursive: true);
    });

    // TEST B: Anti-Duplication across packs
    test('Test B - Anti-Duplication prevents duplicate knowledge entries or corrupted senses', () async {
      final pack1Json = json.encode({
        'manifest': {
          'pack_id': 'pack_base_1',
          'hsk_level': 1,
          'version': '1.0.0',
          'title': 'Pack Base 1',
        },
        'curriculum': {
          'id': 'curr_base_1',
          'units': [
            {
              'id': 'u1',
              'order_index': 1,
              'title_vi': 'U1',
              'title_zh': 'U1',
              'lessons': [
                {
                  'id': 'l1',
                  'order_index': 1,
                  'title_vi': 'L1',
                  'title_zh': 'L1',
                  'pinyin': 'L1',
                  'segments': [
                    {'id': 's1', 'step_order': 1, 'segment_type': 'vocabulary', 'title': 'V', 'content_ref_id': 'V_1'}
                  ]
                }
              ]
            }
          ]
        },
        'content_items': [
          {
            'content_id': 'V_1',
            'knowledge_type': 'vocabulary',
            'hsk_level': 1,
            'title': 'Vocab 1',
            'content_json': {
              'words': [
                {'simplified': '中国', 'pinyin': 'Zhōngguó', 'meaning_vi': 'Trung Quốc', 'part_of_speech': 'danh từ'}
              ]
            }
          }
        ]
      });

      final pack2Json = json.encode({
        'manifest': {
          'pack_id': 'pack_base_2',
          'hsk_level': 1,
          'version': '1.0.0',
          'title': 'Pack Base 2 Review',
        },
        'curriculum': {
          'id': 'curr_base_2',
          'units': [
            {
              'id': 'u2',
              'order_index': 1,
              'title_vi': 'U2',
              'title_zh': 'U2',
              'lessons': [
                {
                  'id': 'l2',
                  'order_index': 1,
                  'title_vi': 'L2',
                  'title_zh': 'L2',
                  'pinyin': 'L2',
                  'segments': [
                    {'id': 's2', 'step_order': 1, 'segment_type': 'vocabulary', 'title': 'V', 'content_ref_id': 'V_2'}
                  ]
                }
              ]
            }
          ]
        },
        'content_items': [
          {
            'content_id': 'V_2',
            'knowledge_type': 'vocabulary',
            'hsk_level': 1,
            'title': 'Vocab 2',
            'content_json': {
              'words': [
                // Re-introducing '中国' with refined sense
                {'simplified': '中国', 'pinyin': 'Zhōngguó', 'meaning_vi': 'Trung Quốc (quốc gia)', 'part_of_speech': 'danh từ'}
              ]
            }
          }
        ]
      });

      final res1 = await manager.installOrUpdatePack(pack1Json);
      expect(res1.isSuccess, isTrue);

      final res2 = await manager.installOrUpdatePack(pack2Json);
      expect(res2.isSuccess, isTrue);

      // Verify vocabularies table has exactly 1 row for '中国'
      final vocabRows = await db.query(
        DatabaseConstants.tableVocabularies,
        where: 'simplified = ?',
        whereArgs: ['中国'],
      );
      expect(vocabRows.length, 1);

      // Verify knowledge_registry has exactly 1 canonical record
      final knowRows = await db.query(
        DatabaseConstants.tableKnowledgeRegistry,
        where: 'canonical_id = ?',
        whereArgs: ['中国'],
      );
      expect(knowRows.length, 1);

      // Verify both lessons have access to it via lesson_knowledge_items
      final knowDao = KnowledgeRegistryDao(db);
      final l1Items = await knowDao.getKnowledgeItemsForLesson('l1');
      final l2Items = await knowDao.getKnowledgeItemsForLesson('l2');
      expect(l1Items.first['canonical_id'], '中国');
      expect(l2Items.first['canonical_id'], '中国');
    });

    // TEST C: Content Update with 100% Progress Preservation
    test('Test C - Content update updates syllabus and definitions while preserving user progress & SRS', () async {
      final v1Json = json.encode({
        'manifest': {
          'pack_id': 'pack_update_test',
          'hsk_level': 1,
          'version': '1.0.0',
          'title': 'HSK 1 Update Test',
        },
        'curriculum': {
          'id': 'curr_upd',
          'units': [
            {
              'id': 'u_upd_1',
              'order_index': 1,
              'title_vi': 'Unit 1',
              'title_zh': '第一单元',
              'lessons': [
                {
                  'id': 'l_upd_1',
                  'order_index': 1,
                  'title_vi': 'Lesson 1',
                  'title_zh': '第一课',
                  'pinyin': 'Dì yī kè',
                  'is_locked': false,
                  'segments': [
                    {'id': 'seg_upd_1', 'step_order': 1, 'segment_type': 'vocabulary', 'title': 'V', 'content_ref_id': 'V_UPD_1'}
                  ]
                }
              ]
            }
          ]
        },
        'content_items': [
          {
            'content_id': 'V_UPD_1',
            'knowledge_type': 'vocabulary',
            'hsk_level': 1,
            'title': 'Vocab',
            'content_json': {
              'words': [
                {'simplified': '水', 'pinyin': 'shuǐ', 'meaning_vi': 'nuoc (typo)', 'part_of_speech': 'danh từ'}
              ]
            }
          }
        ]
      });

      await manager.installOrUpdatePack(v1Json);

      final now = DateTime.now().toUtc().toIso8601String();

      // Simulate user progress on '水'
      await db.insert(DatabaseConstants.tableCurriculumMastery, {
        'id': 'mast_KNOW_VOCAB_水',
        'item_id': 'KNOW_VOCAB_水',
        'item_type': 'vocabulary',
        'mastery_state': 'mastered',
        'score': 0.95,
        'attempts_count': 5,
        'last_attempt_at': now,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'srs_KNOW_VOCAB_水',
        'content_id': 'KNOW_VOCAB_水',
        'content_type': 'vocabulary',
        'state': 'review',
        'interval_days': 7,
        'ease_factor': 2.6,
        'repetitions': 4,
        'lapses': 0,
        'due_at': '2026-11-10T00:00:00Z',
        'last_reviewed_at': now,
        'created_at': now,
        'updated_at': now,
      });

      // Update to v1.1.0 with corrected typo: 'nước'
      final v11Json = json.encode({
        'manifest': {
          'pack_id': 'pack_update_test',
          'hsk_level': 1,
          'version': '1.1.0',
          'title': 'HSK 1 Update Test (v1.1.0)',
        },
        'curriculum': {
          'id': 'curr_upd',
          'units': [
            {
              'id': 'u_upd_1',
              'order_index': 1,
              'title_vi': 'Unit 1 Revised',
              'title_zh': '第一单元 (修订)',
              'lessons': [
                {
                  'id': 'l_upd_1',
                  'order_index': 1,
                  'title_vi': 'Lesson 1',
                  'title_zh': '第一课',
                  'pinyin': 'Dì yī kè',
                  'is_locked': false,
                  'segments': [
                    {'id': 'seg_upd_1', 'step_order': 1, 'segment_type': 'vocabulary', 'title': 'V', 'content_ref_id': 'V_UPD_1'}
                  ]
                }
              ]
            }
          ]
        },
        'content_items': [
          {
            'content_id': 'V_UPD_1',
            'knowledge_type': 'vocabulary',
            'hsk_level': 1,
            'title': 'Vocab',
            'content_json': {
              'words': [
                {'simplified': '水', 'pinyin': 'shuǐ', 'meaning_vi': 'nước (chất lỏng)', 'part_of_speech': 'danh từ'}
              ]
            }
          }
        ]
      });

      final updateRes = await manager.installOrUpdatePack(v11Json);
      expect(updateRes.isSuccess, isTrue);

      // 1. Verify content definition was updated
      final vocabDao = VocabularyDao(db);
      final vocabWithSenses = await vocabDao.getVocabularyWithSenses('vocab_水');
      expect(vocabWithSenses, isNotNull);
      final senses = vocabWithSenses!['senses'] as List<dynamic>;
      expect(senses.first['meaning_vi'], 'nước (chất lỏng)');

      // 2. CRITICAL VERIFICATION: User mastery progress is 100% PRESERVED
      final masteryRow = await db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: ['KNOW_VOCAB_水'],
      );
      expect(masteryRow.length, 1);
      expect(masteryRow.first['mastery_state'], 'mastered');
      expect(masteryRow.first['score'], 0.95);
      expect(masteryRow.first['attempts_count'], 5);

      // 3. CRITICAL VERIFICATION: SRS flashcard state is 100% PRESERVED
      final srsRow = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'content_id = ?',
        whereArgs: ['KNOW_VOCAB_水'],
      );
      expect(srsRow.length, 1);
      expect(srsRow.first['interval_days'], 7);
      expect(srsRow.first['repetitions'], 4);
    });

    // TEST D: Add Knowledge Items via Update
    test('Test D - Add Knowledge items registers new items without disrupting existing items', () async {
      final initialJson = json.encode({
        'manifest': {
          'pack_id': 'pack_add_test',
          'hsk_level': 1,
          'version': '1.0.0',
          'title': 'HSK 1 Pack Add Test',
        },
        'content_items': [
          {
            'content_id': 'V_INIT',
            'knowledge_type': 'vocabulary',
            'hsk_level': 1,
            'title': 'Vocab Init',
            'content_json': {
              'words': [
                {'simplified': '大', 'pinyin': 'dà', 'meaning_vi': 'to, lớn', 'part_of_speech': 'tính từ'}
              ]
            }
          }
        ]
      });

      await manager.installOrUpdatePack(initialJson);

      final knowDao = KnowledgeRegistryDao(db);
      expect(await knowDao.getKnowledgeItemById('KNOW_VOCAB_大'), isNotNull);

      // Update that adds '小'
      final expandedJson = json.encode({
        'manifest': {
          'pack_id': 'pack_add_test',
          'hsk_level': 1,
          'version': '1.1.0',
          'title': 'HSK 1 Pack Add Test (v1.1.0)',
        },
        'content_items': [
          {
            'content_id': 'V_INIT',
            'knowledge_type': 'vocabulary',
            'hsk_level': 1,
            'title': 'Vocab Init',
            'content_json': {
              'words': [
                {'simplified': '大', 'pinyin': 'dà', 'meaning_vi': 'to, lớn', 'part_of_speech': 'tính từ'},
                {'simplified': '小', 'pinyin': 'xiǎo', 'meaning_vi': 'nhỏ, bé', 'part_of_speech': 'tính từ'}
              ]
            }
          }
        ]
      });

      final addRes = await manager.installOrUpdatePack(expandedJson);
      expect(addRes.isSuccess, isTrue);

      expect(await knowDao.getKnowledgeItemById('KNOW_VOCAB_大'), isNotNull);
      expect(await knowDao.getKnowledgeItemById('KNOW_VOCAB_小'), isNotNull);
    });

    // TEST E: Failed Update & Rollback
    test('Test E - Failed update triggers rollback leaving previous state untouched', () async {
      final goodJson = json.encode({
        'manifest': {
          'pack_id': 'pack_rollback_test',
          'hsk_level': 1,
          'version': '1.0.0',
          'title': 'Pack Before Failure',
        },
        'content_items': [
          {
            'content_id': 'V_ROLL',
            'knowledge_type': 'vocabulary',
            'hsk_level': 1,
            'title': 'Vocab Roll',
            'content_json': {
              'words': [
                {'simplified': '茶', 'pinyin': 'chá', 'meaning_vi': 'trà', 'part_of_speech': 'danh từ'}
              ]
            }
          }
        ]
      });

      final res1 = await manager.installOrUpdatePack(goodJson);
      expect(res1.isSuccess, isTrue);

      // Verify '茶' exists
      final knowDao = KnowledgeRegistryDao(db);
      expect(await knowDao.getKnowledgeItemById('KNOW_VOCAB_茶'), isNotNull);

      // Corrupted update: Checksum mismatch
      final corruptedJson = json.encode({
        'manifest': {
          'pack_id': 'pack_rollback_test',
          'hsk_level': 1,
          'version': '2.0.0',
          'title': 'Corrupted Pack',
          'sha256': '0000000000000000000000000000000000000000000000000000000000000000', // Invalid SHA
        },
        'content_items': [
          {
            'content_id': 'V_ROLL_BAD',
            'knowledge_type': 'vocabulary',
            'hsk_level': 1,
            'title': 'Vocab Bad',
            'content_json': {
              'words': [
                {'simplified': '咖啡', 'pinyin': 'kāfēi', 'meaning_vi': 'cà phê', 'part_of_speech': 'danh từ'}
              ]
            }
          }
        ]
      });

      final res2 = await manager.installOrUpdatePack(corruptedJson);
      expect(res2.isSuccess, isFalse);
      expect(res2.errorMessage, contains('SHA-256'));

      // Check state: '茶' is still present, '咖啡' was NEVER partially inserted
      expect(await knowDao.getKnowledgeItemById('KNOW_VOCAB_茶'), isNotNull);
      expect(await knowDao.getKnowledgeItemById('KNOW_VOCAB_咖啡'), isNull);

      final packRow = await db.query(
        DatabaseConstants.tableContentPacks,
        where: 'id = ?',
        whereArgs: ['pack_rollback_test'],
      );
      expect(packRow.first['version'], '1.0.0'); // Version was NOT updated
    });

    // TEST F: Package Removal
    test('Test F - Package removal enforces dependency check and preserves shared knowledge & progress', () async {
      // Pack A (Foundation)
      final packAJson = json.encode({
        'manifest': {
          'pack_id': 'pack_foundation',
          'hsk_level': 1,
          'version': '1.0.0',
          'title': 'Foundation Pack',
        },
        'curriculum': {
          'id': 'curr_fnd',
          'units': [
            {
              'id': 'u_fnd',
              'order_index': 1,
              'title_vi': 'U Fnd',
              'title_zh': 'U Fnd',
              'lessons': [
                {
                  'id': 'l_fnd',
                  'order_index': 1,
                  'title_vi': 'L Fnd',
                  'title_zh': 'L Fnd',
                  'pinyin': 'L Fnd',
                }
              ]
            }
          ]
        },
        'content_items': [
          {
            'content_id': 'V_FND',
            'knowledge_type': 'vocabulary',
            'hsk_level': 1,
            'title': 'Vocab Fnd',
            'content_json': {
              'words': [
                {'simplified': '吃', 'pinyin': 'chī', 'meaning_vi': 'ăn', 'part_of_speech': 'động từ'}
              ]
            }
          }
        ]
      });

      // Pack B (Extension depends on Foundation)
      final packBJson = json.encode({
        'manifest': {
          'pack_id': 'pack_extension',
          'hsk_level': 2,
          'version': '1.0.0',
          'title': 'Extension Pack',
          'dependencies': ['pack_foundation'],
        },
        'content_items': []
      });

      await manager.installOrUpdatePack(packAJson);
      await manager.installOrUpdatePack(packBJson);

      // Create learner mastery on '吃'
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableCurriculumMastery, {
        'id': 'mast_KNOW_VOCAB_吃',
        'item_id': 'KNOW_VOCAB_吃',
        'item_type': 'vocabulary',
        'mastery_state': 'learning',
        'score': 0.8,
        'attempts_count': 3,
        'created_at': now,
        'updated_at': now,
      });

      // Attempt uninstalling Pack A without force -> should throw dependency exception
      expect(
        () async => await manager.uninstallPack('pack_foundation'),
        throwsA(isA<ContentPackManagerException>()),
      );

      // Uninstall Pack B first
      await manager.uninstallPack('pack_extension');

      // Now uninstall Pack A
      final removed = await manager.uninstallPack('pack_foundation');
      expect(removed, isTrue);

      // Syllabus was removed
      final currRows = await db.query(DatabaseConstants.tableCurriculums, where: 'id = ?', whereArgs: ['curr_fnd']);
      expect(currRows, isEmpty);

      // But SHARED knowledge '吃' and learner mastery are PRESERVED!
      final knowDao = KnowledgeRegistryDao(db);
      expect(await knowDao.getKnowledgeItemById('KNOW_VOCAB_吃'), isNotNull);

      final mastery = await db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: ['KNOW_VOCAB_吃'],
      );
      expect(mastery, isNotEmpty);
      expect(mastery.first['score'], 0.8);
    });

    // TEST G: Offline Operation
    test('Test G - All curriculum queries and knowledge lookups operate 100% offline via local SQLite', () async {
      final offlinePackJson = json.encode({
        'manifest': {
          'pack_id': 'pack_offline',
          'hsk_level': 1,
          'version': '1.0.0',
          'title': 'Offline Study Pack',
        },
        'curriculum': {
          'id': 'curr_offline',
          'units': [
            {
              'id': 'u_off_1',
              'order_index': 1,
              'title_vi': 'Chương 1',
              'title_zh': '第一章',
              'lessons': [
                {
                  'id': 'l_off_1',
                  'order_index': 1,
                  'title_vi': 'Bài 1: Chào hỏi',
                  'title_zh': '第一课：问候',
                  'pinyin': 'Dì yī kè: Wènhòu',
                  'segments': [
                    {'id': 'seg_off_1', 'step_order': 1, 'segment_type': 'vocabulary', 'title': 'Từ vựng', 'content_ref_id': 'VOCAB_OFF_1'}
                  ]
                }
              ]
            }
          ]
        },
        'content_items': [
          {
            'content_id': 'VOCAB_OFF_1',
            'knowledge_type': 'vocabulary',
            'hsk_level': 1,
            'title': 'Từ vựng Offline',
            'content_json': {
              'words': [
                {'simplified': '喝', 'pinyin': 'hē', 'meaning_vi': 'uống', 'part_of_speech': 'động từ'}
              ]
            }
          }
        ]
      });

      await manager.installOrUpdatePack(offlinePackJson);

      // Query syllabus offline
      final currDao = CurriculumDao(db);
      final units = await currDao.getUnitsByCurriculumId('curr_offline');
      expect(units.length, 1);
      final lessons = await currDao.getLessonsByUnitId(units.first['id'] as String);
      expect(lessons.length, 1);

      // Query knowledge items for lesson offline
      final knowDao = KnowledgeRegistryDao(db);
      final lessonKnowledge = await knowDao.getKnowledgeItemsForLesson(lessons.first['id'] as String);
      expect(lessonKnowledge.length, 1);
      expect(lessonKnowledge.first['canonical_id'], '喝');
    });
  });
}
