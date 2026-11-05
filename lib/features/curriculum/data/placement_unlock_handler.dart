import 'package:sqflite/sqflite.dart';
import '../../../core/database/dao/curriculum_dao.dart';
import '../../../core/database/dao/mastery_dao.dart';

class PlacementUnlockHandler {
  final DatabaseExecutor _db;
  late final CurriculumDao _curriculumDao;
  late final MasteryDao _masteryDao;

  PlacementUnlockHandler(this._db) {
    _curriculumDao = CurriculumDao(_db);
    _masteryDao = MasteryDao(_db);
  }

  /// Credits all lessons prior to [targetLessonOrder] in [hskLevel],
  /// and unlocks [targetLessonOrder] for immediate study.
  Future<int> creditLessonsUpToLevel({
    required int hskLevel,
    required int targetLessonOrder,
  }) async {
    final effectiveLevel = (hskLevel <= 0) ? 1 : (hskLevel > 6 ? 6 : hskLevel);
    final curr = await _curriculumDao.getCurriculumByLevel(effectiveLevel);
    if (curr == null) return 0;

    final currId = curr['id'] as String;
    final allLessons = await _curriculumDao.getAllLessonsForCurriculum(currId);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    int creditedCount = 0;

    for (final lesson in allLessons) {
      final lessonId = lesson['id'] as String;
      final orderIndex = (lesson['order_index'] as num).toInt();
      final unitId = lesson['unit_id'] as String;
      final existingStatus = lesson['status'] as String?;

      if (orderIndex < targetLessonOrder) {
        if (existingStatus == 'completed') {
          continue;
        }
        await _curriculumDao.updateLessonStatus(
          lessonId,
          status: 'completed',
          isLocked: 0,
          completedAt: nowIso,
          creditedReason: 'credited_by_placement_test',
        );

        await _masteryDao.upsertMastery({
          'id': 'mastery_$lessonId',
          'item_id': lessonId,
          'item_type': 'lesson',
          'mastery_state': 'completed',
          'score': 1.0,
          'attempts_count': 1,
          'last_attempt_at': nowIso,
          'due_review_at': DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
          'created_at': nowIso,
          'updated_at': nowIso,
        });

        creditedCount++;
      } else if (orderIndex == targetLessonOrder) {
        // Unlock target lesson for immediate learning
        await _curriculumDao.updateLessonStatus(
          lessonId,
          status: 'not_started',
          isLocked: 0,
        );

        // Unlock unit if locked
        await _db.update(
          'curriculum_units',
          {'is_locked': 0},
          where: 'id = ?',
          whereArgs: [unitId],
        );
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
    final effectiveLevel = (recommendedLevel <= 0) ? 1 : (recommendedLevel > 6 ? 6 : recommendedLevel);
    int totalCredited = 0;

    // 1. Auto-credit all curriculum levels prior to effectiveLevel
    for (int lvl = 1; lvl < effectiveLevel; lvl++) {
      totalCredited += await creditLessonsUpToLevel(
        hskLevel: lvl,
        targetLessonOrder: 999999, // Exceeds any lesson count, crediting all lessons in level
      );
    }

    // 2. In effectiveLevel, unlock starting lesson (and credit lessons before it if startingLessonOrder > 1)
    totalCredited += await creditLessonsUpToLevel(
      hskLevel: effectiveLevel,
      targetLessonOrder: startingLessonOrder,
    );

    return totalCredited;
  }
}
