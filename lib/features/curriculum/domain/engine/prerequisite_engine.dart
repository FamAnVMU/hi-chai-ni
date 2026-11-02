import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/curriculum_dao.dart';
import '../../../../core/database/dao/mastery_dao.dart';

class UnlockResult {
  final String lessonId;
  final bool isUnlocked;
  final String? lockedReason;

  const UnlockResult({
    required this.lessonId,
    required this.isUnlocked,
    this.lockedReason,
  });

  factory UnlockResult.unlocked(String lessonId) =>
      UnlockResult(lessonId: lessonId, isUnlocked: true);

  factory UnlockResult.locked(String lessonId, {required String reason}) =>
      UnlockResult(lessonId: lessonId, isUnlocked: false, lockedReason: reason);
}

class PrerequisiteEngine {
  final DatabaseExecutor _db;
  late final CurriculumDao _curriculumDao;
  late final MasteryDao _masteryDao;

  PrerequisiteEngine(this._db) {
    _curriculumDao = CurriculumDao(_db);
    _masteryDao = MasteryDao(_db);
  }

  Future<UnlockResult> evaluateUnlockStatus(String lessonId) async {
    final lesson = await _curriculumDao.getLesson(lessonId);
    if (lesson == null) {
      return UnlockResult.locked(lessonId, reason: 'Bài học không tồn tại trong hệ thống.');
    }

    // If already marked unlocked in DB
    if (lesson['is_locked'] == 0 || lesson['is_locked'] == false) {
      return UnlockResult.unlocked(lessonId);
    }

    // Parse prerequisites
    List<String> prerequisites = [];
    if (lesson['prerequisites_json'] is String && (lesson['prerequisites_json'] as String).isNotEmpty) {
      try {
        final decoded = json.decode(lesson['prerequisites_json'] as String);
        if (decoded is List) {
          prerequisites = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    if (prerequisites.isEmpty) {
      await _curriculumDao.updateLessonStatus(lessonId, status: lesson['status'] as String? ?? 'not_started', isLocked: 0);
      return UnlockResult.unlocked(lessonId);
    }

    // Verify all prerequisites
    for (final prereqId in prerequisites) {
      final prereqLesson = await _curriculumDao.getLesson(prereqId);
      if (prereqLesson == null) continue;

      final isCredited = prereqLesson['credited_reason'] != null;
      final status = prereqLesson['status'] as String? ?? 'not_started';
      final isCompleted = status == 'completed' || status == 'mastered';

      final mastery = await _masteryDao.getMastery(prereqId);
      final score = (mastery?['score'] as num?)?.toDouble() ?? 0.0;
      final threshold = (prereqLesson['unlock_score_threshold'] as num?)?.toDouble() ?? 0.8;

      if (!isCredited && (!isCompleted || score < threshold)) {
        return UnlockResult.locked(
          lessonId,
          reason: 'Cần đạt điểm tối thiểu ${(threshold * 100).toInt()}% bài học $prereqId để mở khóa.',
        );
      }
    }

    // All prerequisites satisfied -> Unlock lesson
    await _curriculumDao.updateLessonStatus(
      lessonId,
      status: lesson['status'] as String? ?? 'not_started',
      isLocked: 0,
    );

    return UnlockResult.unlocked(lessonId);
  }
}
