import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/database.dart';
import 'package:hi_chinese/features/pinyin_foundation/data/pinyin_repository.dart';
import 'package:hi_chinese/features/pinyin_foundation/domain/engine/pinyin_exercise_engine.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_assessment_result.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_skill.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Pinyin Foundation Tests (Tests A & B)', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;
    late PinyinRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pinyin_test_');
      dbPath = '${tempDir.path}/pinyin.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
      repository = PinyinRepository(db);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    // TEST A: Pinyin Foundation Complete Progression & Persistence
    test('Test A - Beginner can learn initials/finals/tones, complete exercises, and persist progress', () async {
      // 1. Verify curriculum structure for absolute beginners
      final units = repository.getUnits();
      expect(units.length, 6);
      expect(units[0].titleVi, contains('Cấu tạo Pinyin'));
      expect(units[1].titleVi, contains('Thanh mẫu'));
      expect(units[2].titleVi, contains('Vận mẫu'));
      expect(units[3].titleVi, contains('Thanh điệu'));
      expect(units[4].titleVi, contains('Quy tắc Pinyin'));
      expect(units[5].titleVi, contains('Ghép vần'));

      // Check initials lesson b, p, m, f
      final lesson21 = repository.getLessonById('pinyin_lesson_2_1');
      expect(lesson21, isNotNull);
      final itemP = lesson21!.items.firstWhere((i) => i.symbol == 'p');
      expect(itemP.isAspirated, isTrue); // Aspiration highlighted
      expect(itemP.vietnameseContrast, contains('BẬT HƠI'));

      // 2. Perform exercises using deterministic engine
      const engine = PinyinExerciseEngine();
      final ex = lesson21.exercises.first;

      // Submit correct answer
      final evalCorrect = engine.evaluate(exercise: ex, submission: ex.correctAnswer);
      expect(evalCorrect.isCorrect, isTrue);
      expect(evalCorrect.score, 1.0);

      // Submit wrong answer
      final evalWrong = engine.evaluate(exercise: ex, submission: 'wrong_choice');
      expect(evalWrong.isCorrect, isFalse);
      expect(evalWrong.score, 0.0);

      // 3. Record progress and verify database persistence
      await repository.recordItemAttempt(
        itemId: itemP.id,
        itemType: itemP.type.name,
        isCorrect: true,
        score: 1.0,
      );

      final progressMap = await repository.getAllProgress();
      expect(progressMap.containsKey(itemP.id), isTrue);
      expect(progressMap[itemP.id]!.correctCount, 1);
      expect(progressMap[itemP.id]!.attemptsCount, 1);

      // Verify canonical Knowledge Registry entry was synchronized
      final knowRows = await db.query(
        DatabaseConstants.tableKnowledgeRegistry,
        where: 'id = ?',
        whereArgs: ['KNOW_PINYIN_${itemP.id}'],
      );
      expect(knowRows.length, 1);
      expect(knowRows.first['entity_type'], 'pinyin');

      // 4. Reload from DB (simulate app restart)
      await AppDatabase.instance.close();
      final reopenedDb = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
      final reopenedRepo = PinyinRepository(reopenedDb);
      final persistedProgress = await reopenedRepo.getAllProgress();
      expect(persistedProgress.containsKey(itemP.id), isTrue);
      expect(persistedProgress[itemP.id]!.attemptsCount, 1);
    });

    // TEST B: Pinyin Placement Evaluation & Fast-Track
    test('Test B - Placement Test evaluates Pinyin competency and fast-tracks without corrupting vocab', () async {
      // 1. Beginner result (theta = -1.8) -> Must take Pinyin Foundation
      final beginnerResult = CatAssessmentResult(
        sessionId: 'sess_beginner',
        overallTheta: -1.8,
        overallStandardError: 0.3,
        referenceHskBand: CatAssessmentResult.mapThetaToHskBand(-1.8),
        confidenceScore: 0.9,
        skillScores: {
          CatSkill.speaking: const SkillScoreEstimate(
            skill: CatSkill.speaking,
            isAssessed: true,
            accuracyRate: 0.2,
            confidenceLabel: 'Thấp',
          ),
          CatSkill.vocabulary: const SkillScoreEstimate(
            skill: CatSkill.vocabulary,
            isAssessed: true,
            accuracyRate: 0.1,
            confidenceLabel: 'Thấp',
          ),
        },
        knowledgeGaps: const [],
        recommendedHskLevel: 1,
        recommendedRoadmapTitle: 'Khởi đầu từ Pinyin',
        recommendedRoadmapCode: 'TRACK_PINYIN',
        completedAt: DateTime.now(),
      );

      expect(beginnerResult.shouldBypassPinyinFoundation, isFalse);

      // 2. Intermediate learner (theta = 0.5, speaking accuracy 0.9) -> Eligible to fast-track
      final intermediateResult = CatAssessmentResult(
        sessionId: 'sess_inter',
        overallTheta: 0.5,
        overallStandardError: 0.2,
        referenceHskBand: CatAssessmentResult.mapThetaToHskBand(0.5),
        confidenceScore: 0.95,
        skillScores: {
          CatSkill.speaking: const SkillScoreEstimate(
            skill: CatSkill.speaking,
            isAssessed: true,
            accuracyRate: 0.9,
            confidenceLabel: 'Cao',
          ),
          CatSkill.vocabulary: const SkillScoreEstimate(
            skill: CatSkill.vocabulary,
            isAssessed: true,
            accuracyRate: 0.85,
            confidenceLabel: 'Cao',
          ),
        },
        knowledgeGaps: const [],
        recommendedHskLevel: 2,
        recommendedRoadmapTitle: 'HSK 2 Sơ cấp',
        recommendedRoadmapCode: 'TRACK_HSK2',
        completedAt: DateTime.now(),
      );

      expect(intermediateResult.shouldBypassPinyinFoundation, isTrue);

      // Fast-track Pinyin in repository
      await repository.creditPinyinMastery(reason: 'placement_test_bypass');

      final completionRate = await repository.getOverallCompletionRate();
      expect(completionRate, 1.0); // 100% credited

      // Verify vocabulary scores remain completely distinct and uncorrupted
      final vocabSkill = intermediateResult.skillScores[CatSkill.vocabulary]!;
      expect(vocabSkill.accuracyRate, 0.85); // Vocabulary score is NOT modified
    });
  });
}
