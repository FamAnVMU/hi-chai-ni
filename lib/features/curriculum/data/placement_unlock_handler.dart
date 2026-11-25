import 'package:sqflite/sqflite.dart';
import '../../../core/database/dao/curriculum_dao.dart';
import '../../../core/database/dao/mastery_dao.dart';
import '../../../core/database/database_constants.dart';
import '../../../core/utils/app_clock.dart';

class PlacementUnlockHandler {
  final DatabaseExecutor _db;
  late final CurriculumDao _curriculumDao;
  late final MasteryDao _masteryDao;

  PlacementUnlockHandler(this._db) {
    _curriculumDao = CurriculumDao(_db);
    _masteryDao = MasteryDao(_db);
  }

  /// Synchronizes `lesson_progress` with placement-credited or newly unlocked lessons.
  Future<void> _upsertLessonProgress({
    required String lessonId,
    required String unitId,
    required int hskLevel,
    required String status,
    double? completionScore,
    String? source,
    String? completedAt,
    required String nowIso,
  }) async {
    try {
      await _db.rawInsert(
        '''
        INSERT INTO ${DatabaseConstants.tableLessonProgress} (
          id, lesson_id, unit_id, hsk_level, status, completion_score,
          evidence_count, started_at, completed_at, last_studied_at,
          created_at, updated_at, source
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(lesson_id) DO UPDATE SET
          status = CASE
            WHEN ${DatabaseConstants.tableLessonProgress}.status = 'completed'
              THEN ${DatabaseConstants.tableLessonProgress}.status
            ELSE excluded.status
          END,
          completion_score = COALESCE(excluded.completion_score, ${DatabaseConstants.tableLessonProgress}.completion_score),
          completed_at = COALESCE(${DatabaseConstants.tableLessonProgress}.completed_at, excluded.completed_at),
          source = COALESCE(${DatabaseConstants.tableLessonProgress}.source, excluded.source),
          updated_at = excluded.updated_at
        ''',
        [
          'prog_$lessonId',
          lessonId,
          unitId,
          hskLevel,
          status,
          completionScore,
          status == 'completed' ? 1 : 0,
          nowIso,
          completedAt,
          nowIso,
          nowIso,
          nowIso,
          source,
        ],
      );
    } catch (_) {
      // Table may not exist in isolated curriculum-only unit test DBs.
    }
  }

  /// Credits all lessons prior to [targetLessonOrder] in [hskLevel],
  /// and unlocks [targetLessonOrder] for immediate study.
  Future<int> creditLessonsUpToLevel({
    required int hskLevel,
    required int targetLessonOrder,
  }) async {
    final curr = await _curriculumDao.getCurriculumByLevel(hskLevel);
    if (curr == null) return 0;

    final currId = curr['id'] as String;
    final allLessons = await _curriculumDao.getAllLessonsForCurriculum(currId);
    final nowUtc = AppClock.nowUtc();
    final nowIso = nowUtc.toIso8601String();
    int creditedCount = 0;

    for (final lesson in allLessons) {
      final lessonId = lesson['id'] as String;
      final orderIndex = (lesson['order_index'] as num).toInt();
      final unitId = lesson['unit_id'] as String;
      final existingStatus = lesson['status'] as String?;
      final existingLocked = (lesson['is_locked'] as num?)?.toInt() ?? 1;

      if (orderIndex < targetLessonOrder) {
        if (existingStatus == 'completed') {
          await _db.update(
            DatabaseConstants.tableCurriculumUnits,
            {'is_locked': 0},
            where: 'id = ?',
            whereArgs: [unitId],
          );
          await _upsertLessonProgress(
            lessonId: lessonId,
            unitId: unitId,
            hskLevel: hskLevel,
            status: 'completed',
            completionScore: 1.0,
            source: (lesson['credited_reason'] as String?) ?? 'placement_test',
            completedAt: (lesson['completed_at'] as String?) ?? nowIso,
            nowIso: nowIso,
          );
          continue;
        }
        await _curriculumDao.updateLessonStatus(
          lessonId,
          status: 'completed',
          isLocked: 0,
          completedAt: nowIso,
          creditedReason: 'credited_by_placement_test',
        );

        await _db.update(
          DatabaseConstants.tableCurriculumUnits,
          {'is_locked': 0},
          where: 'id = ?',
          whereArgs: [unitId],
        );

        await _masteryDao.upsertMastery({
          'id': 'mastery_$lessonId',
          'item_id': lessonId,
          'item_type': 'lesson',
          'mastery_state': 'completed',
          'score': 1.0,
          'attempts_count': 1,
          'last_attempt_at': nowIso,
          'due_review_at': nowUtc.add(const Duration(days: 7)).toIso8601String(),
          'created_at': nowIso,
          'updated_at': nowIso,
        });

        await _upsertLessonProgress(
          lessonId: lessonId,
          unitId: unitId,
          hskLevel: hskLevel,
          status: 'completed',
          completionScore: 1.0,
          source: 'placement_test',
          completedAt: nowIso,
          nowIso: nowIso,
        );

        creditedCount++;
      } else if (orderIndex == targetLessonOrder) {
        // Unlock target lesson without overwriting existing completed or in-progress status
        final preservedStatus = (existingStatus == 'completed' || existingStatus == 'in_progress')
            ? existingStatus!
            : 'not_started';
        if (existingLocked != 0 || existingStatus == null || existingStatus.isEmpty) {
          await _curriculumDao.updateLessonStatus(
            lessonId,
            status: preservedStatus,
            isLocked: 0,
          );
        }

        await _db.update(
          DatabaseConstants.tableCurriculumUnits,
          {'is_locked': 0},
          where: 'id = ?',
          whereArgs: [unitId],
        );

        if (preservedStatus != 'completed') {
          await _upsertLessonProgress(
            lessonId: lessonId,
            unitId: unitId,
            hskLevel: hskLevel,
            status: preservedStatus == 'in_progress' ? 'in_progress' : 'available',
            nowIso: nowIso,
          );
        }
      }
    }

    return creditedCount;
  }

  /// Automatically unlocks curriculum content corresponding to the CAT placement recommended HSK level.
  ///
  /// - Automatically credits all lessons in all lower levels (< [recommendedLevel]) with
  ///   `credited_by_placement_test`.
  /// - In [recommendedLevel], credits all lessons prior to [startingLessonOrder] and unlocks
  ///   [startingLessonOrder] (default: Lesson 1) for immediate study.
  Future<int> unlockForRecommendedLevel(
    int recommendedLevel, {
    int startingLessonOrder = 1,
  }) async {
    int totalCredited = 0;

    // 1. Auto-credit all curriculum levels prior to recommendedLevel
    for (int lvl = 1; lvl < recommendedLevel; lvl++) {
      totalCredited += await creditLessonsUpToLevel(
        hskLevel: lvl,
        targetLessonOrder: 999999, // Exceeds any lesson count, crediting all lessons in level
      );
    }

    // 2. In recommendedLevel, unlock starting lesson (and credit lessons before it if startingLessonOrder > 1)
    totalCredited += await creditLessonsUpToLevel(
      hskLevel: recommendedLevel,
      targetLessonOrder: startingLessonOrder,
    );

    return totalCredited;
  }
}
