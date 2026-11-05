import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/features/curriculum/data/content_pack_loader.dart';
import 'package:hi_chinese/features/curriculum/data/curriculum_repository.dart';
import 'package:hi_chinese/features/curriculum/data/placement_unlock_handler.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/home/data/home_repository.dart';
import 'package:hi_chinese/features/vocabulary_srs/data/srs_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('T2-1: Beginner (Zero-Chinese) Onboarding & Curriculum Flow Verification', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;
    late CurriculumRepository curriculumRepo;
    late PlacementUnlockHandler placementHandler;
    late SrsRepository srsRepo;
    late HomeRepository homeRepo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('beginner_flow_test_');
      dbPath = '${tempDir.path}/test_beginner.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );

      // Install HSK 1 pack for curriculum tests
      final packFile = File('assets/data/content_packs/hsk1/hsk1_pack_v1.json');
      if (await packFile.exists()) {
        final rawJson = await packFile.readAsString();
        final loader = ContentPackLoader(db);
        await loader.loadPackFromJson(rawJson);
      }

      curriculumRepo = CurriculumRepository(db);
      placementHandler = PlacementUnlockHandler(db);
      srsRepo = SrsRepository(db);
      homeRepo = HomeRepository(db, srsRepository: srsRepo);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. CurriculumConstants.curriculumIdForLevel(0) safely maps to curr_hsk1 without throwing', () {
      expect(CurriculumConstants.curriculumIdForLevel(0), equals('curr_hsk1'));
      expect(CurriculumConstants.curriculumIdForLevel(-1), equals('curr_hsk1'));
      expect(CurriculumConstants.curriculumIdForLevel(1), equals('curr_hsk1'));
    });

    test('2. PlacementUnlockHandler.unlockForRecommendedLevel(0) unlocks HSK 1 Lesson 1 for absolute beginner', () async {
      // First lock all lessons to verify unlock action
      await db.update(DatabaseConstants.tableCurriculumLessons, {'is_locked': 1});
      await db.update(DatabaseConstants.tableCurriculumUnits, {'is_locked': 1});

      final credited = await placementHandler.unlockForRecommendedLevel(0);
      expect(credited, equals(0)); // Beginners have 0 prior lessons credited

      // Lesson 1 of Unit 1 must be unlocked and not started
      final l1 = await curriculumRepo.getLessonById('lesson_1_1');
      expect(l1, isNotNull);
      expect(l1!.isLocked, isFalse);
      expect(l1.status, equals(LessonStatus.notStarted));

      // Unit 1 must be unlocked
      final unitRows = await db.query(
        DatabaseConstants.tableCurriculumUnits,
        where: "id = 'unit_1'",
      );
      expect(unitRows.first['is_locked'], equals(0));

      // Lesson 2 must remain locked
      final l2 = await curriculumRepo.getLessonById('lesson_1_2');
      expect(l2, isNotNull);
      expect(l2!.isLocked, isTrue);
    });

    test('3. SrsRepository.getDueCardsCount returns 0 for brand new user with 0 completed lessons', () async {
      // Even if unstudied 'new' cards exist in database with due_at <= now
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        DatabaseConstants.tableSrsItems,
        {
          'id': 'SRS_VOCAB_TEMP_01',
          'content_id': 'voc_hsk1_001',
          'content_type': 'vocabulary',
          'state': 'new', // Unstudied new card
          'interval_days': 0,
          'ease_factor': 2.5,
          'repetitions': 0,
          'lapses': 0,
          'due_at': nowUtc,
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
      );

      final dueCount = await srsRepo.getDueCardsCount(hskLevel: 1, forceRefresh: true);
      expect(dueCount, equals(0), reason: 'Unstudied new cards must not be counted as due review cards');
    });

    test('4. HomeRepository.getDashboardData handles beginner (targetHskLevel: 0) cleanly', () async {
      final dashboard = await homeRepo.getDashboardData(targetHskLevel: 0);

      expect(dashboard.srsDueCount, equals(0));
      expect(dashboard.roadmap.currentHskLevel, equals(1));
      expect(dashboard.roadmap.learnedVocabCount, equals(0));
      expect(dashboard.roadmap.nextLessonTitle, equals('Bài 1: Chào hỏi & Pinyin cơ bản'));
    });
  });
}
