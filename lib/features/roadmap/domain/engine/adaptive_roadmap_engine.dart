import '../catalog/curriculum_catalog.dart';
import '../models/roadmap_models.dart';

/// Context inputs for generating adaptive roadmap recommendations
class AdaptiveRoadmapContext {
  final LearnerGoal goal;
  final int currentLevel;
  final Map<String, LessonProgress> progressMap;
  final Map<SkillDimension, double> skillMasteryScores;
  final List<String> identifiedKnowledgeGaps;
  final int srsDueCount;
  final int srsLapseCount;
  final List<Map<String, dynamic>> recentEvidence;

  const AdaptiveRoadmapContext({
    required this.goal,
    required this.currentLevel,
    this.progressMap = const {},
    this.skillMasteryScores = const {},
    this.identifiedKnowledgeGaps = const [],
    this.srsDueCount = 0,
    this.srsLapseCount = 0,
    this.recentEvidence = const [],
  });
}

/// Core algorithmic engine producing prioritized, reasoned, and bounded
/// learning recommendations from Placement Test, Learning Evidence, SRS, and Prerequisites.
class AdaptiveRoadmapEngine {
  const AdaptiveRoadmapEngine();

  /// Computes updated lesson statuses and generates bounded, reasoned recommendations.
  LearnerRoadmapState generateRoadmap(AdaptiveRoadmapContext context) {
    final level = CurriculumCatalog.getLevel(context.currentLevel);
    final allLessons = level.allLessons;

    // 1. Compute updated lesson progress & unlocked availability
    final updatedProgressMap = <String, LessonProgress>{};

    for (final lesson in allLessons) {
      final existing = context.progressMap[lesson.id];

      if (existing != null && (existing.isCompleted || existing.status == LessonStatus.skipped)) {
        updatedProgressMap[lesson.id] = existing;
        continue;
      }

      // Check prerequisites
      final bool prerequisitesMet = lesson.prerequisiteLessonIds.every((preId) {
        final preProgress = context.progressMap[preId] ?? updatedProgressMap[preId];
        return preProgress != null && preProgress.isCompleted;
      });

      final newStatus = prerequisitesMet
          ? (existing?.status == LessonStatus.inProgress
              ? LessonStatus.inProgress
              : LessonStatus.available)
          : LessonStatus.locked;

      updatedProgressMap[lesson.id] = (existing ??
              LessonProgress(
                id: 'prog_${lesson.id}',
                lessonId: lesson.id,
                unitId: lesson.unitId,
                hskLevel: lesson.level,
                status: newStatus,
                updatedAt: DateTime.now().toUtc(),
              ))
          .copyWith(status: newStatus);
    }

    // 2. Synthesize multi-source Skill Mastery and detect conflicting evidence
    final Map<SkillDimension, SkillMastery> synthesizedMastery = {};

    for (final skill in SkillDimension.values) {
      // Collect recent evidence for this skill
      final skillEvidence = context.recentEvidence.where(
        (e) =>
            (e['source']?.toString().contains(skill.name) ?? false) ||
            (e['content_type']?.toString() == skill.name) ||
            (e['skill']?.toString() == skill.name),
      );

      final hasInitialScore = context.skillMasteryScores.containsKey(skill);
      double masteryRate = context.skillMasteryScores[skill] ?? 0.0;

      // Conflicting Evidence Resolution:
      // Recent empirical evidence overrules initial placement test estimate
      if (skillEvidence.isNotEmpty) {
        final scores = skillEvidence.map((e) => (e['score'] as num?)?.toDouble() ?? 0.5);
        final avgRecent = scores.reduce((a, b) => a + b) / scores.length;

        // Weight recent evidence heavily (70% recent empirical, 30% baseline)
        masteryRate = hasInitialScore
            ? (avgRecent * 0.7) + (masteryRate * 0.3)
            : avgRecent;
      }

      synthesizedMastery[skill] = SkillMastery(
        skill: skill,
        masteryRate: masteryRate.clamp(0.0, 1.0),
        evidenceCount: skillEvidence.length,
        lastAssessedAt: DateTime.now().toUtc(),
      );
    }

    // 3. Generate candidate recommendations
    final candidates = <CurriculumLesson>[];
    for (final lesson in allLessons) {
      final prog = updatedProgressMap[lesson.id];
      if (prog != null && (prog.isAvailable || prog.status == LessonStatus.inProgress)) {
        candidates.add(lesson);
      }
    }

    // 4. Score and prioritize candidates
    final scoredList = <_ScoredRecommendation>[];

    for (final lesson in candidates) {
      final skill = lesson.primarySkill;
      final masteryItem = synthesizedMastery[skill];
      final mastery = masteryItem?.masteryRate ?? 0.0;
      final hasEvidenceOrTest = (masteryItem?.evidenceCount ?? 0) > 0 ||
          context.skillMasteryScores.containsKey(skill);

      final hasKnowledgeGap = context.identifiedKnowledgeGaps.any(
        (gap) =>
            gap.toLowerCase().contains(skill.name) ||
            lesson.prerequisiteSkills.any((ps) => gap.toLowerCase().contains(ps)),
      );

      RecommendationPriority priority;
      String reason;
      final supportingEvidence = <String>[];

      // A. Urgent: Identified knowledge gaps or high SRS lapses
      if (hasKnowledgeGap || (context.srsLapseCount > 0 && mastery < 0.6)) {
        priority = RecommendationPriority.urgent;
        reason = 'Củng cố kỹ năng ${skill.displayName} do phát hiện lỗ hổng kiến thức.';
        supportingEvidence.add('Mức độ thành thạo hiện tại: ${(mastery * 100).toStringAsFixed(0)}%');
        if (hasKnowledgeGap) supportingEvidence.add('Phát hiện lỗ hổng từ bài đánh giá năng lực');
        if (context.srsLapseCount > 0) supportingEvidence.add('${context.srsLapseCount} thẻ SRS liên quan bị quên');
      }
      // B. Urgent: Low empirical skill mastery (< 55%) but only when user actually has evidence/test history
      else if (hasEvidenceOrTest && mastery < 0.55) {
        priority = RecommendationPriority.urgent;
        reason = 'Kỹ năng ${skill.displayName} cần được củng cố trước khi học các bài phức tạp.';
        supportingEvidence.add('Độ thành thạo thực tế: ${(mastery * 100).toStringAsFixed(0)}%');
        supportingEvidence.add('Dựa trên kết quả bài học gần nhất');
      }
      // C. Recommended: Standard sequential progression
      else {
        priority = RecommendationPriority.recommended;
        final prereqs = lesson.prerequisiteLessonIds;
        reason = prereqs.isEmpty
            ? 'Bài học mở đầu cho cấp độ HSK ${lesson.level}.'
            : 'Bài học tiếp theo sau khi hoàn thành các bài học tiên quyết.';
        supportingEvidence.add('Đã đáp ứng đầy đủ điều kiện tiên quyết');
        if (hasEvidenceOrTest) {
          supportingEvidence.add('Độ thành thạo kỹ năng nền tảng: ${(mastery * 100).toStringAsFixed(0)}%');
        }
      }

      scoredList.add(_ScoredRecommendation(
        recommendation: RoadmapRecommendation(
          lesson: lesson,
          priority: priority,
          reason: reason,
          supportingEvidence: supportingEvidence,
        ),
        sortScore: priority == RecommendationPriority.urgent
            ? 100.0 - (mastery * 50)
            : 50.0 - (mastery * 20),
      ));
    }

    // Sort: Urgent first, then highest score
    scoredList.sort((a, b) => b.sortScore.compareTo(a.sortScore));

    // 5. Bounded Output: Take top 3 recommendations (at most 4) to prevent cognitive overload
    final boundedRecommendations = scoredList
        .take(3)
        .map((s) => s.recommendation)
        .toList();

    return LearnerRoadmapState(
      activeGoal: context.goal,
      currentLevel: context.currentLevel,
      lessonProgressMap: updatedProgressMap,
      skillMasteryMap: synthesizedMastery,
      recommendations: boundedRecommendations,
    );
  }
}

class _ScoredRecommendation {
  final RoadmapRecommendation recommendation;
  final double sortScore;

  _ScoredRecommendation({
    required this.recommendation,
    required this.sortScore,
  });
}
