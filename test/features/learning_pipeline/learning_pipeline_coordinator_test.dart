import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/learning_pipeline/learning_pipeline.dart';
import 'package:hi_chinese/features/practice/domain/models/practice_models.dart';
import 'package:hi_chinese/features/vocabulary_srs/domain/sm2_engine.dart';
import 'package:hi_chinese/features/vocabulary_srs/domain/srs_models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MasteryEvaluator Pure Cognitive State Tests', () {
    const evaluator = MasteryEvaluator();
    final now = DateTime.utc(2026, 11, 2, 10, 0, 0);

    test('1. Empty history defaults to unseen', () {
      final state = evaluator.evaluate(evidenceHistory: const []);
      expect(state, equals(MasteryState.unseen));
    });

    test('2. Passive exposure transitions to exposed', () {
      final evidence = [
        LearningEvidence(
          id: 'e1',
          contentId: 'VOC_NI',
          contentType: 'vocabulary',
          activityType: ActivityType.exposure,
          sourceModule: 'dialogue_reader',
          score: 1.0,
          isSuccess: true,
          createdAt: now,
        ),
      ];
      final state = evaluator.evaluate(evidenceHistory: evidence);
      expect(state, equals(MasteryState.exposed));
    });

    test('3. Direct lesson instruction transitions to learning', () {
      final evidence = [
        LearningEvidence(
          id: 'e1',
          contentId: 'VOC_NI',
          contentType: 'vocabulary',
          activityType: ActivityType.instruction,
          sourceModule: 'curriculum_lesson',
          score: 1.0,
          isSuccess: true,
          createdAt: now,
        ),
      ];
      final state = evaluator.evaluate(evidenceHistory: evidence);
      expect(state, equals(MasteryState.learning));
    });

    test('4. Failed application attempt marks state as unstable', () {
      final evidence = [
        LearningEvidence(
          id: 'e1',
          contentId: 'VOC_NI',
          contentType: 'vocabulary',
          activityType: ActivityType.instruction,
          sourceModule: 'curriculum_lesson',
          score: 1.0,
          isSuccess: true,
          createdAt: now,
        ),
        LearningEvidence(
          id: 'e2',
          contentId: 'VOC_NI',
          contentType: 'vocabulary',
          activityType: ActivityType.application,
          sourceModule: 'practice_exercise',
          score: 0.0,
          isSuccess: false,
          createdAt: now.add(const Duration(minutes: 5)),
        ),
      ];
      final state = evaluator.evaluate(evidenceHistory: evidence);
      expect(state, equals(MasteryState.unstable));
    });

    test('5. Repeated successful applications promote to familiar', () {
      final evidence = [
        LearningEvidence(
          id: 'e1',
          contentId: 'VOC_NI',
          contentType: 'vocabulary',
          activityType: ActivityType.instruction,
          sourceModule: 'curriculum_lesson',
          score: 1.0,
          isSuccess: true,
          createdAt: now,
        ),
        LearningEvidence(
          id: 'e2',
          contentId: 'VOC_NI',
          contentType: 'vocabulary',
          activityType: ActivityType.application,
          sourceModule: 'practice_exercise',
          score: 1.0,
          isSuccess: true,
          createdAt: now.add(const Duration(minutes: 5)),
        ),
        LearningEvidence(
          id: 'e3',
          contentId: 'VOC_NI',
          contentType: 'vocabulary',
          activityType: ActivityType.application,
          sourceModule: 'practice_exercise',
          score: 1.0,
          isSuccess: true,
          createdAt: now.add(const Duration(minutes: 10)),
        ),
      ];
      final state = evaluator.evaluate(evidenceHistory: evidence);
      expect(state, equals(MasteryState.familiar));
    });

    test('6. Proven spaced retention promotes to mastered', () {
      final evidence = [
        LearningEvidence(
          id: 'e1',
          contentId: 'VOC_NI',
          contentType: 'vocabulary',
          activityType: ActivityType.instruction,
          sourceModule: 'curriculum_lesson',
          score: 1.0,
          isSuccess: true,
          createdAt: now,
        ),
        LearningEvidence(
          id: 'e2',
          contentId: 'VOC_NI',
          contentType: 'vocabulary',
          activityType: ActivityType.application,
          sourceModule: 'practice_exercise',
          score: 1.0,
          isSuccess: true,
          createdAt: now.add(const Duration(minutes: 5)),
        ),
        LearningEvidence(
          id: 'e3',
          contentId: 'VOC_NI',
          contentType: 'vocabulary',
          activityType: ActivityType.retention,
          sourceModule: 'srs_flashcard',
          score: 1.0,
          isSuccess: true,
          metadata: {'new_interval': 6, 'quality': 4},
          createdAt: now.add(const Duration(days: 6)),
        ),
      ];
      final state = evaluator.evaluate(evidenceHistory: evidence);
      expect(state, equals(MasteryState.mastered));
    });
  });

  group('SrsIntakeRules Pure Domain Rules Tests', () {
    const rules = SrsIntakeRules();
    final now = DateTime.utc(2026, 11, 2, 12, 0, 0);

    test('Lesson intake schedules review for tomorrow', () {
      final decision = rules.evaluateLessonVocabIntake(
        contentId: 'VOC_HAO',
        now: now,
      );
      expect(decision.shouldEnrollOrReschedule, isTrue);
      expect(decision.targetState, equals('learning'));
      expect(decision.scheduledDueAt, equals(now.add(const Duration(days: 1))));
      expect(decision.srsItemId, equals('SRS_VOCABULARY_VOC_HAO'));
    });

    test('Failed exercise attempt schedules review immediately for today', () {
      final decision = rules.evaluateFailedAttemptIntake(
        contentId: 'VOC_HAO',
        now: now,
      );
      expect(decision.shouldEnrollOrReschedule, isTrue);
      expect(decision.targetState, equals('relearning'));
      expect(decision.scheduledDueAt, equals(now));
      expect(decision.srsItemId, equals('SRS_VOCABULARY_VOC_HAO'));
    });
  });

  group('LearningPipelineCoordinator SQLite Integration Tests', () {
    late Database db;
    late Directory tempDir;
    late LearningPipelineCoordinator coordinator;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pipeline_test_');
      final dbPath = '${tempDir.path}/test_pipeline.db';
      db = await databaseFactory.openDatabase(dbPath);

      final engine = MigrationEngine();
      await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

      coordinator = LearningPipelineCoordinator(db);

      // Pre-seed mock curriculum hierarchy
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'pack_hsk1',
        'hsk_level': 1,
        'version': '1.0.0',
        'title': 'HSK 1 Standard Pack',
        'is_bundled': 1,
        'status': 'installed',
        'updated_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_hsk1',
        'pack_id': 'pack_hsk1',
        'code': 'HSK1',
        'standard_name': 'HSK 1 Standard',
        'hsk_level': 1,
        'created_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableCurriculumUnits, {
        'id': 'unit_1',
        'curriculum_id': 'curr_hsk1',
        'order_index': 1,
        'title_vi': 'Unit 1: Chào hỏi',
        'title_zh': '第一单元：问候',
        'created_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableCurriculumLessons, {
        'id': 'lesson_1_1',
        'unit_id': 'unit_1',
        'order_index': 1,
        'title_vi': 'Bài 1: Xin chào',
        'title_zh': '第一课：你好',
        'pinyin': 'Nǐ hǎo',
        'status': 'in_progress',
        'is_locked': 0,
        'prerequisites_json': '[]',
        'created_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableCurriculumLessons, {
        'id': 'lesson_1_2',
        'unit_id': 'unit_1',
        'order_index': 2,
        'title_vi': 'Bài 2: Cảm ơn',
        'title_zh': '第二课：谢谢',
        'pinyin': 'Xièxie',
        'status': 'not_started',
        'is_locked': 1,
        'prerequisites_json': json.encode(['lesson_1_1']),
        'created_at': nowIso,
      });

      // Insert Vocabulary and ContentItem
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'VOC_NI',
        'hsk_level': 1,
        'simplified': '你',
        'pinyin': 'nǐ',
        'frequency_rank': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'VOC_HAO',
        'hsk_level': 1,
        'simplified': '好',
        'pinyin': 'hǎo',
        'frequency_rank': 2,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableContentItems, {
        'id': 'ci_nihao',
        'content_id': 'CONTENT_NIHAO',
        'curriculum_id': 'curr_hsk1',
        'hsk_level': 1,
        'knowledge_type': 'vocabulary',
        'title': 'Từ vựng xin chào',
        'content_json': json.encode({
          'words': [
            {'simplified': '你', 'pinyin': 'nǐ'},
            {'simplified': '好', 'pinyin': 'hǎo'},
          ]
        }),
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableLessonSegments, {
        'id': 'seg_1',
        'lesson_id': 'lesson_1_1',
        'step_order': 1,
        'segment_type': 'vocabulary',
        'content_ref_id': 'CONTENT_NIHAO',
        'title': 'Key Vocabulary',
        'created_at': nowIso,
      });
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Record lesson completion synchronizes status, evidence, mastery, and SRS intake', () async {
      final result = await coordinator.recordLessonCompletion(
        lessonId: 'lesson_1_1',
        scorePercent: 0.95,
        questionResults: [
          {'target_word': '你', 'is_correct': true, 'score': 1.0},
          {'target_word': '好', 'is_correct': false, 'score': 0.0},
        ],
      );

      expect(result.isPassed, isTrue);
      expect(result.unlockedLessonIds, contains('lesson_1_2'));

      // Check lesson status updated to completed
      final lessonRow = await db.query(
        DatabaseConstants.tableCurriculumLessons,
        where: 'id = ?',
        whereArgs: ['lesson_1_1'],
      );
      expect(lessonRow.first['status'], equals('completed'));

      // Check downstream lesson unlocked
      final downstreamRow = await db.query(
        DatabaseConstants.tableCurriculumLessons,
        where: 'id = ?',
        whereArgs: ['lesson_1_2'],
      );
      expect(downstreamRow.first['is_locked'], equals(0));

      // Check evidence recorded
      final evidenceRows = await db.query(DatabaseConstants.tableLearnerEvidence);
      expect(evidenceRows.length, greaterThanOrEqualTo(3)); // 2 instruction + 2 question attempts

      // Check mastery for '你' (passed question) is learning or higher
      final niMastery = await db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: ['VOC_NI'],
      );
      expect(niMastery, isNotEmpty);
      expect(niMastery.first['mastery_state'], isIn(['learning', 'familiar']));

      // Check mastery for '好' (failed question) is unstable
      final haoMastery = await db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: ['VOC_HAO'],
      );
      expect(haoMastery, isNotEmpty);
      expect(haoMastery.first['mastery_state'], equals('unstable'));

      // Check SRS items intake
      final srsRows = await db.query(DatabaseConstants.tableSrsItems);
      expect(srsRows.length, equals(2));

      // '好' should be due immediately (now)
      final haoSrs = srsRows.firstWhere((r) => r['content_id'] == 'VOC_HAO');
      final dueAtHao = DateTime.parse(haoSrs['due_at'] as String);
      expect(dueAtHao.difference(DateTime.now().toUtc()).inMinutes.abs(), lessThan(5));
    });

    test('2. Interactive exercise attempt updates mastery and handles failure reinforcement', () async {
      final now = DateTime.now().toUtc();
      final exercise = ExerciseDefinition(
        id: 'ex_test_ni',
        type: ExerciseType.multipleChoice,
        skill: 'vocabulary',
        prompt: 'Select meaning of 你',
        stimulus: '你',
        explanationVi: 'Giải thích',
        createdAt: now,
        updatedAt: now,
      );

      // 1. First attempt: correct
      final attempt1 = ExerciseAttempt(
        id: 'att_1',
        sessionId: 'sess_1',
        exerciseId: 'ex_test_ni',
        answer: const ExerciseAnswer(exerciseId: 'ex_test_ni', selectedOptionIndex: 0),
        result: const ScoringResult(
          isCorrect: true,
          score: 1.0,
          confidence: 1.0,
          feedbackVi: 'Chính xác!',
        ),
        durationMs: 1200,
        createdAt: now,
      );

      await coordinator.recordExerciseAttempt(
        sessionId: 'sess_1',
        attempt: attempt1,
        exercise: exercise,
      );

      // Verify evidence recorded
      final ev1 = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'content_id = ?',
        whereArgs: ['VOC_NI'],
      );
      expect(ev1, isNotEmpty);

      // 2. Second attempt in a subsequent session: failed
      final attempt2 = ExerciseAttempt(
        id: 'att_2',
        sessionId: 'sess_2',
        exerciseId: 'ex_test_ni',
        answer: const ExerciseAnswer(exerciseId: 'ex_test_ni', selectedOptionIndex: 1),
        result: const ScoringResult(
          isCorrect: false,
          score: 0.0,
          confidence: 1.0,
          feedbackVi: 'Chưa chính xác!',
        ),
        durationMs: 1800,
        createdAt: now.add(const Duration(seconds: 10)),
      );

      await coordinator.recordExerciseAttempt(
        sessionId: 'sess_2',
        attempt: attempt2,
        exercise: exercise,
      );

      // Verify mastery state became 'unstable'
      final masteryRow = await db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: ['VOC_NI'],
      );
      expect(masteryRow.first['mastery_state'], equals('unstable'));

      // Verify SRS intake item is created and due immediately
      final srsRow = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'content_id = ?',
        whereArgs: ['VOC_NI'],
      );
      expect(srsRow, isNotEmpty);
      final dueAt = DateTime.parse(srsRow.first['due_at'] as String);
      expect(dueAt.difference(now).inMinutes.abs(), lessThan(5));
    });

    test('3. SRS review promotes mastery to mastered upon proven retention', () async {
      final now = DateTime.now().toUtc();
      const sm2 = Sm2Engine();
      final cardState = SrsCardState.newCard(
        id: 'SRS_VOCABULARY_VOC_NI',
        contentId: 'VOC_NI',
      );

      // First successful application evidence
      await db.insert(DatabaseConstants.tableLearnerEvidence, {
        'id': 'evi_prior_app',
        'content_id': 'VOC_NI',
        'content_type': 'vocabulary',
        'source': 'practice',
        'score': 1.0,
        'duration_ms': 1000,
        'metadata_json': json.encode({
          'activity_type': ActivityType.application.value,
          'is_success': true,
        }),
        'created_at': now.subtract(const Duration(days: 6)).toIso8601String(),
      });

      // Compute SM-2 review result with Good rating
      final reviewResult = sm2.calculateNextState(
        currentState: cardState.copyWith(intervalDays: 5, repetitions: 2),
        rating: SrsRating.good,
        reviewTime: now,
      );

      await coordinator.recordSrsReview(
        reviewResult: reviewResult,
        contentId: 'VOC_NI',
        contentType: 'vocabulary',
      );

      // Verify mastery transitioned to 'mastered'
      final masteryRow = await db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: ['VOC_NI'],
      );
      expect(masteryRow, isNotEmpty);
      expect(masteryRow.first['mastery_state'], equals(MasteryState.mastered.value));
    });

    test('4. Idempotency prevents duplicate attempts on repeated submits', () async {
      final now = DateTime.now().toUtc();
      final exercise = ExerciseDefinition(
        id: 'ex_test_dup',
        type: ExerciseType.multipleChoice,
        skill: 'vocabulary',
        prompt: 'Select meaning of 好',
        stimulus: '好',
        explanationVi: 'Giải thích',
        createdAt: now,
        updatedAt: now,
      );

      final attempt = ExerciseAttempt(
        id: 'att_dup_1',
        sessionId: 'sess_dup',
        exerciseId: 'ex_test_dup',
        answer: const ExerciseAnswer(exerciseId: 'ex_test_dup', selectedOptionIndex: 0),
        result: const ScoringResult(
          isCorrect: true,
          score: 1.0,
          confidence: 1.0,
          feedbackVi: 'Đúng!',
        ),
        durationMs: 800,
        createdAt: now,
      );

      final res1 = await coordinator.recordExerciseAttempt(
        sessionId: 'sess_dup',
        attempt: attempt,
        exercise: exercise,
      );

      final res2 = await coordinator.recordExerciseAttempt(
        sessionId: 'sess_dup',
        attempt: attempt,
        exercise: exercise,
      );

      expect(res1.id, equals(res2.id));

      final count = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseConstants.tablePracticeAttempts} WHERE session_id = ? AND exercise_id = ?',
          ['sess_dup', 'ex_test_dup'],
        ),
      );
      expect(count, equals(1));
    });

    test('5. Aggregates mastery state summary accurately', () async {
      final summary = await coordinator.getMasterySummary();
      expect(summary, isNotNull);
      expect(summary.containsKey(MasteryState.unseen), isTrue);
      expect(summary.containsKey(MasteryState.learning), isTrue);
      expect(summary.containsKey(MasteryState.mastered), isTrue);
    });
  });
}
