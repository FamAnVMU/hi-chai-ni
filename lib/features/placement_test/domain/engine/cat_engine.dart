import 'dart:math' as math;
import '../models/cat_assessment_result.dart';
import '../models/cat_item.dart';
import '../models/cat_session_state.dart';
import '../models/cat_skill.dart';
import 'cat_blueprint.dart';
import 'cat_item_bank.dart';

/// Pure-Dart Computerized Adaptive Testing (CAT) Engine implementing Item Response Theory
/// (1PL / 2PL Logistic Models), Fisher Information routing, and calibrated stopping rules.
class CatEngine {
  final CatBlueprint blueprint;
  final List<CatItem> itemBank;

  const CatEngine({
    this.blueprint = const CatBlueprint(),
    this.itemBank = CatItemBank.defaultItems,
  });

  /// Computes the 2PL probability of a correct response $P(\theta)$ given ability $\theta$,
  /// item difficulty $b$, and discrimination $a$.
  static double calculateProbability(double theta, double difficulty, double discrimination) {
    final exponent = -discrimination * (theta - difficulty);
    if (exponent > 40) return 0.0;
    if (exponent < -40) return 1.0;
    return 1.0 / (1.0 + math.exp(exponent));
  }

  /// Computes Fisher Information $I(\theta) = a^2 P(1 - P)$.
  static double calculateInformation(double theta, double difficulty, double discrimination) {
    final p = calculateProbability(theta, difficulty, discrimination);
    return discrimination * discrimination * p * (1.0 - p);
  }

  CatItem? selectInitialItem(CatSkill skill, {double? targetTheta}) {
    final available = itemBank.where((i) => i.skill == skill).toList();
    if (available.isEmpty) return null;

    if (targetTheta != null) {
      available.sort((a, b) {
        final diffA = (a.difficulty - targetTheta).abs();
        final diffB = (b.difficulty - targetTheta).abs();
        return diffA.compareTo(diffB);
      });
      return available.first;
    }

    for (final item in available) {
      if (item.isCalibration && item.difficulty <= -1.0) {
        return item;
      }
    }
    return available.first;
  }

  /// Selects the optimal next item in [currentSkill] that maximizes Fisher Information at [currentTheta].
  CatItem? selectNextItem({
    required CatSkill currentSkill,
    required double currentTheta,
    required Set<String> usedItemIds,
  }) {
    final candidates = itemBank.where(
      (item) => item.skill == currentSkill && !usedItemIds.contains(item.id),
    ).toList();

    if (candidates.isEmpty) return null;

    // Pick item with difficulty closest to current theta (maximizes Fisher information)
    candidates.sort((a, b) {
      final diffA = (a.difficulty - currentTheta).abs();
      final diffB = (b.difficulty - currentTheta).abs();
      return diffA.compareTo(diffB);
    });

    return candidates.first;
  }

