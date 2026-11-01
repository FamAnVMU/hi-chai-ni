import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/roadmap/roadmap.dart';

void main() {
  const engine = AdaptiveRoadmapEngine();

  group('AdaptiveRoadmapEngine Pedagogical Logic Tests', () {
    test('1. New learner with zero evidence gets first lesson available and others locked', () {
      final goal = LearnerGoal.defaultGoal();
      final context = AdaptiveRoadmapContext(
        goal: goal,
        currentLevel: goal.targetHskLevel,
        progressMap: const {},
        recentEvidence: const [],
        skillMasteryScores: const {},
      );

      final state = engine.generateRoadmap(context);

      expect(state.currentLevel, 1);
      expect(state.activeGoal.targetHskLevel, 1);

      // Lesson 1: Tones has no prerequisites, should be available
      final firstLessonProgress = state.lessonProgressMap['LES_HSK1_01_TONES'];
      expect(firstLessonProgress, isNotNull);
      expect(firstLessonProgress!.status, LessonStatus.available);

      // Lesson 2: Writing Basics requires Lesson 1, should be locked
      final secondLessonProgress = state.lessonProgressMap['LES_HSK1_02_WRITING_BASICS'];
      expect(secondLessonProgress, isNotNull);
      expect(secondLessonProgress!.status, LessonStatus.locked);

      // Recommendations should feature the first available lesson
      expect(state.recommendations, isNotEmpty);
      expect(state.recommendations.first.lesson.id, 'LES_HSK1_01_TONES');
      expect(state.recommendations.first.priority, RecommendationPriority.recommended);
    });

    test('2. Missing placement test data uses safe HSK 1 fallback without error', () {
      final goal = LearnerGoal.defaultGoal();
      final context = AdaptiveRoadmapContext(
        goal: goal,
        currentLevel: goal.targetHskLevel,
        progressMap: const {},
        recentEvidence: const [],
        skillMasteryScores: const {}, // No placement scores
      );

      final state = engine.generateRoadmap(context);

      expect(state.skillMasteryMap.length, 6);
      for (final dim in SkillDimension.values) {
        expect(state.skillMasteryMap[dim]!.masteryRate, 0.0);
        expect(state.skillMasteryMap[dim]!.evidenceCount, 0);
      }
      expect(state.overallLevelCompletion, 0.0);
    });

    test('3. Low mastery in a specific skill triggers URGENT recommendation with clear rationale', () {
      final goal = LearnerGoal.defaultGoal();
      final now = DateTime.now().toUtc();

      // Learner struggled in speaking / pronunciation
      final recentEvidence = [
        {
          'skill': 'speaking',
          'score': 0.35,
          'created_at': now.toIso8601String(),
        },
        {
          'skill': 'speaking',
          'score': 0.40,
          'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        },
      ];

      final context = AdaptiveRoadmapContext(
        goal: goal,
        currentLevel: goal.targetHskLevel,
        progressMap: const {},
        recentEvidence: recentEvidence,
        skillMasteryScores: {SkillDimension.speaking: 0.4},
      );

      final state = engine.generateRoadmap(context);

      expect(state.skillMasteryMap[SkillDimension.speaking]!.masteryRate, lessThan(0.5));

      final urgentRecs = state.recommendations
          .where((r) => r.priority == RecommendationPriority.urgent)
          .toList();

      expect(urgentRecs, isNotEmpty);
      final urgentSpeaking = urgentRecs.first;
      expect(urgentSpeaking.lesson.primarySkill, SkillDimension.speaking);
      expect(urgentSpeaking.reason, contains('Nói & Phát âm'));
      expect(urgentSpeaking.supportingEvidence, isNotEmpty);
    });

    test('4. Conflicting evidence resolution: recent low empirical score overrides old high placement score', () {
      final goal = LearnerGoal.defaultGoal();
      final now = DateTime.now().toUtc();

      // High placement test score (0.90) but recent poor performance (0.30)
      final recentEvidence = [
        {
          'skill': 'reading',
          'score': 0.30,
          'created_at': now.toIso8601String(),
        },
      ];

      final context = AdaptiveRoadmapContext(
        goal: goal,
        currentLevel: goal.targetHskLevel,
        progressMap: const {},
        recentEvidence: recentEvidence,
        skillMasteryScores: {SkillDimension.reading: 0.90}, // Old test was high
      );

      final state = engine.generateRoadmap(context);

      // Weighted calculation: 0.30 * 0.70 + 0.90 * 0.30 = 0.21 + 0.27 = 0.48 (< 0.50)
      final readingMastery = state.skillMasteryMap[SkillDimension.reading]!;
      expect(readingMastery.masteryRate, closeTo(0.48, 0.05));
      expect(readingMastery.masteryRate, lessThan(0.60)); // Recent evidence dominates!
    });

    test('5. Completing prerequisite lesson unlocks dependent lesson from locked to available', () {
      final goal = LearnerGoal.defaultGoal();
      final now = DateTime.now().toUtc();

      // First lesson completed
      final completedFirstLesson = LessonProgress(
        id: 'prog_01',
        lessonId: 'LES_HSK1_01_TONES',
        unitId: 'UNIT_HSK1_01',
        hskLevel: 1,
        status: LessonStatus.completed,
        completionScore: 0.88,
        evidenceCount: 3,
        updatedAt: now,
      );

      final context = AdaptiveRoadmapContext(
        goal: goal,
        currentLevel: goal.targetHskLevel,
        progressMap: {'LES_HSK1_01_TONES': completedFirstLesson},
        recentEvidence: const [],
        skillMasteryScores: const {},
      );

      final state = engine.generateRoadmap(context);

      // LES_HSK1_02_WRITING_BASICS required LES_HSK1_01_TONES, now should be available!
      final secondLessonProgress = state.lessonProgressMap['LES_HSK1_02_WRITING_BASICS'];
      expect(secondLessonProgress, isNotNull);
      expect(secondLessonProgress!.status, LessonStatus.available);

      // Recommendation should advance to Lesson 2
      expect(state.recommendations.any((r) => r.lesson.id == 'LES_HSK1_02_WRITING_BASICS'), isTrue);
    });

    test('6. Goal change to HSK 2 evaluates HSK 2 curriculum level', () {
      final hsk2Goal = LearnerGoal(
        id: 'goal_hsk2',
        targetHskLevel: 2,
        purpose: LearnerPurpose.hskExam,
        timeframe: LearnerTimeframe.express,
        dailyMinutes: 45,
        isActive: true,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      // Prerequisite capstone from HSK 1 completed
      final hsk1Capstone = LessonProgress(
        id: 'cap_01',
        lessonId: 'LES_HSK1_06_SHADOWING_GREETING',
        unitId: 'UNIT_HSK1_02',
        hskLevel: 1,
        status: LessonStatus.completed,
        updatedAt: DateTime.now().toUtc(),
      );

      final context = AdaptiveRoadmapContext(
        goal: hsk2Goal,
        currentLevel: hsk2Goal.targetHskLevel,
        progressMap: {'LES_HSK1_06_SHADOWING_GREETING': hsk1Capstone},
        recentEvidence: const [],
        skillMasteryScores: const {},
      );

      final state = engine.generateRoadmap(context);

      expect(state.currentLevel, 2);
      expect(state.activeGoal.targetHskLevel, 2);
      // HSK 2 first lesson available
      expect(state.lessonProgressMap['LES_HSK2_01_RESTAURANT_VOCAB']?.status, LessonStatus.available);
    });

    test('7. Cognitive overload guard: recommendations never exceed top 3 items', () {
      final goal = LearnerGoal.defaultGoal();
      final context = AdaptiveRoadmapContext(
        goal: goal,
        currentLevel: goal.targetHskLevel,
        progressMap: const {},
        recentEvidence: const [],
        skillMasteryScores: const {},
      );

      final state = engine.generateRoadmap(context);
      expect(state.recommendations.length, inInclusiveRange(1, 3));
    });

    test('8. Academic honesty: incomplete or missing progress never marked isCompleted', () {
      final inProgressLesson = LessonProgress(
        id: 'prog_in_progress',
        lessonId: 'LES_HSK1_01_TONES',
        unitId: 'UNIT_HSK1_01',
        hskLevel: 1,
        status: LessonStatus.inProgress, // Learner only opened it
        evidenceCount: 0,
        updatedAt: DateTime.now().toUtc(),
      );

      expect(inProgressLesson.isCompleted, isFalse);
      expect(inProgressLesson.isAvailable, isFalse);
      expect(inProgressLesson.isLocked, isFalse);
    });
  });
}
