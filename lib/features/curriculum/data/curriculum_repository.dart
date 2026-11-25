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

  static int _exitEviSeq = 0;

  Future<List<CurriculumUnit>> getUnitsWithLessons(String curriculumId) async {
    final rows = await _curriculumDao.getLessonsSummaryByCurriculumId(curriculumId);
    if (rows.isEmpty) return [];

    final unitOrder = <String>[];
    final unitRowsById = <String, Map<String, dynamic>>{};
    final lessonsByUnitId = <String, List<CurriculumLesson>>{};

    for (final row in rows) {
      final unitId = row['unit_id'] as String?;
      if (unitId == null) continue;

      if (!unitRowsById.containsKey(unitId)) {
        unitOrder.add(unitId);
        unitRowsById[unitId] = {
          'id': unitId,
          'curriculum_id': row['curriculum_id'] ?? curriculumId,
          'order_index': row['unit_order_index'] ?? 0,
          'title_vi': row['unit_title_vi'] ?? '',
          'title_zh': row['unit_title_zh'] ?? '',
          'description_vi': row['unit_description_vi'],
          'icon_name': row['unit_icon_name'],
          'is_locked': row['unit_is_locked'] ?? 0,
        };
        lessonsByUnitId[unitId] = <CurriculumLesson>[];
      }

      final lessonId = row['lesson_id'] as String?;
      if (lessonId != null) {
        final normalizedLesson = <String, dynamic>{
          'id': lessonId,
          'unit_id': unitId,
          'order_index': row['lesson_order_index'] ?? 0,
          'title_vi': row['lesson_title_vi'] ?? '',
          'title_zh': row['lesson_title_zh'] ?? '',
          'pinyin': row['lesson_pinyin'] ?? '',
          'estimated_minutes': row['lesson_estimated_minutes'] ?? 15,
          'is_locked': row['lesson_is_locked'] ?? 1,
          'unlock_score_threshold': row['lesson_unlock_score_threshold'] ?? 0.8,
          'prerequisites_json': row['lesson_prerequisites_json'],
          'status': row['lesson_status'] ?? 'not_started',
          'completed_at': row['lesson_completed_at'],
          'credited_reason': row['lesson_credited_reason'],
        };
        final score = (row['mastery_score'] as num?)?.toDouble() ?? 0.0;
        lessonsByUnitId[unitId]!.add(
          CurriculumLesson.fromMap(
            normalizedLesson,
            segments: const [],
            masteryScore: score,
          ),
        );
      }
    }

    return unitOrder
        .map(
          (unitId) => CurriculumUnit.fromMap(
            unitRowsById[unitId]!,
            lessons: lessonsByUnitId[unitId] ?? const [],
          ),
        )
        .toList();
  }

  /// Fetches segments (with resolved `content_payload`) for a single lesson on demand.
  Future<List<LessonSegment>> getLessonSegments(String lessonId) async {
    final segmentMaps = await _curriculumDao.getSegmentsByLessonId(lessonId);
    return segmentMaps.map((s) => LessonSegment.fromMap(s)).toList();
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
      final seq = ++_exitEviSeq;
      await executor.insert(
        DatabaseConstants.tableLearningActivities,
        {
          'id': 'act_exit_exam_${hskLevel}_${now.microsecondsSinceEpoch}_$seq',
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
          'id': 'EVI_EXIT_${now.microsecondsSinceEpoch}_${seq}_hsk$hskLevel',
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

      // 4. If passed, promote user profile / goal and unlock next level
      if (isPassed) {
        final nextLevel = (hskLevel + 1).clamp(1, 6);
        try {
          await executor.rawUpdate(
            '''
            UPDATE ${DatabaseConstants.tableUserProfiles}
            SET current_hsk_level = CASE
                  WHEN COALESCE(current_hsk_level, 1) < ? THEN ?
                  ELSE COALESCE(current_hsk_level, 1)
                END,
                updated_at = ?
            ''',
            [nextLevel, nextLevel, nowIso],
          );
          await executor.rawUpdate(
            '''
            UPDATE ${DatabaseConstants.tableLearnerGoals}
            SET target_hsk_level = CASE
                  WHEN target_hsk_level < ? THEN ?
                  ELSE target_hsk_level
                END,
                updated_at = ?
            WHERE is_active = 1
            ''',
            [nextLevel, nextLevel, nowIso],
          );
        } catch (_) {}

        if (hskLevel < 6) {
          try {
            final unlockHandler = PlacementUnlockHandler(executor);
            await unlockHandler.unlockForRecommendedLevel(
              nextLevel,
              startingLessonOrder: 1,
            );
          } catch (_) {}
        }
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
