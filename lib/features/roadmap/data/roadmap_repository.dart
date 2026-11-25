import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/activity_dao.dart';
import '../../../../core/database/dao/curriculum_dao.dart';
import '../../../../core/database/dao/learner_evidence_dao.dart';
import '../../../../core/database/database_constants.dart';
import '../../../../core/knowledge/domain/services/knowledge_identity_registry.dart';
import '../../../../core/utils/app_clock.dart';
import '../../curriculum/domain/constants/curriculum_constants.dart';
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
  late final CurriculumDao _curriculumDao;
  late final KnowledgeIdentityRegistry _identityRegistry;
  final AdaptiveRoadmapEngine engine;

  DefaultRoadmapRepository(
    this._db, {
    this.engine = const AdaptiveRoadmapEngine(),
    KnowledgeIdentityRegistry? identityRegistry,
  })  : _evidenceDao = LearnerEvidenceDao(_db),
        _activityDao = ActivityDao(_db),
        _curriculumDao = CurriculumDao(_db),
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

      // Synchronize user_profiles so Home, SRS, and Profile stay aligned with active goal
      try {
        await txn.update(
          DatabaseConstants.tableUserProfiles,
          {
            'target_hsk_level': goal.targetHskLevel,
            'daily_minutes': goal.dailyMinutes,
            'purpose': goal.purpose.name,
            'updated_at': nowUtc,
          },
        );
      } catch (_) {}
    });
  }

  /// Resolves lesson metadata directly from SQLite curriculum tables first,
  /// falling back to [CurriculumCatalog] only for legacy synthetic unit-test IDs.
  Future<RoadmapLesson?> _resolveLessonMetadata(String lessonId) async {
    try {
      final rows = await _db.rawQuery('''
        SELECT
          l.id,
          l.unit_id,
          l.order_index,
          l.title_vi,
          l.title_zh,
          l.pinyin,
          l.estimated_minutes,
          l.prerequisites_json,
          c.hsk_level
        FROM ${DatabaseConstants.tableCurriculumLessons} l
        LEFT JOIN ${DatabaseConstants.tableCurriculumUnits} u ON l.unit_id = u.id
        LEFT JOIN ${DatabaseConstants.tableCurriculums} c ON u.curriculum_id = c.id
        WHERE l.id = ?
        LIMIT 1
      ''', [lessonId]);

      if (rows.isNotEmpty) {
        final r = rows.first;
        final orderIdx = (r['order_index'] as num?)?.toInt() ?? 1;
        final hskLevel = (r['hsk_level'] as num?)?.toInt() ?? 1;
        final titleVi = (r['title_vi'] as String? ?? '').trim();
        final titleZh = (r['title_zh'] as String? ?? '').trim();
        final pinyin = (r['pinyin'] as String? ?? '').trim();
        return RoadmapLesson(
          id: r['id'] as String,
          unitId: r['unit_id'] as String? ?? 'unit_1',
          level: hskLevel,
          title: titleVi.isNotEmpty ? titleVi : 'Bài $orderIdx (HSK $hskLevel)',
          description: [titleZh, pinyin].where((s) => s.isNotEmpty).join(' • '),
          primarySkill: _inferPrimarySkill(orderIdx, titleVi),
          estimatedMinutes: (r['estimated_minutes'] as num?)?.toInt() ?? 15,
          prerequisiteLessonIds: _parsePrerequisitesJson(r['prerequisites_json']),
          contentReferences: {'lesson_id': r['id'] as String},
        );
      }
    } catch (_) {}
    return CurriculumCatalog.findLessonById(lessonId);
  }

  static List<String> _parsePrerequisitesJson(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return const [];
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
    } catch (_) {}
    return const [];
  }

  static SkillDimension _inferPrimarySkill(int orderIndex, String titleVi) {
    final lower = titleVi.toLowerCase();
    if (lower.contains('viết') || lower.contains('nét') || lower.contains('chữ hán')) {
      return SkillDimension.writing;
    }
    if (lower.contains('nghe') || lower.contains('phát âm') || lower.contains('thanh điệu')) {
      return SkillDimension.listening;
    }
    if (lower.contains('đọc')) {
      return SkillDimension.reading;
    }
    if (lower.contains('ngữ pháp')) {
      return SkillDimension.grammar;
    }
    if (lower.contains('nói') || lower.contains('giao tiếp') || lower.contains('hội thoại')) {
      return SkillDimension.speaking;
    }
    const cycle = [
      SkillDimension.vocabulary,
      SkillDimension.grammar,
      SkillDimension.reading,
      SkillDimension.speaking,
      SkillDimension.listening,
      SkillDimension.writing,
    ];
    return cycle[(orderIndex - 1).abs() % cycle.length];
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
          final catalogLesson = await _resolveLessonMetadata(lId);
          final p = LessonProgress(
            id: 'prog_$lId',
            lessonId: lId,
            unitId: catalogLesson?.unitId ?? 'unit_1',
            hskLevel: catalogLesson?.level ?? 1,
            status: RoadmapLessonStatus.completed,
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
    final lesson = await _resolveLessonMetadata(lessonId);
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
          'status': RoadmapLessonStatus.inProgress.name,
          'evidence_count': 0,
          'source': 'curriculum_lesson',
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
            'status': RoadmapLessonStatus.inProgress.name,
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
    final lesson = await _resolveLessonMetadata(lessonId);
    if (lesson == null) return;

    final canonicalId = await _identityRegistry.toCanonicalLessonId(lessonId);
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final clampedScore = (score.isNaN || score.isInfinite) ? 0.0 : score.clamp(0.0, 1.0);
    final isPassed = clampedScore >= 0.8;

    await _db.transaction((txn) async {
      final existingRows = await txn.query(
        DatabaseConstants.tableLessonProgress,
        where: 'lesson_id = ? OR lesson_id = ?',
        whereArgs: [lessonId, canonicalId],
        limit: 1,
      );
      final existingId = existingRows.isNotEmpty
          ? existingRows.first['id'] as String
          : 'prog_${lessonId}_${DateTime.now().millisecondsSinceEpoch}';
      final existingStartedAt = existingRows.isNotEmpty
          ? (existingRows.first['started_at'] as String? ?? nowUtc)
          : nowUtc;
      final existingCreatedAt = existingRows.isNotEmpty
          ? (existingRows.first['created_at'] as String? ?? nowUtc)
          : nowUtc;
      final existingEvidence = existingRows.isNotEmpty
          ? ((existingRows.first['evidence_count'] as num?)?.toInt() ?? 0)
          : 0;

      // 1. Update lesson progress - only mark completed if passed (score >= 0.8)
      await txn.insert(
        DatabaseConstants.tableLessonProgress,
        {
          'id': existingId,
          'lesson_id': lessonId,
          'unit_id': lesson.unitId,
          'hsk_level': lesson.level,
          'status': isPassed ? RoadmapLessonStatus.completed.name : RoadmapLessonStatus.inProgress.name,
          'completion_score': clampedScore,
          'evidence_count': isPassed ? (existingEvidence + 1) : existingEvidence,
          'source': 'curriculum_lesson',
          'started_at': existingStartedAt,
          'completed_at': isPassed ? nowUtc : null,
          'last_studied_at': nowUtc,
          'created_at': existingCreatedAt,
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Sync SQLite curriculum_lessons & curriculum_mastery when row exists
      try {
        await txn.update(
          DatabaseConstants.tableCurriculumLessons,
          {
            'status': isPassed ? 'completed' : 'in_progress',
            if (isPassed) 'completed_at': nowUtc,
          },
          where: 'id = ?',
          whereArgs: [lessonId],
        );
      } catch (_) {}

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
    final lesson = await _resolveLessonMetadata(lessonId);
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
        'status': RoadmapLessonStatus.skipped.name,
        'completion_score': 0.0,
        'source': 'curriculum_lesson',
        'completed_at': null,
        'last_studied_at': nowUtc,
        'created_at': createdAt,
        'updated_at': nowUtc,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<int, CurriculumLevel>> _loadSqliteLevels({
    required Map<String, LessonProgress> progressMap,
  }) async {
    final result = <int, CurriculumLevel>{};
    for (int lvl = 1; lvl <= 6; lvl++) {
      final currId = CurriculumConstants.curriculumIdForLevel(lvl);
      final rows = await _curriculumDao.getLessonsSummaryByCurriculumId(currId);
      if (rows.isEmpty) {
        result[lvl] = CurriculumLevel(
          level: lvl,
          title: 'Giáo trình HSK $lvl',
          description: 'Chưa tải gói học liệu HSK $lvl về máy.',
          units: const [],
          isPackInstalled: false,
        );
        continue;
      }

      final unitOrder = <String>[];
      final unitMeta = <String, Map<String, dynamic>>{};
      final unitLessons = <String, List<RoadmapLesson>>{};

      for (final r in rows) {
        final unitId = r['unit_id'] as String?;
        if (unitId == null) continue;
        if (!unitMeta.containsKey(unitId)) {
          unitOrder.add(unitId);
          unitMeta[unitId] = r;
          unitLessons[unitId] = <RoadmapLesson>[];
        }

        final lessonId = r['lesson_id'] as String?;
        if (lessonId != null) {
          final orderIdx = (r['lesson_order_index'] as num?)?.toInt() ?? 1;
          final titleVi = (r['lesson_title_vi'] as String? ?? '').trim();
          final titleZh = (r['lesson_title_zh'] as String? ?? '').trim();
          final pinyin = (r['lesson_pinyin'] as String? ?? '').trim();
          final prereqs = _parsePrerequisitesJson(r['lesson_prerequisites_json']);

          unitLessons[unitId]!.add(
            RoadmapLesson(
              id: lessonId,
              unitId: unitId,
              level: lvl,
              title: titleVi.isNotEmpty ? titleVi : 'Bài $orderIdx',
              description: [titleZh, pinyin].where((s) => s.isNotEmpty).join(' • '),
              primarySkill: _inferPrimarySkill(orderIdx, titleVi),
              estimatedMinutes: (r['lesson_estimated_minutes'] as num?)?.toInt() ?? 15,
              prerequisiteLessonIds: prereqs,
              contentReferences: {
                'curriculum_id': currId,
                'lesson_id': lessonId,
              },
            ),
          );

          // Synchronize SQLite lesson status into progressMap if not already richer
          final sqlStatus = (r['lesson_status'] as String? ?? 'not_started').toLowerCase();
          final sqlScore = (r['mastery_score'] as num?)?.toDouble();
          final existingProg = progressMap[lessonId];
          final mappedStatus = switch (sqlStatus) {
            'completed' || 'mastered' => RoadmapLessonStatus.completed,
            'in_progress' => RoadmapLessonStatus.inProgress,
            _ => (r['lesson_is_locked'] == 0 || r['lesson_is_locked'] == true)
                ? RoadmapLessonStatus.available
                : RoadmapLessonStatus.locked,
          };

          if (existingProg == null ||
              (mappedStatus == RoadmapLessonStatus.completed && !existingProg.isCompleted)) {
            progressMap[lessonId] = LessonProgress(
              id: existingProg?.id ?? 'prog_$lessonId',
              lessonId: lessonId,
              unitId: unitId,
              hskLevel: lvl,
              status: mappedStatus,
              completionScore: existingProg?.completionScore ??
                  ((sqlScore != null && sqlScore > 0) ? sqlScore : null),
              completedAt: r['lesson_completed_at'] != null
                  ? DateTime.tryParse(r['lesson_completed_at'] as String)
                  : existingProg?.completedAt,
              updatedAt: existingProg?.updatedAt ?? DateTime.now().toUtc(),
            );
          }
        }
      }

      final units = unitOrder.map((uId) {
        final uRow = unitMeta[uId]!;
        return RoadmapUnit(
          id: uId,
          level: lvl,
          unitNumber: (uRow['unit_order_index'] as num?)?.toInt() ?? 1,
          title: (uRow['unit_title_vi'] as String? ?? '').trim(),
          description: (uRow['unit_description_vi'] as String? ?? '').trim(),
          lessons: unitLessons[uId] ?? const [],
        );
      }).toList();

      result[lvl] = CurriculumLevel(
        level: lvl,
        title: 'Giáo trình HSK $lvl',
        description: 'Toàn bộ bài học chuẩn HSK $lvl đã cài trên thiết bị.',
        units: units,
        isPackInstalled: true,
      );
    }
    return result;
  }

  @override
  Future<LearnerRoadmapState> getAdaptiveRoadmapState() async {
    final goal = await getActiveGoal();
    final progressMap = await getLessonProgressMap();
    final levelsByHsk = await _loadSqliteLevels(progressMap: progressMap);

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

    final targetLvlData = levelsByHsk[goal.targetHskLevel];
    // For HSK 3+, never fall back to static HSK 0 Pinyin; for HSK 1-2 use SQLite if installed,
    // or static catalog fallback only if SQLite curriculum tables are completely unseeded.
    final effectiveLevelData = (targetLvlData != null &&
            (targetLvlData.isPackInstalled || goal.targetHskLevel >= 3))
        ? targetLvlData
        : null;

    // 4. Generate recommendations via AdaptiveRoadmapEngine (read-only, no snapshot bloat!)
    final context = AdaptiveRoadmapContext(
      goal: goal,
      currentLevel: goal.targetHskLevel,
      levelData: effectiveLevelData,
      levelsByHsk: levelsByHsk,
      progressMap: progressMap,
      skillMasteryScores: placementSkillScores,
      identifiedKnowledgeGaps: knowledgeGaps,
      srsLapseCount: srsLapses,
      recentEvidence: recentEvidence,
    );

    return engine.generateRoadmap(context);
  }
}
