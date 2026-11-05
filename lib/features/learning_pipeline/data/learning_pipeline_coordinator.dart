import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_constants.dart';
import '../../practice/domain/models/practice_models.dart';
import '../../vocabulary_srs/domain/srs_models.dart';
import '../domain/engine/mastery_evaluator.dart';
import '../domain/engine/srs_intake_rules.dart';
import '../domain/models/learning_evidence.dart';
import '../domain/models/mastery_state.dart';

/// Outcome summary of a coordinated lesson completion pipeline run.
class LessonPipelineResult {
  final String lessonId;
  final bool isPassed;
  final double scorePercent;
  final int evidenceCount;
  final int srsEnrolledCount;
  final int srsRescheduledCount;
  final List<String> unlockedLessonIds;

  const LessonPipelineResult({
    required this.lessonId,
    required this.isPassed,
    required this.scorePercent,
    required this.evidenceCount,
    required this.srsEnrolledCount,
    required this.srsRescheduledCount,
    required this.unlockedLessonIds,
  });
}

/// Central architectural coordinator for the unified Learning Data Pipeline.
/// Guarantees atomic SQLite transactions, deterministic cognitive mastery calculations,
/// append-only evidence logging, and automated Spaced Repetition (SRS) synchronization.
class LearningPipelineCoordinator {
  final DatabaseExecutor _db;
  final MasteryEvaluator evaluator;
  final SrsIntakeRules intakeRules;

  const LearningPipelineCoordinator(
    this._db, {
    this.evaluator = const MasteryEvaluator(),
    this.intakeRules = const SrsIntakeRules(),
  });

