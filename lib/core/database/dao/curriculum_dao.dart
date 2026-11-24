import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'dao_utils.dart';

class CurriculumDao {
  final DatabaseExecutor _db;

  const CurriculumDao(this._db);

  // Content Packs
  Future<void> insertContentPack(Map<String, dynamic> row) async {
    await DaoUtils.safeUpsert(_db, DatabaseConstants.tableContentPacks, row);
  }

  Future<Map<String, dynamic>?> getContentPack(String id) async {
    final results = await _db.query(
      DatabaseConstants.tableContentPacks,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllContentPacks() async {
    return _db.query(
      DatabaseConstants.tableContentPacks,
      orderBy: 'hsk_level ASC',
    );
  }

  // Curriculums
  Future<void> insertCurriculum(Map<String, dynamic> row) async {
    await DaoUtils.safeUpsert(_db, DatabaseConstants.tableCurriculums, row);
  }

  Future<Map<String, dynamic>?> getCurriculumByLevel(int level) async {
    final results = await _db.query(
      DatabaseConstants.tableCurriculums,
      where: 'hsk_level = ?',
      whereArgs: [level],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Units
  Future<void> insertUnit(Map<String, dynamic> row) async {
    await DaoUtils.safeUpsert(_db, DatabaseConstants.tableCurriculumUnits, row);
  }

  Future<List<Map<String, dynamic>>> getUnitsByCurriculumId(String curriculumId) async {
    return _db.query(
      DatabaseConstants.tableCurriculumUnits,
      where: 'curriculum_id = ?',
      whereArgs: [curriculumId],
      orderBy: 'order_index ASC',
    );
  }

  // Lessons
  Future<void> insertLesson(Map<String, dynamic> row) async {
    await DaoUtils.safeUpsert(_db, DatabaseConstants.tableCurriculumLessons, row);
  }

  Future<Map<String, dynamic>?> getLesson(String id) async {
    final results = await _db.query(
      DatabaseConstants.tableCurriculumLessons,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getLessonsByUnitId(String unitId) async {
    return _db.query(
      DatabaseConstants.tableCurriculumLessons,
      where: 'unit_id = ?',
      whereArgs: [unitId],
      orderBy: 'order_index ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllLessonsForCurriculum(String curriculumId) async {
    return _db.rawQuery('''
      SELECT l.*, u.order_index as unit_order_index, u.title_vi as unit_title_vi
      FROM ${DatabaseConstants.tableCurriculumLessons} l
      INNER JOIN ${DatabaseConstants.tableCurriculumUnits} u ON l.unit_id = u.id
      WHERE u.curriculum_id = ?
      ORDER BY u.order_index ASC, l.order_index ASC
    ''', [curriculumId]);
  }

  /// Single-query summary of Units + Lessons + Mastery without loading segments or content JSON payloads.
  Future<List<Map<String, dynamic>>> getLessonsSummaryByCurriculumId(String curriculumId) async {
    return _db.rawQuery('''
      SELECT
        u.id AS unit_id,
        u.curriculum_id AS curriculum_id,
        u.order_index AS unit_order_index,
        u.title_vi AS unit_title_vi,
        u.title_zh AS unit_title_zh,
        u.description_vi AS unit_description_vi,
        u.icon_name AS unit_icon_name,
        u.is_locked AS unit_is_locked,
        l.id AS lesson_id,
        l.order_index AS lesson_order_index,
        l.title_vi AS lesson_title_vi,
        l.title_zh AS lesson_title_zh,
        l.pinyin AS lesson_pinyin,
        l.estimated_minutes AS lesson_estimated_minutes,
        l.is_locked AS lesson_is_locked,
        l.unlock_score_threshold AS lesson_unlock_score_threshold,
        l.prerequisites_json AS lesson_prerequisites_json,
        l.status AS lesson_status,
        l.completed_at AS lesson_completed_at,
        l.credited_reason AS lesson_credited_reason,
        COALESCE(m.score, 0.0) AS mastery_score,
        m.mastery_state AS mastery_state
      FROM ${DatabaseConstants.tableCurriculumUnits} u
      LEFT JOIN ${DatabaseConstants.tableCurriculumLessons} l ON l.unit_id = u.id
      LEFT JOIN ${DatabaseConstants.tableCurriculumMastery} m
        ON m.item_id = l.id AND m.item_type = 'lesson'
      WHERE u.curriculum_id = ?
      ORDER BY u.order_index ASC, l.order_index ASC
    ''', [curriculumId]);
  }

  Future<void> updateLessonStatus(String lessonId, {
    required String status,
    int? isLocked,
    String? completedAt,
    String? creditedReason,
  }) async {
    final values = <String, dynamic>{'status': status};
    if (isLocked != null) values['is_locked'] = isLocked;
    if (completedAt != null) values['completed_at'] = completedAt;
    if (creditedReason != null) values['credited_reason'] = creditedReason;

    await _db.update(
      DatabaseConstants.tableCurriculumLessons,
      values,
      where: 'id = ?',
      whereArgs: [lessonId],
    );
  }

  // Segments
  Future<void> insertSegment(Map<String, dynamic> row) async {
    final ref = row['content_ref_id'];
    final normalizedRow = (ref is String && ref != ref.trim())
        ? (Map<String, dynamic>.from(row)..['content_ref_id'] = ref.trim())
        : row;
    await DaoUtils.safeUpsert(_db, DatabaseConstants.tableLessonSegments, normalizedRow);
  }

  Future<List<Map<String, dynamic>>> getSegmentsByLessonId(String lessonId) async {
    return _db.rawQuery('''
      SELECT ls.*, ci.content_json AS content_payload
      FROM ${DatabaseConstants.tableLessonSegments} ls
      LEFT JOIN ${DatabaseConstants.tableContentItems} ci ON ls.content_ref_id = ci.content_id
      WHERE ls.lesson_id = ?
      ORDER BY ls.step_order ASC
    ''', [lessonId]);
  }

  // Level Exit Exams
  Future<void> insertExitExam(Map<String, dynamic> row) async {
    await DaoUtils.safeUpsert(_db, DatabaseConstants.tableLevelExitExams, row);
  }

  Future<Map<String, dynamic>?> getExitExamByLevel(int level) async {
    final results = await _db.query(
      DatabaseConstants.tableLevelExitExams,
      where: 'hsk_level = ?',
      whereArgs: [level],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  static Map<String, dynamic>? safeParsePayload(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = json.decode(trimmed);
        return _deepNormalizeMap(decoded);
      } catch (_) {
        return null;
      }
    }
    return _deepNormalizeMap(raw);
  }

  static Map<String, dynamic>? _deepNormalizeMap(dynamic raw) {
    if (raw is! Map) return null;
    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      result[entry.key.toString()] = _deepNormalizeValue(entry.value);
    }
    return result;
  }

  static dynamic _deepNormalizeValue(dynamic value) {
    if (value is Map) {
      return _deepNormalizeMap(value);
    }
    if (value is List) {
      return value.map(_deepNormalizeValue).toList();
    }
    return value;
  }
}
