import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/activity_dao.dart';
import '../../../../core/database/dao/learner_evidence_dao.dart';
import '../../../../core/database/database_constants.dart';
import '../../../../core/knowledge/domain/services/knowledge_identity_registry.dart';
import '../domain/catalog/curriculum_catalog.dart';
import '../domain/engine/adaptive_roadmap_engine.dart';
import '../domain/models/roadmap_models.dart';

abstract class RoadmapRepository {
  Future<LearnerGoal> getActiveGoal();
  Future<void> updateGoal(LearnerGoal goal);
  Future<Map<String, LessonProgress>> getLessonProgressMap();
  Future<void> startLesson(String lessonId);
  Future<void> completeLesson({required String lessonId, required double score});
  Future<void> skipLesson(String lessonId);
  Future<LearnerRoadmapState> getAdaptiveRoadmapState();
}

class DefaultRoadmapRepository implements RoadmapRepository {
  final Database _db;
  late final LearnerEvidenceDao _evidenceDao;
  late final ActivityDao _activityDao;
  late final KnowledgeIdentityRegistry _identityRegistry;
  final AdaptiveRoadmapEngine engine;

  DefaultRoadmapRepository(
    this._db, {
    this.engine = const AdaptiveRoadmapEngine(),
    KnowledgeIdentityRegistry? identityRegistry,
  })  : _evidenceDao = LearnerEvidenceDao(_db),
        _activityDao = ActivityDao(_db),
        _identityRegistry = identityRegistry ?? KnowledgeIdentityRegistry(_db);

  @override
  Future<LearnerGoal> getActiveGoal() async {
    final rows = await _db.query(
      DatabaseConstants.tableLearnerGoals,
      where: 'is_active = 1',
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      final defaultGoal = LearnerGoal.defaultGoal();
      await updateGoal(defaultGoal);
      return defaultGoal;
    }

    return LearnerGoal.fromMap(rows.first);
  }

