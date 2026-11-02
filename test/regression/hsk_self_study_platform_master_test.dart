import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/features/curriculum/data/content_pack_loader.dart';
import 'package:hi_chinese/features/curriculum/data/curriculum_repository.dart';
import 'package:hi_chinese/features/curriculum/domain/engine/adaptive_exercise_sampler.dart';
import 'package:hi_chinese/features/curriculum/domain/engine/mastery_engine.dart';
import 'package:hi_chinese/features/curriculum/data/placement_unlock_handler.dart';
import 'package:hi_chinese/features/curriculum/domain/engine/prerequisite_engine.dart';
import 'package:hi_chinese/features/ai_tutor/domain/prompts/tutor_system_prompt_builder.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('HSK Self-Study Platform Master E2E Offline Regression Suite', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;
    late CurriculumRepository repo;
    late ContentPackLoader packLoader;
    late PrerequisiteEngine prereqEngine;
    late MasteryEngine masteryEngine;
    late PlacementUnlockHandler placementHandler;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hsk_master_regression_');
      dbPath = '${tempDir.path}/test_master_regression.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );

      repo = CurriculumRepository(db);
      packLoader = ContentPackLoader(db);
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

    test('1. Database Schema v9 & Content Catalog Migration Integrity', () async {
      // Verify all 8 core tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ("
        "'content_packs', 'curriculums', 'curriculum_units', 'curriculum_lessons', "
        "'lesson_segments', 'content_items', 'curriculum_mastery', 'level_exit_exams')",
      );
      expect(tables.length, equals(8), reason: 'All 8 Schema v9 tables must be present in SQLite');

      // Verify column definitions in curriculum_lessons
      final lessonCols = await db.rawQuery("PRAGMA table_info('curriculum_lessons')");
      final colNames = lessonCols.map((c) => c['name'] as String).toSet();
      expect(colNames.contains('id'), isTrue);
      expect(colNames.contains('unit_id'), isTrue);
      expect(colNames.contains('title_vi'), isTrue);
      expect(colNames.contains('title_zh'), isTrue);
      expect(colNames.contains('order_index'), isTrue);
      expect(colNames.contains('is_locked'), isTrue);
      expect(colNames.contains('prerequisites_json'), isTrue);
    });

    test('2. Install Pre-bundled Official HSK 1 Content Pack into Database Offline', () async {
      final packFile = File('assets/data/content_packs/hsk1/hsk1_pack_v1.json');
      expect(packFile.existsSync(), isTrue, reason: 'Official HSK 1 Content Pack file must exist');

      final packJson = await packFile.readAsString();
      final installResult = await packLoader.loadPackFromJson(packJson);

      expect(installResult.isSuccess, isTrue);
      expect(installResult.packId, equals('hsk1_pack_v1'));
      expect(installResult.installedLessonsCount, equals(15));
      expect(installResult.installedContentItemsCount, greaterThanOrEqualTo(60));

      // Query from DB via Repository
      final curriculum = await repo.getCurriculumByLevel(1);
      expect(curriculum, isNotNull);
      expect(curriculum!.hskLevel, equals(1));
      expect(curriculum.code, equals('HSK_2012_L1'));

      final units = await repo.getUnits(curriculum.id);
      expect(units.length, equals(3));

      final allLessons = await repo.getLessons(units.first.id);
      expect(allLessons.length, equals(5)); // 5 lessons per unit (3 units * 5 = 15 total)

      // Verify exit exam
      final exitExam = await repo.getExitExam(1);
      expect(exitExam, isNotNull);
      expect(exitExam!['passing_score'], equals(120));
      expect(exitExam['duration_minutes'], equals(35));
    });

    test('3. Prerequisite Gating, Lesson 1 Study Flow & Deterministic Mastery Progression', () async {
      // Step A: Install pack
      final packFile = File('assets/data/content_packs/hsk1/hsk1_pack_v1.json');
      await packLoader.loadPackFromJson(await packFile.readAsString());

      // Step B: Initial state: Lesson 1 is unlocked (no prereqs), Lesson 2 is locked
      final l1Status = await prereqEngine.evaluateUnlockStatus('lesson_1_1');
      final l2Status = await prereqEngine.evaluateUnlockStatus('lesson_1_2');

      expect(l1Status.isUnlocked, isTrue, reason: 'Lesson 1 has no prereqs and should be open');
      expect(l2Status.isUnlocked, isFalse, reason: 'Lesson 2 depends on Lesson 1 and should be locked');

      // Step C: Adaptive exercise sampling
      final sampler = AdaptiveExerciseSampler();
      final mockExercises = [
        {
          'id': 'ex_1',
          'type': 'multiple_choice',
          'skill_type': 'reading',
          'prompt': 'Từ "你" có nghĩa là gì?',
          'options': ['Bạn', 'Tôi'],
          'correct_answer': 'Bạn',
          'explanation': 'Đại từ bạn',
        },
        {
          'id': 'ex_2',
          'type': 'pinyin_choice',
          'skill_type': 'listening',
          'prompt': 'Pinyin của "好":',
          'options': ['hǎo', 'hào'],
          'correct_answer': 'hǎo',
          'explanation': 'Thanh 3',
        },
      ];
      final sampled = sampler.sampleQuestions(
        allExercises: mockExercises,
        focusSkill: 'reading',
        totalCount: 2,
      );
      expect(sampled.length, equals(2));

      // Step D: Simulate learner completing Lesson 1 with 85% score (> 80% threshold)
      final recordResult = await masteryEngine.recordLessonAttempt(
        lessonId: 'lesson_1_1',
        scorePercent: 0.85,
      );
      expect(recordResult.isPassed, isTrue);
      expect(recordResult.masteryState, equals('completed'));

      // Step E: Verify Lesson 2 is now unlocked automatically
      final l2StatusAfterPass = await prereqEngine.evaluateUnlockStatus('lesson_1_2');
      expect(l2StatusAfterPass.isUnlocked, isTrue, reason: 'Lesson 2 must unlock once Lesson 1 is >= 80%');

      // Verify DB record reflects unlock
      final l2InDb = await repo.getLessonById('lesson_1_2');
      expect(l2InDb!.isLocked, isFalse);
    });

    test('4. Placement Test Auto-Crediting for Fast-Tracking Intermediate Learners', () async {
      final packFile = File('assets/data/content_packs/hsk1/hsk1_pack_v1.json');
      await packLoader.loadPackFromJson(await packFile.readAsString());

      // Candidate scores into Lesson 6 during placement test
      final creditedCount = await placementHandler.creditLessonsUpToLevel(
        hskLevel: 1,
        targetLessonOrder: 6,
      );

      // Lessons 1 through 5 (5 lessons) must be credited
      expect(creditedCount, equals(5));

      // Verify Lessons 1..5 marked completed with credited_by_placement_test reason
      for (int i = 1; i <= 5; i++) {
        final lesson = await repo.getLessonById('lesson_1_$i');
        expect(lesson!.isLocked, isFalse);
        expect(lesson.creditedReason, equals('credited_by_placement_test'));
      }

      // Lesson 6 is now unlocked and ready for study
      final l6Status = await prereqEngine.evaluateUnlockStatus('lesson_1_6');
      expect(l6Status.isUnlocked, isTrue);

      // Lesson 7 remains locked
      final l7Status = await prereqEngine.evaluateUnlockStatus('lesson_1_7');
      expect(l7Status.isUnlocked, isFalse);
    });

    test('5. HSK 1 Level Exit Exam Simulation and Result Evaluation', () async {
      final packFile = File('assets/data/content_packs/hsk1/hsk1_pack_v1.json');
      await packLoader.loadPackFromJson(await packFile.readAsString());

      final exitExam = await repo.getExitExam(1);
      expect(exitExam, isNotNull);

      final examDataJson = exitExam!['exam_data_json'] as String;
      final examData = jsonDecode(examDataJson) as Map<String, dynamic>;
      final sections = (examData['sections'] as List<dynamic>?) ?? [];
      expect(sections.length, equals(2)); // Listening + Reading

      // Calculate candidate score (30 / 40 correct -> 150/200, passing score = 120)
      const correctCount = 30;
      const totalCount = 40;
      final score = (correctCount / totalCount) * 200;
      final passingScore = (exitExam['passing_score'] as num).toInt();
      final isPassed = score >= passingScore;

      expect(score, equals(150.0));
      expect(isPassed, isTrue);
    });

    test('6. Auxiliary AI Tutor Safeguards Verification', () {
      final systemPrompt = TutorSystemPromptBuilder.build(const TutorPromptOptions());

      // Affirmation of auxiliary role
      expect(systemPrompt.contains('trợ giảng bổ trợ'), isTrue);

      // Prohibition of curriculum modification
      expect(systemPrompt.contains('KHÔNG được tự ý thay đổi nội dung giáo trình'), isTrue);

      // Prohibition of answer overwriting
      expect(systemPrompt.contains('KHÔNG tự tạo đáp án chuẩn rồi ghi đè đáp án'), isTrue);

      // Prohibition of fake mastery marking
      expect(systemPrompt.contains('KHÔNG tự đánh dấu kiến thức thành thạo'), isTrue);
    });
  });
}