  /// 1. Synchronously processes a completed lesson attempt:
  /// - Updates lesson completion and mastery state
  /// - Extracts vocabulary and grammar taught in the lesson
  /// - Emits immutable instruction evidence for each knowledge item
  /// - Updates knowledge items' mastery from unseen/exposed -> learning
  /// - Enrolls items into SRS for review scheduled tomorrow
  /// - Processes question-level exercise attempts, tagging weak items as 'unstable' and scheduling immediate review
  /// - Evaluates prerequisite rules to unlock downstream lessons
  Future<LessonPipelineResult> recordLessonCompletion({
    required String lessonId,
    required double scorePercent,
    List<Map<String, dynamic>>? questionResults,
    int durationMs = 0,
    double passingThreshold = 0.8,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final nowIso = nowUtc.toIso8601String();
    final isPassed = scorePercent >= passingThreshold;

    int evidenceCount = 0;
    int srsEnrolledCount = 0;
    int srsRescheduledCount = 0;
    final List<String> unlockedLessons = [];

    Future<void> runPipeline(DatabaseExecutor txn) async {
      // Step A: Update Lesson status in curriculum_lessons
      await txn.update(
        DatabaseConstants.tableCurriculumLessons,
        {
          'status': isPassed ? 'completed' : 'in_progress',
          if (isPassed) 'completed_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [lessonId],
      );

      // Step B: Upsert Lesson-level mastery in curriculum_mastery
      final existingLessonMastery = await txn.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: [lessonId],
        limit: 1,
      );
      final prevAttempts = existingLessonMastery.isNotEmpty
          ? ((existingLessonMastery.first['attempts_count'] as num?)?.toInt() ?? 0)
          : 0;

      await txn.insert(
        DatabaseConstants.tableCurriculumMastery,
        {
          'id': 'mastery_$lessonId',
          'item_id': lessonId,
          'item_type': 'lesson',
          'mastery_state': isPassed ? 'completed' : 'in_progress',
          'score': scorePercent,
          'attempts_count': prevAttempts + 1,
          'last_attempt_at': nowIso,
          'due_review_at': nowUtc.add(Duration(days: isPassed ? 3 : 1)).toIso8601String(),
          'created_at': existingLessonMastery.isNotEmpty
              ? existingLessonMastery.first['created_at']
              : nowIso,
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Step B2: Sync with tableLessonProgress (Eliminates Roadmap & Curriculum Split-Brain)
      final lessonRows = await txn.query(
        DatabaseConstants.tableCurriculumLessons,
        where: 'id = ?',
        whereArgs: [lessonId],
        limit: 1,
      );
      final unitId = lessonRows.isNotEmpty ? (lessonRows.first['unit_id'] as String? ?? 'unit_1') : 'unit_1';
      final hskLevel = lessonRows.isNotEmpty ? ((lessonRows.first['level'] as num?)?.toInt() ?? 1) : 1;

      final existingLessonProg = await txn.query(
        DatabaseConstants.tableLessonProgress,
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
        limit: 1,
      );

      await txn.insert(
        DatabaseConstants.tableLessonProgress,
        {
          'id': existingLessonProg.isNotEmpty
              ? existingLessonProg.first['id']
              : 'prog_${lessonId}_${nowUtc.millisecondsSinceEpoch}',
          'lesson_id': lessonId,
          'unit_id': unitId,
          'hsk_level': hskLevel,
          'status': isPassed ? 'completed' : 'inProgress',
          'completion_score': scorePercent,
          'evidence_count': (existingLessonProg.isNotEmpty
                  ? ((existingLessonProg.first['evidence_count'] as num?)?.toInt() ?? 0)
                  : 0) +
              (questionResults?.length ?? 1),
          'started_at': existingLessonProg.isNotEmpty
              ? existingLessonProg.first['started_at']
              : nowIso,
          'completed_at': isPassed ? nowIso : null,
          'last_studied_at': nowIso,
          'created_at': existingLessonProg.isNotEmpty
              ? existingLessonProg.first['created_at']
              : nowIso,
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Step C: Discover all knowledge items taught in this lesson
      final segments = await txn.query(
        DatabaseConstants.tableLessonSegments,
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
        orderBy: 'step_order ASC',
      );

      final List<Map<String, dynamic>> taughtWords = [];

      for (final seg in segments) {
        final contentRefId = seg['content_ref_id'] as String?;
        final segmentType = seg['segment_type'] as String? ?? '';

        if (contentRefId != null && (segmentType == 'vocabulary' || segmentType == 'vocab')) {
          final contentItemRows = await txn.query(
            DatabaseConstants.tableContentItems,
            where: 'content_id = ?',
            whereArgs: [contentRefId],
            limit: 1,
          );

          if (contentItemRows.isNotEmpty) {
            final rawJson = contentItemRows.first['content_json'] as String?;
            if (rawJson != null && rawJson.isNotEmpty) {
              try {
                final decoded = json.decode(rawJson) as Map<String, dynamic>;
                final words = (decoded['words'] as List<dynamic>?) ?? [];
                for (final w in words) {
                  taughtWords.add(Map<String, dynamic>.from(w as Map));
                }
              } catch (_) {}
            }
          }
        }
      }

      // Step D: Intake taught words into Evidence, Mastery, and SRS
      for (final w in taughtWords) {
        final simplified = w['simplified'] as String? ?? '';
        if (simplified.isEmpty) continue;

        // Resolve canonical vocabulary ID
        final vocabRows = await txn.query(
          DatabaseConstants.tableVocabularies,
          columns: ['id'],
          where: 'simplified = ?',
          whereArgs: [simplified],
          limit: 1,
        );
        final canonicalId = vocabRows.isNotEmpty
            ? vocabRows.first['id'] as String
            : simplified;

        // 1. Enroll into SRS if not yet enrolled
        final srsItemId = SrsIntakeRules.generateSrsItemId(canonicalId, 'vocabulary');
        final existingSrs = await txn.query(
          DatabaseConstants.tableSrsItems,
          where: 'content_id = ? AND content_type = ? AND deleted_at IS NULL',
          whereArgs: [canonicalId, 'vocabulary'],
          limit: 1,
        );

        if (existingSrs.isEmpty) {
          final decision = intakeRules.evaluateLessonVocabIntake(
            contentId: canonicalId,
            now: nowUtc,
          );

          await txn.insert(
            DatabaseConstants.tableSrsItems,
            {
              'id': decision.srsItemId,
              'content_id': canonicalId,
              'content_type': 'vocabulary',
              'state': decision.targetState,
              'interval_days': 0,
              'ease_factor': 2.5,
              'repetitions': 0,
              'lapses': 0,
              'due_at': decision.scheduledDueAt.toIso8601String(),
              'last_reviewed_at': null,
              'created_at': nowIso,
              'updated_at': nowIso,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          srsEnrolledCount++;
        }

        // 2. Emit Instruction Evidence (now srs_item_id is guaranteed to exist!)
        final evidenceId = 'EVI_${DateTime.now().microsecondsSinceEpoch}_$canonicalId';
        await txn.insert(
          DatabaseConstants.tableLearnerEvidence,
          {
            'id': evidenceId,
            'srs_item_id': srsItemId,
            'content_id': canonicalId,
            'content_type': 'vocabulary',
            'source': 'curriculum_lesson',
            'score': 1.0,
            'duration_ms': durationMs,
            'metadata_json': json.encode({
              'activity_type': ActivityType.instruction.value,
              'is_success': true,
              'lesson_id': lessonId,
              'simplified': simplified,
            }),
            'created_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        evidenceCount++;

        // 3. Upsert Mastery record as 'learning'
        final existingItemMastery = await txn.query(
          DatabaseConstants.tableCurriculumMastery,
          where: 'item_id = ?',
          whereArgs: [canonicalId],
          limit: 1,
        );

        final curState = existingItemMastery.isNotEmpty
            ? (existingItemMastery.first['mastery_state'] as String? ?? 'unseen')
            : 'unseen';

        // Only transition to 'learning' if it was unseen or exposed
        final nextState = (curState == 'unseen' || curState == 'exposed')
            ? MasteryState.learning.value
            : curState;

        await txn.insert(
          DatabaseConstants.tableCurriculumMastery,
          {
            'id': 'mastery_$canonicalId',
            'item_id': canonicalId,
            'item_type': 'vocabulary',
            'mastery_state': nextState,
            'score': 1.0,
            'attempts_count': existingItemMastery.isNotEmpty
                ? ((existingItemMastery.first['attempts_count'] as num?)?.toInt() ?? 0) + 1
                : 1,
            'last_attempt_at': nowIso,
            'due_review_at': nowUtc.add(const Duration(days: 1)).toIso8601String(),
            'created_at': existingItemMastery.isNotEmpty
                ? existingItemMastery.first['created_at']
                : nowIso,
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Step E: Process question-level practice/mastery exercises (if provided)
      if (questionResults != null && questionResults.isNotEmpty) {
        for (final q in questionResults) {
          final isCorrect = q['is_correct'] == true ||
              q['score'] == 1.0 ||
              (q['selected_option'] != null &&
                  q['selected_option'] == q['correct_option']);
          final score = (q['score'] as num?)?.toDouble() ?? (isCorrect ? 1.0 : 0.0);

          // Find targeted word or knowledge item
          String? targetWord = q['target_word'] as String?;
          if (targetWord == null || targetWord.isEmpty) {
            final prompt = q['prompt'] as String? ?? '';
            // Try extracting target word enclosed in quotes e.g. Từ "你"
            final match = RegExp(r'["“]([^"”]+)["”]').firstMatch(prompt);
            if (match != null) {
              targetWord = match.group(1);
            }
          }

          if (targetWord != null && targetWord.isNotEmpty) {
            // Find canonical ID
            final vocabRows = await txn.query(
              DatabaseConstants.tableVocabularies,
              columns: ['id'],
              where: 'simplified = ?',
              whereArgs: [targetWord],
              limit: 1,
            );
            final targetId = vocabRows.isNotEmpty
                ? vocabRows.first['id'] as String
                : targetWord;

            // Check if card exists in SRS to safely populate srs_item_id FK
            final srsRows = await txn.query(
              DatabaseConstants.tableSrsItems,
              columns: ['id'],
              where: 'content_id = ? AND content_type = ? AND deleted_at IS NULL',
              whereArgs: [targetId, 'vocabulary'],
              limit: 1,
            );
            final String? linkedSrsId = srsRows.isNotEmpty ? srsRows.first['id'] as String : null;

            // 1. Log Application Evidence
            final appEvidenceId = 'EVI_${DateTime.now().microsecondsSinceEpoch}_$targetId';
            await txn.insert(
              DatabaseConstants.tableLearnerEvidence,
              {
                'id': appEvidenceId,
                'srs_item_id': linkedSrsId,
                'content_id': targetId,
                'content_type': 'vocabulary',
                'source': 'curriculum_exercise',
                'score': score,
                'duration_ms': 0,
                'metadata_json': json.encode({
                  'activity_type': ActivityType.application.value,
                  'is_success': isCorrect,
                  'lesson_id': lessonId,
                  'target_word': targetWord,
                }),
                'created_at': nowIso,
              },
              conflictAlgorithm: ConflictAlgorithm.abort,
            );
            evidenceCount++;

            // 2. If incorrect, tag as unstable and reschedule in SRS for immediate reinforcement
            if (!isCorrect) {
              await txn.update(
                DatabaseConstants.tableCurriculumMastery,
                {
                  'mastery_state': MasteryState.unstable.value,
                  'updated_at': nowIso,
                },
                where: 'item_id = ?',
                whereArgs: [targetId],
              );

              final decision = intakeRules.evaluateFailedAttemptIntake(
                contentId: targetId,
                now: nowUtc,
              );

              // Update or insert SRS item to be due NOW
              final existingSrsItem = await txn.query(
                DatabaseConstants.tableSrsItems,
                where: 'content_id = ? AND content_type = ? AND deleted_at IS NULL',
                whereArgs: [targetId, 'vocabulary'],
                limit: 1,
              );

              if (existingSrsItem.isNotEmpty) {
                await txn.update(
                  DatabaseConstants.tableSrsItems,
                  {
                    'state': decision.targetState,
                    'due_at': decision.scheduledDueAt.toIso8601String(),
                    'lapses': ((existingSrsItem.first['lapses'] as num?)?.toInt() ?? 0) + 1,
                    'updated_at': nowIso,
                  },
                  where: 'id = ?',
                  whereArgs: [existingSrsItem.first['id']],
                );
                srsRescheduledCount++;
              } else {
                await txn.insert(
                  DatabaseConstants.tableSrsItems,
                  {
                    'id': decision.srsItemId,
                    'content_id': targetId,
                    'content_type': 'vocabulary',
                    'state': decision.targetState,
                    'interval_days': 0,
                    'ease_factor': 2.5,
                    'repetitions': 0,
                    'lapses': 1,
                    'due_at': decision.scheduledDueAt.toIso8601String(),
                    'last_reviewed_at': null,
                    'created_at': nowIso,
                    'updated_at': nowIso,
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                srsEnrolledCount++;
              }
            }
          }
        }
      }

      // Step F: Unlock downstream prerequisite lessons
      if (isPassed) {
        final lesson = await txn.query(
          DatabaseConstants.tableCurriculumLessons,
          where: 'id = ?',
          whereArgs: [lessonId],
          limit: 1,
        );

        if (lesson.isNotEmpty && lesson.first['unit_id'] != null) {
          final unit = await txn.query(
            DatabaseConstants.tableCurriculumUnits,
            where: 'id = ?',
            whereArgs: [lesson.first['unit_id']],
            limit: 1,
          );

          if (unit.isNotEmpty) {
            final currId = unit.first['curriculum_id'] as String;
            final allLessons = await txn.rawQuery('''
              SELECT l.id, l.is_locked, l.prerequisites_json
              FROM ${DatabaseConstants.tableCurriculumLessons} l
              INNER JOIN ${DatabaseConstants.tableCurriculumUnits} u ON l.unit_id = u.id
              WHERE u.curriculum_id = ?
            ''', [currId]);

            for (final l in allLessons) {
              if (l['is_locked'] == 1 || l['is_locked'] == true) {
                final targetId = l['id'] as String;
                final prereqsJson = l['prerequisites_json'] as String? ?? '[]';
                final prereqs = (json.decode(prereqsJson) as List<dynamic>).map((e) => e.toString()).toList();

                if (prereqs.contains(lessonId)) {
                  // Check if all prerequisites completed
                  bool allMet = true;
                  for (final pId in prereqs) {
                    final check = await txn.query(
                      DatabaseConstants.tableCurriculumLessons,
                      columns: ['status'],
                      where: 'id = ?',
                      whereArgs: [pId],
                      limit: 1,
                    );
                    if (check.isEmpty || check.first['status'] != 'completed') {
                      allMet = false;
                      break;
                    }
                  }

                  if (allMet) {
                    await txn.update(
                      DatabaseConstants.tableCurriculumLessons,
                      {'is_locked': 0},
                      where: 'id = ?',
                      whereArgs: [targetId],
                    );
                    // Also update tableLessonProgress if currently locked
                    await txn.update(
                      DatabaseConstants.tableLessonProgress,
                      {'status': 'available', 'updated_at': nowIso},
                      where: 'lesson_id = ? AND status = ?',
                      whereArgs: [targetId, 'locked'],
                    );
                    unlockedLessons.add(targetId);
                  }
                }
              }
            }
          }
        }
      }
    }

    final db = _db;
    if (db is Database) {
      await db.transaction((txn) async {
        await runPipeline(txn);
      });
    } else {
      await runPipeline(db);
    }

    return LessonPipelineResult(
      lessonId: lessonId,
      isPassed: isPassed,
      scorePercent: scorePercent,
      evidenceCount: evidenceCount,
      srsEnrolledCount: srsEnrolledCount,
      srsRescheduledCount: srsRescheduledCount,
      unlockedLessonIds: unlockedLessons,
    );
  }

  /// 2. Records an interactive exercise attempt from the Practice module:
  /// - Idempotent insertion into practice_attempts
  /// - Appends application learning evidence
  /// - Recalculates mastery state (tags unstable on error, promotes to familiar on repeated success)
  /// - Feeds weak items into SRS for urgent reinforcement
  Future<ExerciseAttempt> recordExerciseAttempt({
    required String sessionId,
    required ExerciseAttempt attempt,
    required ExerciseDefinition exercise,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final nowIso = nowUtc.toIso8601String();

    Future<ExerciseAttempt> runAttempt(DatabaseExecutor txn) async {
      // 1. Idempotency guard: prevent duplicate recording of identical (session_id, exercise_id)
      final existing = await txn.query(
        DatabaseConstants.tablePracticeAttempts,
        where: 'session_id = ? AND exercise_id = ?',
        whereArgs: [sessionId, attempt.exerciseId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return ExerciseAttempt.fromMap(existing.first);
      }

      // 2. Insert practice attempt
      await txn.insert(
        DatabaseConstants.tablePracticeAttempts,
        attempt.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 3. Resolve target knowledge item
      String targetId = exercise.id;
      final stimulus = exercise.stimulus?.trim();
      if (stimulus != null && stimulus.isNotEmpty) {
        final vocabMatch = await txn.query(
          DatabaseConstants.tableVocabularies,
          columns: ['id'],
          where: 'simplified = ?',
          whereArgs: [stimulus],
          limit: 1,
        );
        if (vocabMatch.isNotEmpty) {
          targetId = vocabMatch.first['id'] as String;
        }
      }

      // Check if card exists in SRS to safely populate srs_item_id FK
      final srsRows = await txn.query(
        DatabaseConstants.tableSrsItems,
        columns: ['id'],
        where: 'content_id = ? AND content_type = ? AND deleted_at IS NULL',
        whereArgs: [targetId, 'vocabulary'],
        limit: 1,
      );
      final String? linkedSrsId = srsRows.isNotEmpty ? srsRows.first['id'] as String : null;

      // 4. Append Application Learning Evidence
      final evidenceId = 'EVI_${DateTime.now().microsecondsSinceEpoch}_$targetId';
      await txn.insert(
        DatabaseConstants.tableLearnerEvidence,
        {
          'id': evidenceId,
          'srs_item_id': linkedSrsId,
          'content_id': targetId,
          'content_type': 'vocabulary',
          'source': 'practice_session',
          'score': attempt.score,
          'duration_ms': attempt.durationMs,
          'metadata_json': json.encode({
            'activity_type': ActivityType.application.value,
            'is_success': attempt.isCorrect,
            'exercise_id': exercise.id,
            'session_id': sessionId,
            'exercise_type': exercise.type.name,
          }),
          'created_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final existingMasteryRows = await txn.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'id = ?',
        whereArgs: ['mastery_$targetId'],
        limit: 1,
      );
      final prevAttempts = existingMasteryRows.isNotEmpty
          ? ((existingMasteryRows.first['attempts_count'] as num?)?.toInt() ?? 0)
          : 0;
      final existingCreatedAt = existingMasteryRows.isNotEmpty
          ? (existingMasteryRows.first['created_at'] as String? ?? nowIso)
          : nowIso;
      final existingDueReviewAt = existingMasteryRows.isNotEmpty
          ? (existingMasteryRows.first['due_review_at'] as String?)
          : null;

      if (!attempt.isCorrect) {
        await txn.insert(
          DatabaseConstants.tableCurriculumMastery,
          {
            'id': 'mastery_$targetId',
            'item_id': targetId,
            'item_type': 'vocabulary',
            'mastery_state': MasteryState.unstable.value,
            'score': attempt.score,
            'attempts_count': prevAttempts + 1,
            'last_attempt_at': nowIso,
            'due_review_at': nowIso,
            'created_at': existingCreatedAt,
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Schedule urgent SRS intake
        final decision = intakeRules.evaluateFailedAttemptIntake(
          contentId: targetId,
          now: nowUtc,
        );

        final existingSrs = await txn.query(
          DatabaseConstants.tableSrsItems,
          where: 'content_id = ? AND content_type = ? AND deleted_at IS NULL',
          whereArgs: [targetId, 'vocabulary'],
          limit: 1,
        );

        if (existingSrs.isNotEmpty) {
          await txn.update(
            DatabaseConstants.tableSrsItems,
            {
              'state': decision.targetState,
              'due_at': decision.scheduledDueAt.toIso8601String(),
              'lapses': ((existingSrs.first['lapses'] as num?)?.toInt() ?? 0) + 1,
              'updated_at': nowIso,
            },
            where: 'id = ?',
            whereArgs: [existingSrs.first['id']],
          );
        } else {
          await txn.insert(
            DatabaseConstants.tableSrsItems,
            {
              'id': decision.srsItemId,
              'content_id': targetId,
              'content_type': 'vocabulary',
              'state': decision.targetState,
              'interval_days': 0,
              'ease_factor': 2.5,
              'repetitions': 0,
              'lapses': 1,
              'due_at': decision.scheduledDueAt.toIso8601String(),
              'last_reviewed_at': null,
              'created_at': nowIso,
              'updated_at': nowIso,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } else {
        final historyRows = await txn.query(
          DatabaseConstants.tableLearnerEvidence,
          where: 'content_id = ?',
          whereArgs: [targetId],
        );
        final history = historyRows.map((r) => LearningEvidence.fromMap(r)).toList();
        final calculatedState = evaluator.evaluate(evidenceHistory: history);

        await txn.insert(
          DatabaseConstants.tableCurriculumMastery,
          {
            'id': 'mastery_$targetId',
            'item_id': targetId,
            'item_type': 'vocabulary',
            'mastery_state': calculatedState.value,
            'score': attempt.score,
            'attempts_count': prevAttempts + 1,
            'last_attempt_at': nowIso,
            'due_review_at': existingDueReviewAt,
            'created_at': existingCreatedAt,
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 6. Touch session timestamp
      await txn.update(
        DatabaseConstants.tablePracticeSessions,
        {'updated_at': nowIso},
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      return attempt;
    }

    final db = _db;
    if (db is Database) {
      return await db.transaction((txn) async {
        return await runAttempt(txn);
      });
    } else {
      return await runAttempt(db);
    }
  }

  /// 3. Synchronously processes an SRS Flashcard review turn:
  /// - Evaluates SM-2 retention
  /// - Appends retention evidence
  /// - Promotes to 'mastered' when retention is proven (interval >= 6 days and quality >= 4)
  Future<void> recordSrsReview({
    required SrsReviewResult reviewResult,
    required String contentId,
    String contentType = 'vocabulary',
    DatabaseExecutor? txn,
  }) async {
    final nowUtc = reviewResult.reviewTime;
    final nowIso = nowUtc.toIso8601String();

    Future<void> runSrsSync(DatabaseExecutor targetTxn) async {
      // 1. Fetch evidence history for this knowledge item
      final historyRows = await targetTxn.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'content_id = ?',
        whereArgs: [contentId],
      );
      final history = historyRows.map((r) => LearningEvidence.fromMap(r)).toList();

      // Check if this retention event was already inserted into learner_evidence
      final alreadyLogged = history.any((e) =>
          e.activityType == ActivityType.retention &&
          e.createdAt.difference(nowUtc).inSeconds.abs() < 2);
      if (!alreadyLogged) {
        final newEvidence = LearningEvidence(
          id: 'temp_${DateTime.now().microsecondsSinceEpoch}',
          contentId: contentId,
          contentType: contentType,
          activityType: ActivityType.retention,
          sourceModule: 'srs_flashcard',
          score: reviewResult.isSuccessful ? 1.0 : 0.0,
          isSuccess: reviewResult.isSuccessful,
          metadata: {
            'rating': reviewResult.rating.label,
            'quality': reviewResult.rating.quality,
            'new_interval': reviewResult.newIntervalDays,
          },
          createdAt: nowUtc,
        );
        history.add(newEvidence);
      }

      // 2. Evaluate updated mastery state
      final newState = evaluator.evaluate(evidenceHistory: history);

      // 3. Upsert into curriculum_mastery
      final existing = await targetTxn.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: [contentId],
        limit: 1,
      );

      await targetTxn.insert(
        DatabaseConstants.tableCurriculumMastery,
        {
          'id': 'mastery_$contentId',
          'item_id': contentId,
          'item_type': contentType,
          'mastery_state': newState.value,
          'score': reviewResult.isSuccessful ? 1.0 : 0.0,
          'attempts_count': existing.isNotEmpty
              ? ((existing.first['attempts_count'] as num?)?.toInt() ?? 0) + 1
              : 1,
          'last_attempt_at': nowIso,
          'due_review_at': reviewResult.nextState.dueAt.toIso8601String(),
          'created_at': existing.isNotEmpty ? existing.first['created_at'] : nowIso,
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (txn != null) {
      await runSrsSync(txn);
    } else {
      final db = _db;
      if (db is Database) {
        await db.transaction((t) async {
          await runSrsSync(t);
        });
      } else {
        await runSrsSync(db);
      }
    }
  }

  /// Returns aggregated breakdown of knowledge items by mastery state
  Future<Map<MasteryState, int>> getMasterySummary({String itemType = 'vocabulary'}) async {
    final rows = await _db.rawQuery('''
      SELECT mastery_state, COUNT(*) as count
      FROM ${DatabaseConstants.tableCurriculumMastery}
      WHERE item_type = ?
      GROUP BY mastery_state
    ''', [itemType]);

    final summary = <MasteryState, int>{
      for (final s in MasteryState.values) s: 0,
    };

    for (final r in rows) {
      final stateStr = r['mastery_state'] as String? ?? 'unseen';
      final state = MasteryState.fromString(stateStr);
      final count = (r['count'] as num?)?.toInt() ?? 0;
      summary[state] = (summary[state] ?? 0) + count;
    }

    return summary;
  }
}
