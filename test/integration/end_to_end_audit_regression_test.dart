import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/dao/activity_dao.dart';
import 'package:hi_chinese/core/database/dao/curriculum_dao.dart';
import 'package:hi_chinese/core/database/database_backup_helper.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/seed/seed_loader.dart';
import 'package:hi_chinese/core/network/ai/ai_service.dart';
import 'package:hi_chinese/core/network/ai/models/ai_model_config.dart';
import 'package:hi_chinese/core/network/ai/providers/mock_ai_provider.dart';
import 'package:hi_chinese/core/network/ai/security/ai_credential_storage.dart';
import 'package:hi_chinese/features/ai_tutor/data/repositories/ai_tutor_repository.dart';
import 'package:hi_chinese/features/ai_tutor/domain/models/tutor_persona.dart';
import 'package:hi_chinese/features/ai_tutor/domain/models/tutor_scenario.dart';
import 'package:hi_chinese/features/content_packs/data/content_pack_manager.dart';
import 'package:hi_chinese/features/curriculum/data/placement_unlock_handler.dart';
import 'package:hi_chinese/features/profile/domain/models/user_profile.dart';
import 'package:hi_chinese/features/reading/data/reading_repository.dart';
import 'package:hi_chinese/features/settings/data/services/data_management_service.dart';
import 'package:hi_chinese/features/vocabulary_srs/data/srs_repository.dart';
import 'package:hi_chinese/features/vocabulary_srs/domain/srs_models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('End-to-End Audit Regression Suite (v1.0.17 SQLite v21)', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;
    late MockAiProvider mockAiProvider;
    late AiService aiService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('e2e_audit_v21_');
      dbPath = '${tempDir.path}/e2e_hi_chinese.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );

      mockAiProvider = MockAiProvider();
      aiService = AiService(
        provider: mockAiProvider,
        credentialStorage: AiCredentialStorage.inMemory(initialApiKey: 'test-key'),
        modelRegistry: AiModelRegistry(),
      );
    });

    tearDown(() async {
      if (AppDatabase.instance.isOpen) {
        await AppDatabase.instance.close();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Startup v21 opens cleanly with FTS5 dictionary, Wave 2 columns & FK integrity', () async {
      final versionRes = await db.rawQuery('PRAGMA user_version;');
      expect(Sqflite.firstIntValue(versionRes), equals(DatabaseConstants.currentDatabaseVersion));

      expect(await DatabaseBackupHelper.checkIntegrity(db), isEmpty);
      expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);

      final ftsTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = ?;",
        [DatabaseConstants.tableDictionaryEntriesFts],
      );
      expect(ftsTables, isNotEmpty);

      final chatMsgCols = (await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableChatMessages});'))
          .map((c) => c['name'] as String)
          .toSet();
      expect(chatMsgCols, containsAll(['evaluation_json', 'follow_up_suggestions_json']));

      final chatSessionCols = (await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableChatSessions});'))
          .map((c) => c['name'] as String)
          .toSet();
      expect(chatSessionCols, contains('persona_id'));

      final profileCols = (await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableUserProfiles});'))
          .map((c) => c['name'] as String)
          .toSet();
      expect(profileCols, contains('total_xp'));
    });

    test('2. CAT Placement HSK 4 unlock + HSK 1/3/4 pack install idempotency', () async {
      final packManager = ContentPackManager(db);
      final hsk1Raw = await File('assets/data/content_packs/hsk1/hsk1_pack_v1.json').readAsString();
      final hsk3Raw = await File('assets/data/content_packs/hsk3/hsk3_pack_v1.json').readAsString();
      final hsk4Raw = await File('assets/data/content_packs/hsk4/hsk4_pack_v1.json').readAsString();

      final res1 = await packManager.installOrUpdatePack(hsk1Raw, isBundled: true);
      final res3 = await packManager.installOrUpdatePack(hsk3Raw);
      final res4 = await packManager.installOrUpdatePack(hsk4Raw);

      expect(res1.isSuccess, isTrue, reason: res1.errorMessage);
      expect(res3.isSuccess, isTrue, reason: res3.errorMessage);
      expect(res4.isSuccess, isTrue, reason: res4.errorMessage);

      final unlockHandler = PlacementUnlockHandler(db);
      final creditedCount = await unlockHandler.unlockForRecommendedLevel(4);
      expect(creditedCount, greaterThan(0));

      final curriculumDao = CurriculumDao(db);
      final hsk1Curr = await curriculumDao.getCurriculumByLevel(1);
      final hsk3Curr = await curriculumDao.getCurriculumByLevel(3);
      final hsk4Curr = await curriculumDao.getCurriculumByLevel(4);
      expect(hsk1Curr, isNotNull);
      expect(hsk3Curr, isNotNull);
      expect(hsk4Curr, isNotNull);

      final hsk1Lessons = await curriculumDao.getAllLessonsForCurriculum(hsk1Curr!['id'] as String);
      final hsk3Lessons = await curriculumDao.getAllLessonsForCurriculum(hsk3Curr!['id'] as String);
      final hsk4Lessons = await curriculumDao.getAllLessonsForCurriculum(hsk4Curr!['id'] as String);

      expect(hsk1Lessons.every((l) => l['status'] == 'completed' && l['is_locked'] == 0), isTrue);
      expect(hsk3Lessons.every((l) => l['status'] == 'completed' && l['is_locked'] == 0), isTrue);
      expect(hsk4Lessons.first['is_locked'], equals(0));

      // Re-installing HSK 4 pack must remain idempotent and keep placement progress intact.
      final reinstallRes = await packManager.installOrUpdatePack(hsk4Raw);
      expect(reinstallRes.isSuccess, isTrue);

      final hsk1After = await curriculumDao.getAllLessonsForCurriculum(hsk1Curr['id'] as String);
      expect(hsk1After.every((l) => l['status'] == 'completed'), isTrue);
    });

    test('3. Reading completion, HSK 1 SRS review cycle & activity streak persistence', () async {
      final readingRaw = await File('assets/data/graded_reading_passages.json').readAsString();
      final seedRes = await SeedLoader(db).seedGradedReadingPassages(rawJson: readingRaw);
      expect(seedRes.success, isTrue);

      final readingRepo = DefaultReadingRepository(db, aiService: aiService);
      final hsk1Passages = await readingRepo.getPassages(hskLevel: 1);
      expect(hsk1Passages, isNotEmpty);
      final passage = hsk1Passages.first;

      await readingRepo.saveReadingSession(
        passageId: passage.id,
        readingTimeSeconds: 45,
        lastScrollOffset: 120.0,
        answers: {'q1': 0},
        isCompleted: true,
        score: 100.0,
      );

      final progress = await readingRepo.getProgress(passage.id);
      expect(progress, isNotNull);
      expect(progress!.isCompleted, isTrue);
      expect(progress.score, equals(100.0));

      final nowUtc = DateTime.now().toUtc();
      final nowIso = nowUtc.toIso8601String();
      const vocabId = 'VOC_E2E_NIHAO';
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': vocabId,
        'simplified': '你好测试',
        'traditional': '你好測試',
        'pinyin': 'nǐ hǎo cèshì',
        'hsk_level': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      final srsRepo = SrsRepository(db);
      final cardState = await srsRepo.getOrCreateCardState(contentId: vocabId);
      await db.update(
        DatabaseConstants.tableSrsItems,
        {'due_at': nowUtc.subtract(const Duration(hours: 1)).toIso8601String()},
        where: 'id = ?',
        whereArgs: [cardState.id],
      );

      expect(await srsRepo.getDueCardsCount(hskLevel: 1, forceRefresh: true), equals(1));
      final dueItems = await srsRepo.getDueFlashcards(hskLevel: 1);
      expect(dueItems.length, equals(1));

      await srsRepo.recordReviewAndProgress(
        item: dueItems.first,
        rating: SrsRating.good,
        durationMs: 2500,
      );

      expect(await srsRepo.getDueCardsCount(hskLevel: 1, forceRefresh: true), equals(0));

      final activities = await db.query(DatabaseConstants.tableLearningActivities);
      expect(activities.map((a) => a['activity_type']), containsAll(['reading', 'srs_review']));
      expect(activities.every((a) => a['timezone_offset_minutes'] != null), isTrue);
      expect(await ActivityDao(db).getDistinctActiveDates(), isNotEmpty);
    });

    test('4. AI Tutor persona session, structured evaluation_json round-trip & soft delete', () async {
      mockAiProvider.customTextResponse = json.encode({
        'reply_zh': '太好了！请看菜单。',
        'reply_pinyin': 'Tài hǎo le! Qǐng kàn càidān.',
        'reply_vi': 'Tuyệt quá! Mời bạn xem thực đơn.',
        'evaluation': {
          'is_correct': true,
          'original_text': '我要点菜',
          'corrected_text': null,
          'pinyin': 'Wǒ yào diǎn cài',
          'explanation_vi': 'Câu nói tự nhiên và đúng ngữ pháp.',
          'encouragement_vi': 'Làm tốt lắm!',
        },
        'follow_up_suggestions': ['这有什么特色菜？', '请给我一杯水。'],
        'target_vocabulary': ['菜单'],
      });

      final tutorRepo = AiTutorRepositoryImpl(
        database: AppDatabase.instance,
        aiService: aiService,
      );

      final sessionId = await tutorRepo.createSession(
        title: 'Gọi món HSK 2',
        scenarioCode: TutorScenarios.restaurant.code,
        personaId: TutorPersonaId.laowang,
      );

      final activeBeforeDelete = await tutorRepo.getActiveSessions();
      expect(activeBeforeDelete.length, equals(1));
      expect(activeBeforeDelete.first['persona_id'], equals('laowang'));

      final reply = await tutorRepo.sendMessage(
        sessionId: sessionId,
        userText: '我要点菜',
        persona: TutorPersonas.laowang,
        scenario: TutorScenarios.restaurant,
      );
      expect(reply.replyZh, equals('太好了！请看菜单。'));

      final turns = await tutorRepo.getSessionTurns(sessionId);
      final assistantTurns = turns.where((t) => t.role == 'assistant').toList();
      expect(assistantTurns.last.evaluation, isNotNull);
      expect(assistantTurns.last.evaluation!.isCorrect, isTrue);
      expect(assistantTurns.last.followUpSuggestions, equals(['这有什么特色菜？', '请给我一杯水。']));

      await tutorRepo.deleteSession(sessionId);
      expect(await tutorRepo.getActiveSessions(), isEmpty);

      final sessionRows = await db.query(
        DatabaseConstants.tableChatSessions,
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      expect(sessionRows.single['deleted_at'], isNotNull);
    });

    test('5. Backup, restore & protected reset preserve seeded content while clearing user progress', () async {
      final packManager = ContentPackManager(db);
      final hsk1Raw = await File('assets/data/content_packs/hsk1/hsk1_pack_v1.json').readAsString();
      expect((await packManager.installOrUpdatePack(hsk1Raw, isBundled: true)).isSuccess, isTrue);

      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        DatabaseConstants.tableUserProfiles,
        UserProfile.defaultProfile()
            .copyWith(
              displayName: 'E2E Học Viên',
              currentHskLevel: 2,
              targetHskLevel: 4,
              dailyMinutes: 20,
            )
            .toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'act_e2e_backup',
        'activity_type': 'reading',
        'duration_seconds': 60,
        'items_count': 1,
        'activity_date': '2026-11-25',
        'created_at': nowIso,
        'timezone_offset_minutes': 420,
      });

      final service = DataManagementService(db, dbPath);
      final backupFile = await service.createBackup(customName: 'e2e_audit.hibak');
      expect(await backupFile.exists(), isTrue);

      await service.restoreBackup(backupFile);
      db = AppDatabase.instance.database;

      expect(await DatabaseBackupHelper.checkIntegrity(db), isEmpty);
      final restoredProfiles = await db.query(DatabaseConstants.tableUserProfiles);
      expect(restoredProfiles.single['display_name'], equals('E2E Học Viên'));

      await service.clearAllUserData(confirmationCode: 'RESET');

      expect(await db.query(DatabaseConstants.tableLearningActivities), isEmpty);
      expect(await db.query(DatabaseConstants.tableChatSessions), isEmpty);
      expect(await db.query(DatabaseConstants.tableSrsItems), isEmpty);
      expect(await db.query(DatabaseConstants.tableReadingProgress), isEmpty);

      final resetProfile = await db.query(DatabaseConstants.tableUserProfiles);
      expect(resetProfile.single['display_name'], isNot(equals('E2E Học Viên')));

      // Seeded curriculum and vocabulary tables remain intact after user reset.
      expect(await db.query(DatabaseConstants.tableCurriculums), isNotEmpty);
      expect(await db.query(DatabaseConstants.tableVocabularies), isNotEmpty);
    });
  });
}