  /// Processes a learner's answer turn, updating ability $\theta$, standard error $SE$,
  /// evaluating stopping rules, and advancing to the next item or skill.
  CatSessionState processTurn({
    required CatSessionState currentState,
    required dynamic userAnswer,
    required int latencyMs,
    bool isSkipped = false,
  }) {
    final activeItem = currentState.activeItem;
    if (activeItem == null || currentState.isCompleted) {
      return currentState;
    }

    final isCorrect = isSkipped ? null : activeItem.checkAnswer(userAnswer);

    // 1. Record response
    final responseRecord = CatResponseRecord(
      itemId: activeItem.id,
      skill: activeItem.skill,
      writingSubType: activeItem.writingSubType,
      speakingMode: activeItem.speakingMode,
      itemDifficulty: activeItem.difficulty,
      hskTarget: activeItem.hskLevel,
      isCalibrationItem: activeItem.isCalibration,
      userAnswer: userAnswer,
      isCorrect: isCorrect,
      isSkipped: isSkipped,
      latencyMs: latencyMs,
      timestamp: DateTime.now().toUtc(),
    );

    final updatedResponses = List<CatResponseRecord>.from(currentState.responses)..add(responseRecord);

    // 2. Update skill item counts
    final currentSkill = currentState.currentSkill;
    final updatedSkillCounts = Map<CatSkill, int>.from(currentState.skillItemCounts);
    updatedSkillCounts[currentSkill] = (updatedSkillCounts[currentSkill] ?? 0) + 1;

    // 3. Update latent ability $\theta$ and standard error $SE$ via 2PL Newton-Raphson / bounded step
    double newTheta = currentState.currentTheta;
    double newSe = currentState.currentStandardError;

    if (!isSkipped && isCorrect != null) {
      final p = calculateProbability(newTheta, activeItem.difficulty, activeItem.discrimination);
      final x = isCorrect ? 1.0 : 0.0;
      final info = calculateInformation(newTheta, activeItem.difficulty, activeItem.discrimination);

      // Bounded theta adjustment step $\Delta\theta$
      final step = ((x - p) / (activeItem.discrimination * p * (1.0 - p))).clamp(-0.6, 0.6);
      newTheta = (newTheta + step).clamp(-3.0, 3.0);

      // Cumulative Fisher information update
      final currentTotalInfo = 1.0 / (currentState.currentStandardError * currentState.currentStandardError);
      final updatedTotalInfo = currentTotalInfo + info;
      newSe = (1.0 / math.sqrt(updatedTotalInfo)).clamp(0.2, 1.5);
    }

    final usedItemIds = updatedResponses.map((r) => r.itemId).toSet();

    // Determine active blueprint based on session configuration
    final activeBlueprint = _resolveBlueprint(currentState);

    // 4. Evaluate stopping rule for current skill
    final shouldStopCurrentSkill = isSkipped || _evaluateSkillStopRule(
      currentSkill: currentSkill,
      skillItemCount: updatedSkillCounts[currentSkill] ?? 0,
      skillSe: newSe,
      responses: updatedResponses,
      blueprint: activeBlueprint,
    );

    if (shouldStopCurrentSkill) {
      // Find next skill in sequence
      final nextSkill = _findNextSkill(currentSkill, blueprint: activeBlueprint);

      if (nextSkill == null || updatedResponses.length >= activeBlueprint.maxTotalItems) {
        // Complete test!
        final finalResult = generateAssessmentResult(
          sessionId: currentState.sessionId,
          overallTheta: newTheta,
          overallStandardError: newSe,
          responses: updatedResponses,
          completedAt: DateTime.now().toUtc(),
          blueprintVersion: activeBlueprint.version,
        );

        return currentState.copyWith(
          status: 'completed',
          isCompleted: true,
          currentTheta: newTheta,
          currentStandardError: newSe,
          responses: updatedResponses,
          skillItemCounts: updatedSkillCounts,
          clearActiveItem: true,
          result: finalResult,
        );
      } else {
        // Advance to next skill
        final nextItem = selectInitialItem(nextSkill, targetTheta: newTheta);
        return currentState.copyWith(
          currentSkill: nextSkill,
          activeItem: nextItem,
          stepIndex: currentState.stepIndex + 1,
          currentTheta: newTheta,
          currentStandardError: newSe,
          responses: updatedResponses,
          skillItemCounts: updatedSkillCounts,
        );
      }
    } else {
      // Continue within same skill
      final nextItem = selectNextItem(
        currentSkill: currentSkill,
        currentTheta: newTheta,
        usedItemIds: usedItemIds,
      );

      if (nextItem == null) {
        // Skill items exhausted early -> advance to next skill
        final nextSkill = _findNextSkill(currentSkill, blueprint: activeBlueprint);
        if (nextSkill == null || updatedResponses.length >= activeBlueprint.minTotalItems) {
          final finalResult = generateAssessmentResult(
            sessionId: currentState.sessionId,
            overallTheta: newTheta,
            overallStandardError: newSe,
            responses: updatedResponses,
            completedAt: DateTime.now().toUtc(),
            blueprintVersion: activeBlueprint.version,
          );
          return currentState.copyWith(
            status: 'completed',
            isCompleted: true,
            currentTheta: newTheta,
            currentStandardError: newSe,
            responses: updatedResponses,
            skillItemCounts: updatedSkillCounts,
            clearActiveItem: true,
            result: finalResult,
          );
        }
        return currentState.copyWith(
          currentSkill: nextSkill,
          activeItem: selectInitialItem(nextSkill, targetTheta: newTheta),
          stepIndex: currentState.stepIndex + 1,
          currentTheta: newTheta,
          currentStandardError: newSe,
          responses: updatedResponses,
          skillItemCounts: updatedSkillCounts,
        );
      }

      return currentState.copyWith(
        activeItem: nextItem,
        stepIndex: currentState.stepIndex + 1,
        currentTheta: newTheta,
        currentStandardError: newSe,
        responses: updatedResponses,
        skillItemCounts: updatedSkillCounts,
      );
    }
  }

