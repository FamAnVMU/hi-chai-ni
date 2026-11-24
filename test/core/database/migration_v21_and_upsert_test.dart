import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationV21 Upgrade, Deduplication, Safe Upserts & FTS5 Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mig_v21_test_');
    });

    tearDown(() async {
      if (AppDatabase.instance.isOpen) {
        await AppDatabase.instance.close();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Upgrading v20 -> v21 adds columns, normalizes exams, deduplicates vocab_* & SRS, and sets up FTS5', () async {
      final dbPath = '${tempDir.path}/upgrade_v20_to_v21.db';
      final engine = MigrationEngine();
      final nowIso = DateTime.now().toUtc().toIso8601String();

      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 20,
          onConfigure: (d) async {
            await d.execute('PRAGMA foreign_keys = ON;');
          },
          onCreate: (d, ver) async {
            await engine.executeMigrations(d, 0, ver);
          },
        ),
      );

      // Seed v20 state with duplicate vocab_* + VOC_*, saved word, SRS, exit exam <= 1, and dictionary entry
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'VOC_HSK1_爱_ai',
        'simplified': '爱',
        'traditional': '愛',
        'pinyin': 'ài',
        'pinyin_clean': 'ai',
        'hsk_level': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'vocab_爱',
        'simplified': '爱',
        'traditional': '愛',
        'pinyin': 'ài',
        'hanviet': 'Ái',
        'hsk_level': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'SRS_VOC_LEGACY',
        'content_id': 'vocab_爱',
        'content_type': 'vocabulary',
        'state': 'review',
        'interval_days': 6,
        'ease_factor': 2.5,
        'repetitions': 4,
        'lapses': 0,
        'due_at': nowIso,
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'SRS_VOC_CANONICAL',
        'content_id': 'VOC_HSK1_爱_ai',
        'content_type': 'vocabulary',
        'state': 'learning',
        'interval_days': 1,
        'ease_factor': 2.5,
        'repetitions': 1,
        'lapses': 0,
        'due_at': nowIso,
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableUserSavedWords, {
        'id': 'saved_leg_ai',
        'vocabulary_id': 'vocab_爱',
        'simplified': '爱',
        'pinyin': 'ài',
        'custom_note': 'Từ rất quan trọng',
        'is_favorite': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'pack_1',
        'hsk_level': 1,
        'version': '1.0.0',
        'title': 'HSK 1',
        'updated_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_hsk1',
        'pack_id': 'pack_1',
        'code': 'HSK1',
        'standard_name': 'HSK 1',
        'hsk_level': 1,
        'created_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableLevelExitExams, {
        'id': 'exam_hsk1',
        'curriculum_id': 'curr_hsk1',
        'hsk_level': 1,
        'title': 'HSK 1 Exam',
        'passing_score': 1,
        'duration_minutes': 35,
        'exam_data_json': '{}',
        'created_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableDictionaryEntries, {
        'id': 'dict_nihao',
        'simplified': '你好',
        'traditional': '你好',
        'pinyin': 'nǐ hǎo',
        'pinyin_clean': 'nihao',
        'hanviet': 'nhĩ hảo',
        'hsk_level': 1,
        'meaning_vi': 'xin chào bạn',
        'created_at': nowIso,
      });

      await db.close();

      // Upgrade v20 -> v21
      db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: DatabaseConstants.currentDatabaseVersion,
          onConfigure: (d) async {
            await d.execute('PRAGMA foreign_keys = ON;');
          },
          onUpgrade: (d, oldVer, newVer) async {
            await engine.executeMigrations(d, oldVer, newVer);
          },
        ),
      );

      // Verify v21 columns
      final chatMsgCols = (await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableChatMessages});'))
          .map((c) => c['name'])
          .toSet();
      expect(chatMsgCols, containsAll(['evaluation_json', 'follow_up_suggestions_json']));

      final chatSessCols = (await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableChatSessions});'))
          .map((c) => c['name'])
          .toSet();
      expect(chatSessCols, contains('persona_id'));

      final profileCols = (await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableUserProfiles});'))
          .map((c) => c['name'])
          .toSet();
      expect(profileCols, contains('total_xp'));

      // Verify exit exam normalization
      final examRows = await db.query(DatabaseConstants.tableLevelExitExams, where: 'id = ?', whereArgs: ['exam_hsk1']);
      expect(examRows.first['passing_score'], equals(120));

      // Verify vocab_* merged into VOC_*
      final legacyVocab = await db.query(DatabaseConstants.tableVocabularies, where: 'id = ?', whereArgs: ['vocab_爱']);
      expect(legacyVocab, isEmpty);

      final canonicalVocab = await db.query(DatabaseConstants.tableVocabularies, where: 'id = ?', whereArgs: ['VOC_HSK1_爱_ai']);
      expect(canonicalVocab.length, equals(1));
      expect(canonicalVocab.first['hanviet'], equals('Ái'));

      // Higher-repetition SRS stats preserved & deduplicated under canonical ID
      final srsRows = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'content_id = ? AND deleted_at IS NULL',
        whereArgs: ['VOC_HSK1_爱_ai'],
      );
      expect(srsRows.length, equals(1));
      expect(srsRows.first['repetitions'], equals(4));

      // Saved word repointed and custom_note preserved
      final savedRows = await db.query(
        DatabaseConstants.tableUserSavedWords,
        where: 'vocabulary_id = ?',
        whereArgs: ['VOC_HSK1_爱_ai'],
      );
      expect(savedRows.length, equals(1));
      expect(savedRows.first['custom_note'], equals('Từ rất quan trọng'));

      // FTS5 search works
      final vocabDao = VocabularyDao(db);
      final ftsHits = await vocabDao.searchDictionaryFts('nihao');
      expect(ftsHits.length, equals(1));
      expect(ftsHits.first['simplified'], equals('你好'));

      // Partial unique index enforces no duplicate active SRS rows
      expect(
        () => db.insert(DatabaseConstants.tableSrsItems, {
          'id': 'SRS_DUP_ERR',
          'content_id': 'VOC_HSK1_爱_ai',
          'content_type': 'vocabulary',
          'state': 'new',
          'interval_days': 0,
          'ease_factor': 2.5,
          'repetitions': 0,
          'lapses': 0,
          'due_at': nowIso,
          'created_at': nowIso,
          'updated_at': nowIso,
        }),
        throwsException,
      );

      final fkIssues = await db.rawQuery('PRAGMA foreign_key_check;');
      expect(fkIssues, isEmpty);

      await db.close();
    });

    test('2. Non-destructive upserts preserve custom_note, hanviet/stroke_count, and chat_messages', () async {
      final dbPath = '${tempDir.path}/safe_upserts.db';
      final db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final vocabDao = VocabularyDao(db);
      final savedDao = UserSavedWordsDao(db);
      final chatDao = ChatDao(db);

      // Rich vocabulary + saved word with custom_note
      await vocabDao.insertVocabulary({
        'id': 'VOC_HSK1_学',
        'simplified': '学',
        'traditional': '學',
        'pinyin': 'xué',
        'pinyin_clean': 'xue',
        'hanviet': 'Học',
        'hsk_level': 1,
        'stroke_count': 8,
        'radicals': '子',
        'frequency_rank': 42,
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      await savedDao.saveWord(
        id: 'sw_1',
        vocabularyId: 'VOC_HSK1_学',
        simplified: '学',
        pinyin: 'xué',
        customNote: 'Ghi chú cá nhân',
      );

      // Re-upsert minimal dictionary representation -> must NOT erase hanviet/stroke_count or CASCADE delete custom_note!
      await vocabDao.insertMinimalVocabularyFromDictionary({
        'id': 'VOC_HSK1_学',
        'simplified': '学',
        'pinyin': 'xué',
        'meaning_vi': 'học tập',
      });
      // Save again with customNote == null -> must preserve existing customNote
      await savedDao.saveWord(
        id: 'sw_2',
        vocabularyId: 'VOC_HSK1_学',
        simplified: '学',
        pinyin: 'xué',
        customNote: null,
      );

      final vocab = await vocabDao.getVocabularyById('VOC_HSK1_学');
      expect(vocab!['hanviet'], equals('Học'));
      expect(vocab['stroke_count'], equals(8));
      expect(vocab['frequency_rank'], equals(42));

      final saved = await savedDao.getSavedWord('VOC_HSK1_学');
      expect(saved, isNotNull);
      expect(saved!['custom_note'], equals('Ghi chú cá nhân'));

      // ChatDao insertSession on existing session preserves chat_messages; deleteSession hard-deletes messages
      await chatDao.insertSession({
        'id': 'chat_1',
        'title': 'Phiên 1',
        'scenario_code': 'free_chat',
        'is_archived': 0,
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      await chatDao.insertMessage({
        'id': 'msg_1',
        'session_id': 'chat_1',
        'role': 'user',
        'content': '你好',
        'created_at': nowIso,
      });

      await chatDao.insertSession({
        'id': 'chat_1',
        'title': 'Phiên 1 (Đổi tên)',
        'scenario_code': 'free_chat',
        'is_archived': 0,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      final msgsAfterUpdate = await chatDao.getMessagesBySessionId('chat_1');
      expect(msgsAfterUpdate.length, equals(1));
      final updatedSess = await chatDao.getSessionById('chat_1');
      expect(updatedSess!['title'], equals('Phiên 1 (Đổi tên)'));

      await chatDao.deleteSession('chat_1');
      final msgsAfterDelete = await chatDao.getMessagesBySessionId('chat_1');
      expect(msgsAfterDelete, isEmpty);
    });

    test('3. SeedLoader preserves polyphones & grammar v6/v13 fields; TimezoneDataMigrator & CurriculumDao summary', () async {
      final dbPath = '${tempDir.path}/seed_tz_curr.db';
      final db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );

      final bundleJson = jsonEncode({
        'bundleName': 'polyphone_grammar_test',
        'version': 1,
        'syllabusVersion': 'HSK3.0',
        'source': 'test',
        'vocabularies': [
          {
            'id': 'VOC_XING_2',
            'simplified': '行',
            'pinyin': 'xíng',
            'pinyinClean': 'xing',
            'hskLevel': 1,
            'senses': [
              {'id': 'SNS_XING', 'partOfSpeech': 'Động từ', 'meaningVi': 'được, đi'}
            ],
          },
          {
            'id': 'VOC_HANG_2',
            'simplified': '行',
            'pinyin': 'háng',
            'pinyinClean': 'hang',
            'hskLevel': 3,
            'senses': [
              {'id': 'SNS_HANG', 'partOfSpeech': 'Danh từ', 'meaningVi': 'ngành, hàng'}
            ],
          },
        ],
        'grammarItems': [
          {
            'id': 'GRAM_T1',
            'code': 'HSK3_BA',
            'hskLevel': 3,
            'title': 'Câu chữ 把',
            'pattern': 'S + 把 + O + V + C',
            'explanationVi': 'Đưa tân ngữ lên trước động từ',
            'examples': [],
          },
        ],
      });

      final seedLoader = SeedLoader(db);
      final res = await seedLoader.seedFromJsonString(bundleJson);
      expect(res.success, isTrue);

      final knowledgeRows = await db.query(
        DatabaseConstants.tableKnowledgeRegistry,
        where: "entity_type = 'vocabulary'",
      );
      expect(knowledgeRows.length, equals(2));

      final grammarRows = await db.query(
        DatabaseConstants.tableGrammarItems,
        where: 'id = ?',
        whereArgs: ['GRAM_T1'],
      );
      expect(grammarRows.first['hsk_level_mapped'], equals(3));
      expect(grammarRows.first['title'], equals('Câu chữ 把'));
      expect(grammarRows.first['structure'], equals('S + 把 + O + V + C'));

      // TimezoneDataMigrator checks timezone_offset_minutes directly from SELECT
      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'act_tz_1',
        'activity_type': 'lesson',
        'duration_seconds': 180,
        'items_count': 5,
        'activity_date': '2026-11-24',
        'timezone_offset_minutes': 420,
        'created_at': '2026-11-24T10:00:00.000Z',
      });
      const tzMigrator = TimezoneDataMigrator();
      final report = await tzMigrator.auditHistoricalActivities(db);
      expect(report.totalRecords, equals(1));
      expect(report.recordsWithExplicitTimezone, equals(1));

      // CurriculumDao single-query summary
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'p1',
        'hsk_level': 1,
        'version': '1.0.0',
        'title': 'HSK 1',
        'updated_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_1',
        'pack_id': 'p1',
        'code': 'HSK1',
        'standard_name': 'HSK 1',
        'hsk_level': 1,
        'created_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableCurriculumUnits, {
        'id': 'u_1',
        'curriculum_id': 'curr_1',
        'order_index': 1,
        'title_vi': 'Đơn vị 1',
        'title_zh': '第一单元',
        'is_locked': 0,
        'created_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableCurriculumLessons, {
        'id': 'l_1',
        'unit_id': 'u_1',
        'order_index': 1,
        'title_vi': 'Bài 1',
        'title_zh': '第一课',
        'pinyin': 'Dì yī kè',
        'is_locked': 0,
        'status': 'completed',
        'created_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableCurriculumMastery, {
        'id': 'm_1',
        'item_id': 'l_1',
        'item_type': 'lesson',
        'mastery_state': 'completed',
        'score': 0.92,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      final currDao = CurriculumDao(db);
      final summary = await currDao.getLessonsSummaryByCurriculumId('curr_1');
      expect(summary.length, equals(1));
      expect(summary.first['lesson_id'], equals('l_1'));
      expect((summary.first['mastery_score'] as num).toDouble(), closeTo(0.92, 0.001));
    });
  });
}
