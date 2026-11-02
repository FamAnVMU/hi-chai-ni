import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class CurriculumDao {
  final DatabaseExecutor _db;

  const CurriculumDao(this._db);

  // Content Packs
  Future<void> insertContentPack(Map<String, dynamic> row) async {
    await _db.insert(
      DatabaseConstants.tableContentPacks,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    await _db.insert(
      DatabaseConstants.tableCurriculums,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    await _db.insert(
      DatabaseConstants.tableCurriculumUnits,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    await _db.insert(
      DatabaseConstants.tableCurriculumLessons,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    await _db.insert(
      DatabaseConstants.tableLessonSegments,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSegmentsByLessonId(String lessonId) async {
    return _db.query(
      DatabaseConstants.tableLessonSegments,
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      orderBy: 'step_order ASC',
    );
  }

  // Level Exit Exams
  Future<void> insertExitExam(Map<String, dynamic> row) async {
    await _db.insert(
      DatabaseConstants.tableLevelExitExams,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
}
