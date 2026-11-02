import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/curriculum_dao.dart';
import '../../../../core/database/dao/mastery_dao.dart';
import 'prerequisite_engine.dart';

class MasteryUpdateResult {
  final String lessonId;
  final bool isPassed;
  final double scorePercent;
  final String masteryState;
  final int totalAttempts;

  const MasteryUpdateResult({
    required this.lessonId,
    required this.isPassed,
    required this.scorePercent,
    required this.masteryState,
    required this.totalAttempts,
  });
}

class MasteryEngine {
  final DatabaseExecutor _db;
  late final CurriculumDao _curriculumDao;
  late final MasteryDao _masteryDao;
  late final PrerequisiteEngine _prereqEngine;

  MasteryEngine(this._db) {
    _curriculumDao = CurriculumDao(_db);
    _masteryDao = MasteryDao(_db);
    _prereqEngine = PrerequisiteEngine(_db);
  }

  Future<MasteryUpdateResult> recordLessonAttempt({
    required String lessonId,
    required double scorePercent,
    double passingThreshold = 0.8,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final nowIso = nowUtc.toIso8601String();

    final existing = await _masteryDao.getMastery(lessonId);
    final prevAttempts = (existing?['attempts_count'] as num?)?.toInt() ?? 0;
    final newAttempts = prevAttempts + 1;

    final isPassed = scorePercent >= passingThreshold;
    final newState = isPassed ? 'completed' : 'in_progress';

    // Calculate due review date for SRS intake (+3 days on pass, +1 day on fail)
    final dueReview = nowUtc.add(Duration(days: isPassed ? 3 : 1)).toIso8601String();

    await _masteryDao.upsertMastery({
      'id': 'mastery_$lessonId',
      'item_id': lessonId,
      'item_type': 'lesson',
      'mastery_state': newState,
      'score': scorePercent,
      'attempts_count': newAttempts,
      'last_attempt_at': nowIso,
      'due_review_at': dueReview,
      'created_at': existing?['created_at'] ?? nowIso,
      'updated_at': nowIso,
    });

    if (isPassed) {
      await _curriculumDao.updateLessonStatus(
        lessonId,
        status: 'completed',
        completedAt: nowIso,
      );

      // Check all lessons in curriculum and auto-unlock next ones whose prereq was this lesson
      final lesson = await _curriculumDao.getLesson(lessonId);
      if (lesson != null && lesson['unit_id'] != null) {
        final unit = await _db.query(
          'curriculum_units',
          where: 'id = ?',
          whereArgs: [lesson['unit_id']],
          limit: 1,
        );
        if (unit.isNotEmpty) {
          final currId = unit.first['curriculum_id'] as String;
          final allLessons = await _curriculumDao.getAllLessonsForCurriculum(currId);
          for (final l in allLessons) {
            if (l['is_locked'] == 1 || l['is_locked'] == true) {
              await _prereqEngine.evaluateUnlockStatus(l['id'] as String);
            }
          }
        }
      }
    }

    return MasteryUpdateResult(
      lessonId: lessonId,
      isPassed: isPassed,
      scorePercent: scorePercent,
      masteryState: newState,
      totalAttempts: newAttempts,
    );
  }

  Future<List<Map<String, dynamic>>> getWeakLessons({double threshold = 0.70}) async {
    return _masteryDao.getWeakKnowledgeItems(scoreThreshold: threshold);
  }
}
