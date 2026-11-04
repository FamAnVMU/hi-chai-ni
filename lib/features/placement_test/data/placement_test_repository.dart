import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../../../core/utils/app_clock.dart';
import '../../curriculum/data/placement_unlock_handler.dart';
import '../domain/engine/cat_blueprint.dart';
import '../domain/engine/cat_engine.dart';
import '../domain/models/cat_assessment_result.dart';
import '../domain/models/cat_session_state.dart';
import '../domain/models/cat_skill.dart';

/// Repository managing SQLite persistence for adaptive placement test sessions,
/// item responses, and syncing verified diagnostic evidence into `learner_evidence`.
class PlacementTestRepository {
  final Database _db;
  final CatEngine _engine;

  PlacementTestRepository(
    this._db, {
    CatEngine? engine,
  }) : _engine = engine ?? const CatEngine();

  CatEngine get engine => _engine;

  Future<CatSessionState> startNewSession({
    String? customSessionId,
    double? initialTheta,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final sessionId = customSessionId ?? 'CAT_${nowUtc.microsecondsSinceEpoch}';

    final effectiveTheta = initialTheta ?? -1.0;
    final isBeginner = effectiveTheta <= -1.8;
    final initialSkill = isBeginner ? CatSkill.listening : CatSkill.vocabulary;
    final blueprintVer = isBeginner ? 'v1.0-beginner' : _engine.blueprint.version;

    final initialItem = _engine.selectInitialItem(
      initialSkill,
      targetTheta: initialTheta,
    );
    final initialState = CatSessionState.initial(
      sessionId,
      initialSkill: initialSkill,
      initialItem: initialItem,
      initialTheta: effectiveTheta,
      blueprintVersion: blueprintVer,
    );

    await _db.insert(
      DatabaseConstants.tablePlacementTestSessions,
      {
        'id': sessionId,
        'status': 'in_progress',
        'current_step_index': 0,
        'estimated_theta': initialState.currentTheta,
        'standard_error': initialState.currentStandardError,
        'overall_hsk_band': null,
        'confidence_level': 0.0,
        'skill_scores_json': json.encode({}),
        'knowledge_gaps_json': json.encode([]),
        'recommended_level': 1,
        'recommended_roadmap_code': 'HSK_1',
        'blueprint_version': blueprintVer,
        'started_at': nowUtc.toIso8601String(),
        'completed_at': null,
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return initialState;
  }

  /// Retrieves any active, in-progress CAT session to allow seamless resumption.
  Future<CatSessionState?> getActiveSession() async {
    final sessionRows = await _db.query(
      DatabaseConstants.tablePlacementTestSessions,
      where: 'status = ?',
      whereArgs: ['in_progress'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (sessionRows.isEmpty) return null;
    final sRow = sessionRows.first;
    final sessionId = sRow['id'] as String;

    // Load all historical responses for this session
    final respRows = await _db.query(
      DatabaseConstants.tablePlacementTestResponses,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );

    final responses = <CatResponseRecord>[];
    final skillCounts = <CatSkill, int>{for (final s in CatSkill.values) s: 0};

    for (final r in respRows) {
      final skillName = r['skill'] as String;
      final skill = CatSkill.values.firstWhere(
        (s) => s.name == skillName,
        orElse: () => CatSkill.vocabulary,
      );

      skillCounts[skill] = (skillCounts[skill] ?? 0) + 1;

      final subTypeName = r['writing_sub_type'] as String?;
      final spkModeName = r['speaking_evaluation_mode'] as String?;

      responses.add(
        CatResponseRecord(
          itemId: r['item_id'] as String,
          skill: skill,
          writingSubType: subTypeName != null
              ? WritingSubType.values.firstWhere((w) => w.name == subTypeName)
              : null,
          speakingMode: spkModeName != null
              ? SpeakingEvaluationMode.values.firstWhere((m) => m.name == spkModeName)
              : null,
          itemDifficulty: (r['item_difficulty'] as num).toDouble(),
          hskTarget: (r['hsk_target'] as num).toInt(),
          isCalibrationItem: (r['is_calibration_item'] as int) == 1,
          userAnswer: r['user_answer'],
          isCorrect: r['is_correct'] == null ? null : (r['is_correct'] as int) == 1,
          isSkipped: (r['is_skipped'] as int) == 1,
          latencyMs: (r['latency_ms'] as int?) ?? 0,
          timestamp: DateTime.parse(r['created_at'] as String),
        ),
      );
    }

    final currentTheta = (sRow['estimated_theta'] as num).toDouble();
    final currentSe = (sRow['standard_error'] as num).toDouble();
    final startedAt = DateTime.parse(sRow['started_at'] as String);
    final blueprintVer = sRow['blueprint_version'] as String? ?? _engine.blueprint.version;
    final effectiveBlueprint = blueprintVer == 'v1.0-beginner'
        ? const CatBlueprint.beginner()
        : _engine.blueprint;

    // Determine current active skill and select next item
    final usedItemIds = responses.map((r) => r.itemId).toSet();
    CatSkill currentSkill = effectiveBlueprint.skillSequence.first;

    for (final skill in effectiveBlueprint.skillSequence) {
      final count = skillCounts[skill] ?? 0;
      if (count < effectiveBlueprint.minItemsPerSkill) {
        currentSkill = skill;
        break;
      }
      if (count < effectiveBlueprint.maxItemsPerSkill) {
        currentSkill = skill;
        break;
      }
    }

    final activeItem = _engine.selectNextItem(
      currentSkill: currentSkill,
      currentTheta: currentTheta,
      usedItemIds: usedItemIds,
    ) ?? _engine.selectInitialItem(currentSkill, targetTheta: currentTheta);

    return CatSessionState(
      sessionId: sessionId,
      status: 'in_progress',
      currentSkill: currentSkill,
      activeItem: activeItem,
      stepIndex: responses.length,
      skillItemCounts: skillCounts,
      currentTheta: currentTheta,
      currentStandardError: currentSe,
      responses: responses,
      startedAt: startedAt,
      blueprintVersion: blueprintVer,
    );
  }

  /// Persists an individual turn response and updates the session metadata in SQLite.
  Future<void> saveTurnResponse({
    required String sessionId,
    required CatResponseRecord response,
    required double updatedTheta,
    required double updatedSe,
    required int stepIndex,
  }) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    await _db.transaction((txn) async {
      await txn.insert(
        DatabaseConstants.tablePlacementTestResponses,
        response.toMap(sessionId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.update(
        DatabaseConstants.tablePlacementTestSessions,
        {
          'current_step_index': stepIndex,
          'estimated_theta': updatedTheta,
          'standard_error': updatedSe,
          'updated_at': nowUtc,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  /// Finalizes the session, saving full diagnostic assessment results and recording
  /// verified diagnostic learning evidence into `learner_evidence`.
  Future<void> finalizeSession({
    required CatSessionState sessionState,
    required CatAssessmentResult result,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final nowUtcStr = nowUtc.toIso8601String();

    final skillScoresMap = {
      for (final entry in result.skillScores.entries)
        entry.key.name: entry.value.toMap(),
    };

    final gapsList = result.knowledgeGaps.map((g) => g.toMap()).toList();

    await _db.transaction((txn) async {
      // 1. Update session status to completed
      await txn.update(
        DatabaseConstants.tablePlacementTestSessions,
        {
          'status': 'completed',
          'current_step_index': sessionState.responses.length,
          'estimated_theta': result.overallTheta,
          'standard_error': result.overallStandardError,
          'overall_hsk_band': result.referenceHskBand,
          'confidence_level': result.confidenceScore,
          'skill_scores_json': json.encode(skillScoresMap),
          'knowledge_gaps_json': json.encode(gapsList),
          'recommended_level': result.recommendedHskLevel,
          'recommended_roadmap_code': result.recommendedRoadmapCode,
          'completed_at': nowUtcStr,
          'updated_at': nowUtcStr,
        },
        where: 'id = ?',
        whereArgs: [sessionState.sessionId],
      );

      // 2. Persist verified evidence in learner_evidence (source: 'cat_placement_test')
      for (final resp in sessionState.responses) {
        if (!resp.isSkipped && resp.isCorrect != null) {
          final evidenceId = 'EVI_CAT_${nowUtc.microsecondsSinceEpoch}_${resp.itemId}';
          await txn.insert(
            DatabaseConstants.tableLearnerEvidence,
            {
              'id': evidenceId,
              'content_id': resp.itemId,
              'content_type': 'placement_${resp.skill.name}',
              'source': 'cat_placement_test',
              'score': resp.isCorrect! ? 1.0 : 0.0,
              'duration_ms': resp.latencyMs,
              'metadata_json': json.encode({
                'session_id': sessionState.sessionId,
                'difficulty': resp.itemDifficulty,
                'skill': resp.skill.name,
                'writing_sub_type': resp.writingSubType?.name,
                'speaking_mode': resp.speakingMode?.name,
              }),
              'created_at': nowUtcStr,
            },
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }

      // 3. Log activity in learning_activities
      final durationSec = sessionState.responses.fold<int>(
        0,
        (acc, r) => acc + (r.latencyMs / 1000).round(),
      );

      await txn.insert(
        DatabaseConstants.tableLearningActivities,
        {
          'id': 'ACT_${nowUtc.microsecondsSinceEpoch}',
          'activity_type': 'cat_placement_test',
          'duration_seconds': durationSec > 0 ? durationSec : 300,
          'items_count': sessionState.responses.length,
          'activity_date': AppClock.todayLocalDateString(),
          'created_at': nowUtcStr,
          'timezone_offset_minutes': AppClock.currentOffset.inMinutes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 4. Activate PlacementUnlockHandler to unlock recommended level and auto-credit prior lessons
      try {
        final unlockHandler = PlacementUnlockHandler(txn);
        await unlockHandler.unlockForRecommendedLevel(result.recommendedHskLevel);
      } catch (e) {
        debugPrint('[PlacementTestRepository] Warning: PlacementUnlockHandler failed: $e');
      }
    });
  }

  /// Retrieves the most recent completed assessment result for review.
  Future<CatAssessmentResult?> getLatestCompletedResult() async {
    final rows = await _db.query(
      DatabaseConstants.tablePlacementTestSessions,
      where: 'status = ?',
      whereArgs: ['completed'],
      orderBy: 'completed_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final row = rows.first;

    final sessionId = row['id'] as String;
    final theta = (row['estimated_theta'] as num).toDouble();
    final se = (row['standard_error'] as num).toDouble();
    final hskBand = row['overall_hsk_band'] as String? ?? 'HSK 1';
    final confScore = (row['confidence_level'] as num).toDouble();
    final completedAt = DateTime.parse(row['completed_at'] as String);
    final recLevel = (row['recommended_level'] as num).toInt();
    final recRoadmap = row['recommended_roadmap_code'] as String? ?? 'HSK_1';
    final blueprintVer = row['blueprint_version'] as String? ?? 'v1.0';

    final skillScoresRaw = json.decode(row['skill_scores_json'] as String) as Map<String, dynamic>;
    final skillScores = <CatSkill, SkillScoreEstimate>{};
    for (final entry in skillScoresRaw.entries) {
      final skill = CatSkill.values.firstWhere(
        (s) => s.name == entry.key,
        orElse: () => CatSkill.vocabulary,
      );
      skillScores[skill] = SkillScoreEstimate.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }

    final gapsRaw = json.decode(row['knowledge_gaps_json'] as String) as List<dynamic>;
    final gaps = gapsRaw
        .map((g) => KnowledgeGapItem.fromMap(Map<String, dynamic>.from(g as Map)))
        .toList();

    return CatAssessmentResult(
      sessionId: sessionId,
      overallTheta: theta,
      overallStandardError: se,
      referenceHskBand: hskBand,
      confidenceScore: confScore,
      skillScores: skillScores,
      knowledgeGaps: gaps,
      recommendedHskLevel: recLevel,
      recommendedRoadmapTitle: 'Lộ trình gợi ý: HSK $recLevel',
      recommendedRoadmapCode: recRoadmap,
      completedAt: completedAt,
      blueprintVersion: blueprintVer,
    );
  }

  /// Abandons an active session so user can start fresh.
  Future<void> abandonSession(String sessionId) async {
    await _db.update(
      DatabaseConstants.tablePlacementTestSessions,
      {
        'status': 'abandoned',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }
}