  CatBlueprint _resolveBlueprint(CatSessionState state) {
    if (state.isBeginnerMode || (state.currentTheta <= -1.8 && state.stepIndex == 0)) {
      return const CatBlueprint.beginner();
    }
    return blueprint;
  }

  /// Evaluates stopping rule for a given skill.
  bool _evaluateSkillStopRule({
    required CatSkill currentSkill,
    required int skillItemCount,
    required double skillSe,
    required List<CatResponseRecord> responses,
    CatBlueprint? blueprint,
  }) {
    final bp = blueprint ?? this.blueprint;
    if (skillItemCount < bp.minItemsPerSkill) {
      return false;
    }
    if (skillItemCount >= bp.maxItemsPerSkill) {
      return true;
    }

    // Early termination: Target SE achieved
    if (skillSe <= bp.targetStandardError) {
      return true;
    }

    // Early termination: 3 consecutive failures in this skill
    final skillResponses = responses.where((r) => r.skill == currentSkill).toList();
    if (skillResponses.length >= bp.maxConsecutiveLowestFailures) {
      final lastThree = skillResponses.sublist(skillResponses.length - bp.maxConsecutiveLowestFailures);
      final allFailed = lastThree.every((r) => r.isCorrect == false);
      if (allFailed) return true;
    }

    return false;
  }

  CatSkill? _findNextSkill(CatSkill currentSkill, {CatBlueprint? blueprint}) {
    final seq = (blueprint ?? this.blueprint).skillSequence;
    final currentIndex = seq.indexOf(currentSkill);
    if (currentIndex == -1 || currentIndex >= seq.length - 1) {
      return null;
    }
    return seq[currentIndex + 1];
  }

