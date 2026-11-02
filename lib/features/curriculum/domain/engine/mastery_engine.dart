import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/mastery_dao.dart';
import '../../../learning_pipeline/data/learning_pipeline_coordinator.dart';

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
  late final MasteryDao _masteryDao;
  late final LearningPipelineCoordinator _coordinator;

  MasteryEngine(this._db) {
    _masteryDao = MasteryDao(_db);
    _coordinator = LearningPipelineCoordinator(_db);
  }

  Future<MasteryUpdateResult> recordLessonAttempt({
    required String lessonId,
    required double scorePercent,
    List<Map<String, dynamic>>? questionResults,
    double passingThreshold = 0.8,
  }) async {
    final pipelineResult = await _coordinator.recordLessonCompletion(
      lessonId: lessonId,
      scorePercent: scorePercent,
      questionResults: questionResults,
      passingThreshold: passingThreshold,
    );

    final existing = await _masteryDao.getMastery(lessonId);
    final attempts = (existing?['attempts_count'] as num?)?.toInt() ?? 1;

    return MasteryUpdateResult(
      lessonId: lessonId,
      isPassed: pipelineResult.isPassed,
      scorePercent: scorePercent,
      masteryState: pipelineResult.isPassed ? 'completed' : 'in_progress',
      totalAttempts: attempts,
    );
  }

  Future<List<Map<String, dynamic>>> getWeakLessons({double threshold = 0.70}) async {
    return _masteryDao.getWeakKnowledgeItems(scoreThreshold: threshold);
  }
}
