import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/dao/curriculum_dao.dart';
import '../../../core/database/dao/content_item_dao.dart';
import '../../../core/database/database_constants.dart';
import '../../../core/utils/app_clock.dart';
import '../domain/models/curriculum_models.dart';
import '../domain/models/content_item_models.dart';
import 'placement_unlock_handler.dart';

class CurriculumRepository {
  final DatabaseExecutor _db;
  late final CurriculumDao _curriculumDao;
  late final ContentItemDao _contentItemDao;

  CurriculumRepository(this._db) {
    _curriculumDao = CurriculumDao(_db);
    _contentItemDao = ContentItemDao(_db);
  }

  Future<Curriculum?> getCurriculumByLevel(int level) async {
    final map = await _curriculumDao.getCurriculumByLevel(level);
    if (map == null) return null;
    return Curriculum.fromMap(map);
  }

  Future<List<CurriculumUnit>> getUnits(String curriculumId) async {
    final maps = await _curriculumDao.getUnitsByCurriculumId(curriculumId);
    return maps.map((m) => CurriculumUnit.fromMap(m)).toList();
  }

  Future<List<CurriculumUnit>> getUnitsWithLessons(String curriculumId) async {
    final unitMaps = await _curriculumDao.getUnitsByCurriculumId(curriculumId);
    if (unitMaps.isEmpty) return [];

    final masteryMap = <String, double>{};
    try {
      final masteryRows = await _db.query(
        DatabaseConstants.tableCurriculumMastery,
        columns: ['item_id', 'score'],
      );
      for (final r in masteryRows) {
        final itemId = r['item_id'] as String?;
        if (itemId != null) {
          masteryMap[itemId] = (r['score'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (_) {}

    final results = <CurriculumUnit>[];
    for (final uMap in unitMaps) {
      final unitId = uMap['id'] as String;
      final lessonMaps = await _curriculumDao.getLessonsByUnitId(unitId);
      final lessons = <CurriculumLesson>[];
      for (final lMap in lessonMaps) {
        final lessonId = lMap['id'] as String;
        final segmentMaps = await _curriculumDao.getSegmentsByLessonId(lessonId);
        final segments = segmentMaps.map((s) => LessonSegment.fromMap(s)).toList();
        final score = masteryMap[lessonId] ?? 0.0;
        lessons.add(CurriculumLesson.fromMap(lMap, segments: segments, masteryScore: score));
      }
      results.add(CurriculumUnit.fromMap(uMap, lessons: lessons));
    }
    return results;
  }

  Future<List<CurriculumLesson>> getLessons(String unitId) async {
    final maps = await _curriculumDao.getLessonsByUnitId(unitId);
    final results = <CurriculumLesson>[];
    for (final map in maps) {
      final lessonId = map['id'] as String;
      final segmentMaps = await _curriculumDao.getSegmentsByLessonId(lessonId);
      final segments = segmentMaps.map((s) => LessonSegment.fromMap(s)).toList();
      results.add(CurriculumLesson.fromMap(map, segments: segments));
    }
    return results;
  }

  Future<CurriculumLesson?> getLessonById(String lessonId) async {
    final map = await _curriculumDao.getLesson(lessonId);
    if (map == null) return null;
    final segmentMaps = await _curriculumDao.getSegmentsByLessonId(lessonId);
    final segments = segmentMaps.map((s) => LessonSegment.fromMap(s)).toList();
    return CurriculumLesson.fromMap(map, segments: segments);
  }

  Future<List<CurriculumLesson>> getAllLessons(String curriculumId) async {
    final maps = await _curriculumDao.getAllLessonsForCurriculum(curriculumId);
    final results = <CurriculumLesson>[];
    for (final map in maps) {
      final lessonId = map['id'] as String;
      final segmentMaps = await _curriculumDao.getSegmentsByLessonId(lessonId);
      final segments = segmentMaps.map((s) => LessonSegment.fromMap(s)).toList();
      results.add(CurriculumLesson.fromMap(map, segments: segments));
    }
    return results;
  }

  Future<ContentItem?> getContentItem(String contentId) async {
    final map = await _contentItemDao.getContentItemByContentId(contentId);
    if (map == null) return null;
    return ContentItem.fromMap(map);
  }

  Future<List<ContentItem>> getContentItemsByLevelAndType(int hskLevel, String type) async {
    final maps = await _contentItemDao.getContentItemsByLevelAndType(hskLevel, type);
    return maps.map((m) => ContentItem.fromMap(m)).toList();
  }

  Future<Map<String, dynamic>?> getExitExam(int level) async {
    return _curriculumDao.getExitExamByLevel(level);
  }

  /// Atomically records the HSK Exit Exam results into:
  /// - `curriculum_mastery`: records mastery_state ('mastered' if score >= 120, else 'failed')
  /// - `learning_activities`: sustains Home Screen streak with actual study activity
  /// - `learner_evidence`: append-only evidence trail
  /// - `curriculum_lessons` / `PlacementUnlockHandler`: unlocks next HSK level when passed!
  Future<void> recordExitExamSubmission({
    required int hskLevel,
    required int score,
    required int totalScore,
    required int listenScore,
    required int readScore,
    required bool isPassed,
    required int durationSeconds,
    required int itemsCount,
  }) async {
    final now = AppClock.nowUtc();
    final nowIso = now.toIso8601String();
    final todayDate = AppClock.todayLocalDateString();
    final scoreRatio = (totalScore > 0 ? (score / totalScore) : 0.0).clamp(0.0, 1.0);
    final itemId = 'exit_exam_hsk$hskLevel';

    Future<void> executeWith(DatabaseExecutor executor) async {
      // 1. Persist to curriculum_mastery
      final existingMastery = await executor.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: [itemId],
        limit: 1,
      );

      final attempts = existingMastery.isNotEmpty
          ? ((existingMastery.first['attempts_count'] as int? ?? 0) + 1)
          : 1;

      final masteryRow = <String, dynamic>{
        'id': 'cm_$itemId',
        'item_id': itemId,
        'item_type': 'exit_exam',
        'mastery_state': isPassed ? 'mastered' : 'failed',
        'score': scoreRatio,
        'attempts_count': attempts,
        'last_attempt_at': nowIso,
        'due_review_at': isPassed
            ? now.add(const Duration(days: 30)).toIso8601String()
            : now.add(const Duration(days: 3)).toIso8601String(),
        'created_at': existingMastery.isNotEmpty
            ? (existingMastery.first['created_at'] as String? ?? nowIso)
            : nowIso,
        'updated_at': nowIso,
      };

      if (existingMastery.isNotEmpty) {
        await executor.update(
          DatabaseConstants.tableCurriculumMastery,
          masteryRow,
          where: 'item_id = ?',
          whereArgs: [itemId],
        );
      } else {
        await executor.insert(
          DatabaseConstants.tableCurriculumMastery,
          masteryRow,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // 2. Persist to learning_activities (sustains Home streak)
      await executor.insert(
        DatabaseConstants.tableLearningActivities,
        {
          'id': 'act_exit_exam_${hskLevel}_${DateTime.now().millisecondsSinceEpoch}',
          'activity_type': 'exit_exam',
          'duration_seconds': durationSeconds > 0 ? durationSeconds : 60,
          'items_count': itemsCount,
          'activity_date': todayDate,
          'created_at': nowIso,
          'timezone_offset_minutes': AppClock.currentOffset.inMinutes,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // 3. Persist to learner_evidence
      await executor.insert(
        DatabaseConstants.tableLearnerEvidence,
        {
          'id': 'evi_exit_exam_${hskLevel}_${DateTime.now().millisecondsSinceEpoch}',
          'srs_item_id': null,
          'content_id': itemId,
          'content_type': 'exit_exam',
          'source': 'exit_exam',
          'score': scoreRatio,
          'duration_ms': (durationSeconds > 0 ? durationSeconds : 60) * 1000,
          'metadata_json': jsonEncode({
            'hsk_level': hskLevel,
            'score': score,
            'total_score': totalScore,
            'listen_score': listenScore,
            'read_score': readScore,
            'is_passed': isPassed,
          }),
          'created_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // 4. If passed, unlock next level
      if (isPassed) {
        try {
          final unlockHandler = PlacementUnlockHandler(executor);
          await unlockHandler.unlockForRecommendedLevel(
            hskLevel + 1,
            startingLessonOrder: 1,
          );
        } catch (_) {}
      }
    }

    final db = _db;
    if (db is Database) {
      await db.transaction((txn) async {
        await executeWith(txn);
      });
    } else {
      await executeWith(_db);
    }
  }
}
