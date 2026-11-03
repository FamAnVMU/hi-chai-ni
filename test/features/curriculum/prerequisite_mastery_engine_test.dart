import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/features/curriculum/data/content_pack_loader.dart';
import 'package:hi_chinese/features/curriculum/data/curriculum_repository.dart';
import 'package:hi_chinese/features/curriculum/domain/engine/prerequisite_engine.dart';
import 'package:hi_chinese/features/curriculum/domain/engine/mastery_engine.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/data/placement_unlock_handler.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Prerequisite, Mastery & Placement Unlock Engine Tests', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;
    late CurriculumRepository repo;
    late PrerequisiteEngine prereqEngine;
    late MasteryEngine masteryEngine;
    late PlacementUnlockHandler placementHandler;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('prereq_engine_test_');
      dbPath = '${tempDir.path}/test_engine.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );

      // Install HSK 1 Pack
      final packFile = File('assets/data/content_packs/hsk1/hsk1_pack_v1.json');
      final rawJson = await packFile.readAsString();
      final loader = ContentPackLoader(db);
      await loader.loadPackFromJson(rawJson);

      repo = CurriculumRepository(db);
      prereqEngine = PrerequisiteEngine(db);
      masteryEngine = MasteryEngine(db);
      placementHandler = PlacementUnlockHandler(db);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Lesson 1 is unlocked by default; Lesson 2 is locked until Lesson 1 completed with >= 80%', () async {
      // Check lesson 1
      final l1Status = await prereqEngine.evaluateUnlockStatus('lesson_1_1');
      expect(l1Status.isUnlocked, isTrue);

      // Check lesson 2 (should be locked)
      final l2StatusBefore = await prereqEngine.evaluateUnlockStatus('lesson_1_2');
      expect(l2StatusBefore.isUnlocked, isFalse);
      expect(l2StatusBefore.lockedReason, contains('lesson_1_1'));

      // Attempt lesson 1 with failing score 0.65 (65%)
      final rFail = await masteryEngine.recordLessonAttempt(
        lessonId: 'lesson_1_1',
        scorePercent: 0.65,
      );
      expect(rFail.isPassed, isFalse);
      expect(rFail.masteryState, 'in_progress');

      // Lesson 2 remains locked
      final l2StatusAfterFail = await prereqEngine.evaluateUnlockStatus('lesson_1_2');
      expect(l2StatusAfterFail.isUnlocked, isFalse);

      // Retake lesson 1 with passing score 0.85 (85%)
      final rPass = await masteryEngine.recordLessonAttempt(
        lessonId: 'lesson_1_1',
        scorePercent: 0.85,
      );
      expect(rPass.isPassed, isTrue);
      expect(rPass.masteryState, 'completed');

      // Now lesson 2 must be unlocked!
      final l2StatusAfterPass = await prereqEngine.evaluateUnlockStatus('lesson_1_2');
      expect(l2StatusAfterPass.isUnlocked, isTrue);

      // Verify DB lesson record updated
      final l2Db = await repo.getLessonById('lesson_1_2');
      expect(l2Db!.isLocked, isFalse);
    });

    test('2. Placement Test placement into Lesson 6 auto-credits Lessons 1-5 and unlocks Lesson 6', () async {
      // Initially, Lesson 6 is locked
      final l6Initial = await prereqEngine.evaluateUnlockStatus('lesson_1_6');
      expect(l6Initial.isUnlocked, isFalse);

      // Run Placement Auto-Credit up to Lesson 6 (order 6)
      final creditedCount = await placementHandler.creditLessonsUpToLevel(
        hskLevel: 1,
        targetLessonOrder: 6,
      );

      // Lessons 1 through 5 (5 lessons) must be credited
      expect(creditedCount, 5);

      // Verify Lessons 1..5 marked completed with credited_by_placement_test reason
      for (int i = 1; i <= 5; i++) {
        final lesson = await repo.getLessonById('lesson_1_$i');
        expect(lesson!.isLocked, isFalse);
        expect(lesson.creditedReason, 'credited_by_placement_test');
      }

      // Lesson 6 is now unlocked and ready for study
      final l6After = await prereqEngine.evaluateUnlockStatus('lesson_1_6');
      expect(l6After.isUnlocked, isTrue);

      // Lesson 7 remains locked!
      final l7After = await prereqEngine.evaluateUnlockStatus('lesson_1_7');
      expect(l7After.isUnlocked, isFalse);
    });

    test('3. Weak knowledge detection identifies lessons needing review for SRS recommendations', () async {
      // Score 0.60 on lesson 1
      await masteryEngine.recordLessonAttempt(lessonId: 'lesson_1_1', scorePercent: 0.60);

      final weakItems = await masteryEngine.getWeakLessons(threshold: 0.70);
      expect(weakItems.length, 1);
      expect(weakItems.first['item_id'], 'lesson_1_1');
    });

    test('4. PlacementUnlockHandler.unlockForRecommendedLevel unlocks target level and credits prior levels', () async {
      // Learner tests into HSK 1 with starting lesson 3
      final credited = await placementHandler.unlockForRecommendedLevel(1, startingLessonOrder: 3);
      expect(credited, 2); // Lessons 1 and 2 credited

      final l1 = await repo.getLessonById('lesson_1_1');
      final l2 = await repo.getLessonById('lesson_1_2');
      final l3 = await repo.getLessonById('lesson_1_3');
      final l4 = await repo.getLessonById('lesson_1_4');

      expect(l1!.status, LessonStatus.completed);
      expect(l1.creditedReason, 'credited_by_placement_test');
      expect(l2!.status, LessonStatus.completed);
      expect(l2.creditedReason, 'credited_by_placement_test');

      // Lesson 3 is unlocked and not started
      expect(l3!.isLocked, isFalse);
      expect(l3.status, LessonStatus.notStarted);

      // Lesson 4 remains locked
      expect(l4!.isLocked, isTrue);
    });
  });
}
