import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/activity_dao.dart';
import '../../../../core/database/dao/learner_evidence_dao.dart';
import '../../../../core/database/database_constants.dart';
import '../../../../core/knowledge/domain/services/knowledge_identity_registry.dart';
import '../../../../core/utils/app_clock.dart';
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

    final aliasToCanonical = <String, String>{};
    final canonicalToAliases = <String, List<String>>{};

    for (final entry in KnowledgeIdentityRegistry.wellKnownLessonAliases.entries) {
      aliasToCanonical[entry.key] = entry.value;
      canonicalToAliases.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    try {
      final mappingRows = await _db.query(
        DatabaseConstants.tableContentIdMappings,
        columns: ['old_id', 'new_id'],
      );
      for (final row in mappingRows) {
        final oldId = row['old_id'] as String?;
        final newId = row['new_id'] as String?;
        if (oldId != null && newId != null) {
          aliasToCanonical[oldId] = newId;
          canonicalToAliases.putIfAbsent(newId, () => []).add(oldId);
        }
      }
    } catch (_) {}

    try {
      final registryRows = await _db.query(
        DatabaseConstants.tableKnowledgeRegistry,
        columns: ['id', 'canonical_id'],
        where: "entity_type = 'lesson'",
      );
      for (final row in registryRows) {
        final id = row['id'] as String?;
        final canonicalId = row['canonical_id'] as String?;
        if (id != null && canonicalId != null) {
          aliasToCanonical[id] = canonicalId;
          canonicalToAliases.putIfAbsent(canonicalId, () => []).add(id);
        }
      }
    } catch (_) {}

    String resolveCanonical(String id) {
      final trimmed = id.trim();
      if (aliasToCanonical.containsKey(trimmed)) {
        return aliasToCanonical[trimmed]!;
      }
      final regex = RegExp(r'^lesson_hsk(\d+)_u\d+_l(\d+)$', caseSensitive: false);
      final match = regex.firstMatch(trimmed);
      if (match != null) {
        return 'lesson_${match.group(1)}_${match.group(2)}';
      }
      final regexC = RegExp(r'^c_hsk(\d+)_l(\d+)$', caseSensitive: false);
      final matchC = regexC.firstMatch(trimmed);
      if (matchC != null) {
        return 'lesson_${matchC.group(1)}_${matchC.group(2)}';
      }
      return trimmed;
    }

    for (final r in rows) {
      final progress = LessonProgress.fromMap(r);
      map[progress.lessonId] = progress;

      final canonical = resolveCanonical(progress.lessonId);
      map[canonical] = progress;

      final aliases = canonicalToAliases[canonical] ?? [progress.lessonId];
      for (final alias in aliases) {
        map[alias] = progress;
      }
    }

    try {
      final masteryRows = await _db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_type = ? AND mastery_state = ?',
        whereArgs: ['lesson', 'completed'],
      );
      for (final m in masteryRows) {
        final lId = m['item_id'] as String;
        if (!map.containsKey(lId) || !map[lId]!.isCompleted) {
          final catalogLesson = CurriculumCatalog.findLessonById(lId);
          final p = LessonProgress(
            id: 'prog_$lId',
            lessonId: lId,
            unitId: catalogLesson?.unitId ?? 'unit_1',
            hskLevel: catalogLesson?.level ?? 1,
            status: LessonStatus.completed,
            completionScore: (m['score'] as num?)?.toDouble() ?? 0.8,
            completedAt: DateTime.tryParse(m['updated_at'] as String? ?? ''),
            updatedAt: DateTime.tryParse(m['updated_at'] as String? ?? '') ?? DateTime.now(),
          );
          map[lId] = p;
          final canonical = resolveCanonical(lId);
          map[canonical] = p;
          final aliases = canonicalToAliases[canonical] ?? [lId];
          for (final alias in aliases) {
            map[alias] = p;
          }
        }
      }
    } catch (_) {}

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
    final clampedScore = (score.isNaN || score.isInfinite) ? 0.0 : score.clamp(0.0, 1.0);
    final isPassed = clampedScore >= 0.8;

    await _db.transaction((txn) async {
      // 1. Update lesson progress - only mark completed if passed (score >= 0.8)
      await txn.insert(
        DatabaseConstants.tableLessonProgress,
        {
          'id': 'prog_${lessonId}_${DateTime.now().millisecondsSinceEpoch}',
          'lesson_id': lessonId,
          'unit_id': lesson.unitId,
          'hsk_level': lesson.level,
          'status': isPassed ? LessonStatus.completed.name : LessonStatus.inProgress.name,
          'completion_score': clampedScore,
          'evidence_count': isPassed ? 1 : 0,
          'started_at': nowUtc,
          'completed_at': isPassed ? nowUtc : null,
          'last_studied_at': nowUtc,
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Persist learner evidence only when valid empirical evidence exists
      if (clampedScore > 0.0) {
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
      }

      // 3. Log activity for daily streak only if passed
      if (isPassed) {
        final activityId = 'act_les_${DateTime.now().microsecondsSinceEpoch}';
        await _activityDao.logActivity(
          {
            'id': activityId,
            'activity_type': 'lesson',
            'duration_seconds': lesson.estimatedMinutes * 60,
            'items_count': 1,
            'activity_date': AppClock.todayLocalDateString(),
            'created_at': nowUtc,
            'timezone_offset_minutes': AppClock.currentOffset.inMinutes,
          },
          txn: txn,
        );
      }
    });
  }

  @override
  Future<void> skipLesson(String lessonId) async {
    final lesson = CurriculumCatalog.findLessonById(lessonId);
    if (lesson == null) return;

    final canonicalId = await _identityRegistry.toCanonicalLessonId(lessonId);
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    final existingRows = await _db.query(
      DatabaseConstants.tableLessonProgress,
      where: 'lesson_id = ? OR lesson_id = ?',
      whereArgs: [lessonId, canonicalId],
      limit: 1,
    );

    final createdAt = existingRows.isNotEmpty
        ? (existingRows.first['created_at'] as String? ?? nowUtc)
        : nowUtc;

    await _db.insert(
      DatabaseConstants.tableLessonProgress,
      {
        'id': existingRows.isNotEmpty
            ? existingRows.first['id'] as String
            : 'prog_${lessonId}_${DateTime.now().millisecondsSinceEpoch}',
        'lesson_id': lessonId,
        'unit_id': lesson.unitId,
        'hsk_level': lesson.level,
        'status': LessonStatus.skipped.name,
        'completion_score': 0.0,
        'completed_at': null,
        'last_studied_at': nowUtc,
        'created_at': createdAt,
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