  /// Synthesizes complete pedagogical diagnostic report from all responses.
  CatAssessmentResult generateAssessmentResult({
    required String sessionId,
    required double overallTheta,
    required double overallStandardError,
    required List<CatResponseRecord> responses,
    required DateTime completedAt,
    String? blueprintVersion,
  }) {
    final skillScores = <CatSkill, SkillScoreEstimate>{};
    final knowledgeGaps = <KnowledgeGapItem>[];

    for (final skill in CatSkill.values) {
      final skillResponses = responses.where((r) => r.skill == skill).toList();

      if (skillResponses.isEmpty || skillResponses.every((r) => r.isSkipped)) {
        // Skill unassessed: MUST NOT be scored as zero (0)
        skillScores[skill] = SkillScoreEstimate.unassessed(
          skill,
          reason: skill == CatSkill.speaking
              ? 'Chưa đủ dữ liệu đánh giá phát âm'
              : 'Học viên đã bỏ qua phần này',
        );
        continue;
      }

      final attempted = skillResponses.where((r) => !r.isSkipped).toList();
      final correctCount = attempted.where((r) => r.isCorrect == true).length;
      final accuracy = attempted.isEmpty ? 0.0 : correctCount / attempted.length;

      // Calculate skill specific theta
      double skillTheta = overallTheta;
      final subMetrics = <String, dynamic>{};

      if (skill == CatSkill.listening) {
        // Acoustic Sensitivity (tone discrimination & pinyin sound-to-symbol)
        final acousticResponses = attempted.where((r) =>
          r.itemId.startsWith('TONE_') ||
          r.itemId.startsWith('PIN_') ||
          (r.skill == CatSkill.listening && r.itemDifficulty <= -1.5)
        ).toList();
        if (acousticResponses.isNotEmpty) {
          final correctAcoustic = acousticResponses.where((r) => r.isCorrect == true).length;
          subMetrics['acoustic_sensitivity_accuracy'] = correctAcoustic / acousticResponses.length;
        }
      } else if (skill == CatSkill.writing) {
        // Separate sub-metrics for writing: Never mix recognition, pinyin, and stroke scores
        final recResponses = attempted.where((r) => r.writingSubType == WritingSubType.characterRecognition).toList();
        final pinResponses = attempted.where((r) => r.writingSubType == WritingSubType.pinyinTranscription).toList();
        final strResponses = attempted.where((r) => r.writingSubType == WritingSubType.strokeOrderWriting).toList();

        subMetrics['character_recognition_accuracy'] = recResponses.isEmpty ? null : (recResponses.where((r) => r.isCorrect == true).length / recResponses.length);
        subMetrics['pinyin_transcription_accuracy'] = pinResponses.isEmpty ? null : (pinResponses.where((r) => r.isCorrect == true).length / pinResponses.length);
        subMetrics['stroke_order_accuracy'] = strResponses.isEmpty ? null : (strResponses.where((r) => r.isCorrect == true).length / strResponses.length);

        // Pictographic Intuition (basic pictographs)
        final picResponses = attempted.where((r) =>
          r.itemId.startsWith('PIC_') ||
          (r.writingSubType == WritingSubType.characterRecognition && r.itemDifficulty <= -1.5)
        ).toList();
        if (picResponses.isNotEmpty) {
          final correctPic = picResponses.where((r) => r.isCorrect == true).length;
          subMetrics['pictographic_intuition_accuracy'] = correctPic / picResponses.length;
        }
      } else if (skill == CatSkill.speaking) {
        subMetrics['speaking_mode'] = SpeakingEvaluationMode.acousticAudioAnalyzed.labelVi;
        subMetrics['note'] = 'Đánh giá qua ngữ điệu và phát âm mẫu';
      }

      String confLabel = 'Trung bình';
      if (overallStandardError <= 0.35) {
        confLabel = 'Cao';
      } else if (overallStandardError >= 0.70) {
        confLabel = 'Thấp';
      }

      skillScores[skill] = SkillScoreEstimate(
        skill: skill,
        isAssessed: true,
        estimatedTheta: skillTheta,
        standardError: overallStandardError,
        accuracyRate: accuracy,
        itemsAttempted: attempted.length,
        itemsCorrect: correctCount,
        confidenceLabel: confLabel,
        subMetrics: subMetrics,
      );
    }

    // Collect knowledge gaps from incorrect answers
    final seenGapTags = <String>{};
    for (final resp in responses) {
      if (resp.isCorrect == false) {
        final item = CatItemBank.getItemById(resp.itemId);
        if (item != null && !seenGapTags.contains(item.knowledgeGapTag)) {
          seenGapTags.add(item.knowledgeGapTag);
          knowledgeGaps.add(
            KnowledgeGapItem(
              tag: item.knowledgeGapTag,
              labelVi: item.knowledgeGapLabelVi,
              skill: item.skill,
              suggestedRemediationVi: item.explanationVi,
            ),
          );
        }
      }
    }

    final effectiveBlueprintVersion = blueprintVersion ?? blueprint.version;
    final isBeginner = effectiveBlueprintVersion == 'v1.0-beginner';

    final hskBand = isBeginner
        ? (overallTheta < -1.5 ? 'HSK 0 (Khởi đầu từ số 0)' : 'HSK 1 (Sơ cấp cơ bản)')
        : CatAssessmentResult.mapThetaToHskBand(overallTheta);
    final recommendedLevel = isBeginner
        ? 1
        : CatAssessmentResult.mapThetaToRecommendedLevel(overallTheta);
    final confidenceScore = (1.0 - (overallStandardError / 1.5)).clamp(0.1, 1.0);

    return CatAssessmentResult(
      sessionId: sessionId,
      overallTheta: overallTheta,
      overallStandardError: overallStandardError,
      referenceHskBand: hskBand,
      confidenceScore: confidenceScore,
      skillScores: skillScores,
      knowledgeGaps: knowledgeGaps,
      recommendedHskLevel: recommendedLevel,
      recommendedRoadmapTitle: 'Lộ trình gợi ý: HSK $recommendedLevel',
      recommendedRoadmapCode: 'HSK_$recommendedLevel',
      completedAt: completedAt,
      blueprintVersion: effectiveBlueprintVersion,
    );
  }
}