  @override
  Future<void> updateGoal(LearnerGoal goal) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((txn) async {
      // Deactivate older active goals
      await txn.update(
        DatabaseConstants.tableLearnerGoals,
        {'is_active': 0, 'updated_at': nowUtc},
        where: 'is_active = 1',
      );

      await txn.insert(
        DatabaseConstants.tableLearnerGoals,
        goal.copyWith(isActive: true, updatedAt: DateTime.now().toUtc()).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<Map<String, LessonProgress>> getLessonProgressMap() async {
    final rows = await _db.query(DatabaseConstants.tableLessonProgress);
    final map = <String, LessonProgress>{};
    for (final r in rows) {
      final progress = LessonProgress.fromMap(r);
      map[progress.lessonId] = progress;

      // Index by canonical ID and all aliases for seamless roadmap/curriculum sync
      final canonical = await _identityRegistry.toCanonicalLessonId(progress.lessonId);
      map[canonical] = progress;

      final aliases = await _identityRegistry.getAliasesFor(canonical);
      for (final alias in aliases) {
        map[alias] = progress;
      }
    }
    return map;
  }

  @override
  Future<void> startLesson(String lessonId) async {
    // CRITICAL: Opening/starting a lesson NEVER marks it completed!
    final lesson = CurriculumCatalog.findLessonById(lessonId);
    if (lesson == null) return;

    final canonicalId = await _identityRegistry.toCanonicalLessonId(lessonId);

    final existingRows = await _db.query(
      DatabaseConstants.tableLessonProgress,
      where: 'lesson_id = ? OR lesson_id = ?',
      whereArgs: [lessonId, canonicalId],
      limit: 1,
    );

    final nowUtc = DateTime.now().toUtc().toIso8601String();

    if (existingRows.isEmpty) {
      await _db.insert(
        DatabaseConstants.tableLessonProgress,
        {
          'id': 'prog_${lessonId}_${DateTime.now().millisecondsSinceEpoch}',
          'lesson_id': lessonId,
          'unit_id': lesson.unitId,
          'hsk_level': lesson.level,
          'status': LessonStatus.inProgress.name,
          'evidence_count': 0,
          'started_at': nowUtc,
          'last_studied_at': nowUtc,
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      final existing = LessonProgress.fromMap(existingRows.first);
      if (!existing.isCompleted) {
        await _db.update(
          DatabaseConstants.tableLessonProgress,
          {
            'status': LessonStatus.inProgress.name,
            'last_studied_at': nowUtc,
            'updated_at': nowUtc,
          },
          where: 'id = ?',
          whereArgs: [existing.id],
        );
      }
    }
  }

  @override
  Future<void> completeLesson({required String lessonId, required double score}) async {
    final lesson = CurriculumCatalog.findLessonById(lessonId);
    if (lesson == null) return;

    final canonicalId = await _identityRegistry.toCanonicalLessonId(lessonId);
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final clampedScore = score.clamp(0.0, 1.0);

    await _db.transaction((txn) async {
      // 1. Update lesson progress
      await txn.insert(
        DatabaseConstants.tableLessonProgress,
        {
          'id': 'prog_${lessonId}_${DateTime.now().millisecondsSinceEpoch}',
          'lesson_id': lessonId,
          'unit_id': lesson.unitId,
          'hsk_level': lesson.level,
          'status': LessonStatus.completed.name,
          'completion_score': clampedScore,
          'evidence_count': 1,
          'started_at': nowUtc,
          'completed_at': nowUtc,
          'last_studied_at': nowUtc,
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Persist learner evidence
      final evidenceId = 'ev_les_${DateTime.now().microsecondsSinceEpoch}';
      await _evidenceDao.appendEvidence(
        {
          'id': evidenceId,
          'content_id': lessonId,
          'content_type': lesson.primarySkill.name,
          'source': 'curriculum_lesson',
          'score': clampedScore,
          'duration_ms': lesson.estimatedMinutes * 60 * 1000,
          'metadata_json': json.encode({
            'lesson_title': lesson.title,
            'unit_id': lesson.unitId,
            'hsk_level': lesson.level,
            'canonical_id': canonicalId,
          }),
          'created_at': nowUtc,
        },
        txn: txn,
      );

      // 3. Log activity for daily streak
      final activityId = 'act_les_${DateTime.now().microsecondsSinceEpoch}';
      await _activityDao.logActivity(
        {
          'id': activityId,
          'activity_type': 'lesson',
          'duration_seconds': lesson.estimatedMinutes * 60,
          'items_count': 1,
          'activity_date': nowUtc.substring(0, 10),
          'created_at': nowUtc,
        },
        txn: txn,
      );
    });
  }

  @override
  Future<void> skipLesson(String lessonId) async {
    final lesson = CurriculumCatalog.findLessonById(lessonId);
    if (lesson == null) return;

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await _db.insert(
      DatabaseConstants.tableLessonProgress,
      {
        'id': 'prog_${lessonId}_${DateTime.now().millisecondsSinceEpoch}',
        'lesson_id': lessonId,
        'unit_id': lesson.unitId,
        'hsk_level': lesson.level,
        'status': LessonStatus.skipped.name,
        'completion_score': 1.0,
        'completed_at': nowUtc,
        'last_studied_at': nowUtc,
        'created_at': nowUtc,
        'updated_at': nowUtc,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<LearnerRoadmapState> getAdaptiveRoadmapState() async {
    final goal = await getActiveGoal();
    final progressMap = await getLessonProgressMap();

    // 1. Fetch recent evidence
    final recentEvidence = await _evidenceDao.getRecentEvidence(limit: 50);

    // 2. Fetch latest CAT Placement Test session if exists
    final placementRows = await _db.query(
      DatabaseConstants.tablePlacementTestSessions,
      where: "status = 'completed'",
      orderBy: 'completed_at DESC',
      limit: 1,
    );

    final List<String> knowledgeGaps = [];
    final Map<SkillDimension, double> placementSkillScores = {};

    if (placementRows.isNotEmpty) {
      final pRow = placementRows.first;
      final rawGaps = pRow['knowledge_gaps_json'];
      if (rawGaps is String && rawGaps.isNotEmpty) {
        try {
          final decoded = json.decode(rawGaps) as List<dynamic>;
          for (final e in decoded) {
            if (e is Map) {
              final label = e['label_vi'] ?? e['tag'] ?? e['skill'];
              if (label != null && label.toString().trim().isNotEmpty) {
                knowledgeGaps.add(label.toString().trim());
              }
            } else if (e != null && e.toString().trim().isNotEmpty) {
              knowledgeGaps.add(e.toString().trim());
            }
          }
        } catch (_) {}
      }

      final rawScores = pRow['skill_scores_json'];
      if (rawScores is String && rawScores.isNotEmpty) {
        try {
          final decoded = json.decode(rawScores) as Map<String, dynamic>;
          decoded.forEach((k, v) {
            SkillDimension? skill;
            if (k == 'writing') {
              skill = SkillDimension.writing;
            } else {
              for (final s in SkillDimension.values) {
                if (s.name == k) {
                  skill = s;
                  break;
                }
              }
            }
            skill ??= SkillDimension.vocabulary;

            double? extractedScore;
            if (v is num) {
              extractedScore = v.toDouble();
            } else if (v is Map) {
              final rawVal = v['score'] ?? v['mastery'] ?? v['theta'];
              if (rawVal is num) {
                extractedScore = rawVal.toDouble();
              }
            }
            if (extractedScore != null) {
              placementSkillScores[skill] = extractedScore.clamp(0.0, 1.0);
            }
          });
        } catch (_) {}
      }
    }

    // 3. Fetch SRS lapse count
    int srsLapses = 0;
    try {
      final lapseResult = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableSrsItems} WHERE lapses >= 2',
      );
      srsLapses = Sqflite.firstIntValue(lapseResult) ?? 0;
    } catch (_) {}

    // 4. Generate recommendations via AdaptiveRoadmapEngine
    final context = AdaptiveRoadmapContext(
      goal: goal,
      currentLevel: goal.targetHskLevel,
      progressMap: progressMap,
      skillMasteryScores: placementSkillScores,
      identifiedKnowledgeGaps: knowledgeGaps,
      srsLapseCount: srsLapses,
      recentEvidence: recentEvidence,
    );

    final roadmapState = engine.generateRoadmap(context);

    // 5. Persist snapshot for offline cache
    final snapshotId = 'snap_${goal.targetHskLevel}_${DateTime.now().millisecondsSinceEpoch}';
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await _db.insert(
      DatabaseConstants.tableRoadmapSnapshots,
      {
        'id': snapshotId,
        'current_level': goal.targetHskLevel,
        'active_goal_id': goal.id,
        'recommendations_json': json.encode(
          roadmapState.recommendations.map((r) => r.toMap()).toList(),
        ),
        'skill_mastery_json': json.encode(
          roadmapState.skillMasteryMap.map((k, v) => MapEntry(k.name, v.toMap())),
        ),
        'created_at': nowUtc,
        'updated_at': nowUtc,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return roadmapState;
  }
}
