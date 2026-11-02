import 'package:sqflite/sqflite.dart';
import '../../../core/database/dao/curriculum_dao.dart';
import '../../../core/database/dao/content_item_dao.dart';
import '../domain/models/curriculum_models.dart';
import '../domain/models/content_item_models.dart';

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
}
