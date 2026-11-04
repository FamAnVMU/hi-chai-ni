import 'package:flutter/foundation.dart';
import 'cat_assessment_result.dart';
import 'cat_item.dart';
import 'cat_skill.dart';

/// An individual response recorded during the adaptive testing session.
@immutable
class CatResponseRecord {
  final String itemId;
  final CatSkill skill;
  final WritingSubType? writingSubType;
  final SpeakingEvaluationMode? speakingMode;
  final double itemDifficulty;
  final int hskTarget;
  final bool isCalibrationItem;
  final dynamic userAnswer;
  final bool? isCorrect;
  final bool isSkipped;
  final int latencyMs;
  final DateTime timestamp;

  const CatResponseRecord({
    required this.itemId,
    required this.skill,
    this.writingSubType,
    this.speakingMode,
    required this.itemDifficulty,
    required this.hskTarget,
    this.isCalibrationItem = false,
    this.userAnswer,
    this.isCorrect,
    this.isSkipped = false,
    this.latencyMs = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toMap(String sessionId) => {
        'id': 'RESP_${timestamp.microsecondsSinceEpoch}_$itemId',
        'session_id': sessionId,
        'item_id': itemId,
        'skill': skill.name,
        'writing_sub_type': writingSubType?.name,
        'speaking_evaluation_mode': speakingMode?.name,
        'item_difficulty': itemDifficulty,
        'hsk_target': hskTarget,
        'is_calibration_item': isCalibrationItem ? 1 : 0,
        'user_answer': userAnswer?.toString(),
        'is_correct': isCorrect == null ? null : (isCorrect! ? 1 : 0),
        'is_skipped': isSkipped ? 1 : 0,
        'latency_ms': latencyMs,
        'created_at': timestamp.toIso8601String(),
      };
}

/// Immutable snapshot representing an active or completed CAT assessment session.
@immutable
class CatSessionState {
  final String sessionId;
  final String status; // 'in_progress', 'completed', 'abandoned'
  final CatSkill currentSkill;
  final CatItem? activeItem;
  final int stepIndex; // 0-based total items presented
  final Map<CatSkill, int> skillItemCounts;
  final double currentTheta;
  final double currentStandardError;
  final List<CatResponseRecord> responses;
  final bool isCompleted;
  final CatAssessmentResult? result;
  final DateTime startedAt;
  final String blueprintVersion;

  const CatSessionState({
    required this.sessionId,
    required this.status,
    required this.currentSkill,
    this.activeItem,
    required this.stepIndex,
    required this.skillItemCounts,
    required this.currentTheta,
    required this.currentStandardError,
    required this.responses,
    this.isCompleted = false,
    this.result,
    required this.startedAt,
    this.blueprintVersion = 'v1.0',
  });

  bool get isBeginnerMode => blueprintVersion == 'v1.0-beginner';

  factory CatSessionState.initial(
    String sessionId, {
    CatItem? initialItem,
    CatSkill initialSkill = CatSkill.vocabulary,
    double initialTheta = -1.0,
    double initialStandardError = 1.2,
    String blueprintVersion = 'v1.0',
  }) =>
      CatSessionState(
        sessionId: sessionId,
        status: 'in_progress',
        currentSkill: initialSkill,
        activeItem: initialItem,
        stepIndex: 0,
        skillItemCounts: {for (final s in CatSkill.values) s: 0},
        currentTheta: initialTheta,
        currentStandardError: initialStandardError,
        responses: const [],
        isCompleted: false,
        startedAt: DateTime.now().toUtc(),
        blueprintVersion: blueprintVersion,
      );

  CatSessionState copyWith({
    String? status,
    CatSkill? currentSkill,
    CatItem? activeItem,
    bool clearActiveItem = false,
    int? stepIndex,
    Map<CatSkill, int>? skillItemCounts,
    double? currentTheta,
    double? currentStandardError,
    List<CatResponseRecord>? responses,
    bool? isCompleted,
    CatAssessmentResult? result,
    String? blueprintVersion,
  }) {
    return CatSessionState(
      sessionId: sessionId,
      status: status ?? this.status,
      currentSkill: currentSkill ?? this.currentSkill,
      activeItem: clearActiveItem ? null : (activeItem ?? this.activeItem),
      stepIndex: stepIndex ?? this.stepIndex,
      skillItemCounts: skillItemCounts ?? this.skillItemCounts,
      currentTheta: currentTheta ?? this.currentTheta,
      currentStandardError: currentStandardError ?? this.currentStandardError,
      responses: responses ?? this.responses,
      isCompleted: isCompleted ?? this.isCompleted,
      result: result ?? this.result,
      startedAt: startedAt,
      blueprintVersion: blueprintVersion ?? this.blueprintVersion,
    );
  }
}
