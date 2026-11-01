import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/roadmap/roadmap.dart';

class FakeRoadmapRepository implements RoadmapRepository {
  LearnerGoal goal = LearnerGoal.defaultGoal();
  final Map<String, LessonProgress> progressMap = {
    'LES_HSK1_01_TONES': LessonProgress(
      id: 'p1',
      lessonId: 'LES_HSK1_01_TONES',
      unitId: 'UNIT_HSK1_01',
      hskLevel: 1,
      status: LessonStatus.available,
      evidenceCount: 0,
      updatedAt: DateTime.utc(2026, 11, 1),
    ),
  };

  @override
  Future<LearnerGoal> getActiveGoal() async => goal;

  @override
  Future<void> updateGoal(LearnerGoal newGoal) async {
    goal = newGoal;
  }

  @override
  Future<Map<String, LessonProgress>> getLessonProgressMap() async => progressMap;

  @override
  Future<void> startLesson(String lessonId) async {
    final existing = progressMap[lessonId];
    progressMap[lessonId] = (existing ??
            LessonProgress(
              id: 'p_$lessonId',
              lessonId: lessonId,
              unitId: 'UNIT_HSK1_01',
              hskLevel: 1,
              updatedAt: DateTime.now().toUtc(),
            ))
        .copyWith(status: LessonStatus.inProgress);
  }

  @override
  Future<void> completeLesson({required String lessonId, required double score}) async {
    final existing = progressMap[lessonId];
    progressMap[lessonId] = (existing ??
            LessonProgress(
              id: 'p_$lessonId',
              lessonId: lessonId,
              unitId: 'UNIT_HSK1_01',
              hskLevel: 1,
              updatedAt: DateTime.now().toUtc(),
            ))
        .copyWith(
      status: LessonStatus.completed,
      completionScore: score,
    );
  }

  @override
  Future<void> skipLesson(String lessonId) async {
    final existing = progressMap[lessonId];
    progressMap[lessonId] = (existing ??
            LessonProgress(
              id: 'p_$lessonId',
              lessonId: lessonId,
              unitId: 'UNIT_HSK1_01',
              hskLevel: 1,
              updatedAt: DateTime.now().toUtc(),
            ))
        .copyWith(status: LessonStatus.skipped);
  }

  @override
  Future<LearnerRoadmapState> getAdaptiveRoadmapState() async {
    final lesson = CurriculumCatalog.findLessonById('LES_HSK1_01_TONES')!;
    return LearnerRoadmapState(
      activeGoal: goal,
      currentLevel: goal.targetHskLevel,
      lessonProgressMap: progressMap,
      skillMasteryMap: {
        for (final s in SkillDimension.values)
          s: SkillMastery(skill: s, masteryRate: 0.65, evidenceCount: 4),
      },
      recommendations: [
        RoadmapRecommendation(
          lesson: lesson,
          priority: RecommendationPriority.recommended,
          reason: 'Bắt đầu với 4 thanh điệu cơ bản để phát âm chuẩn.',
          supportingEvidence: ['Bài học khởi động HSK 1'],
        ),
      ],
    );
  }
}

void main() {
  late FakeRoadmapRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeRoadmapRepository();
  });

  Widget buildTestableWidget() {
    return ProviderScope(
      overrides: [
        roadmapRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: const MaterialApp(
        home: RoadmapScreen(),
      ),
    );
  }

  group('RoadmapScreen Widget Tests', () {
    testWidgets('1. Displays goal overview, level chips, recommendations and skill cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Title in appbar
      expect(find.text('Lộ Trình Thích Ứng'), findsOneWidget);

      // Goal header
      expect(find.text('Mục Tiêu Của Bạn: HSK 1'), findsOneWidget);

      // Level selector chips
      expect(find.text('HSK 1'), findsWidgets);
      expect(find.text('HSK 2'), findsWidgets);

      // Recommendations card
      expect(find.text('Đề Xuất Cho Bạn (Thích Ứng)'), findsOneWidget);
      expect(find.text('Bắt đầu với 4 thanh điệu cơ bản để phát âm chuẩn.'), findsOneWidget);

      // 6 skills mastery grid
      expect(find.text('Độ Thành Thạo 6 Kỹ Năng'), findsOneWidget);
      expect(find.text('Từ vựng'), findsWidgets);
      expect(find.text('Nói & Phát âm'), findsWidgets);

      // Curriculum units
      expect(find.text('Unit 1'), findsOneWidget);
    });

    testWidgets('2. Tap "Thay đổi" opens GoalSettingsSheet modal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final changeBtn = find.text('Thay đổi');
      expect(changeBtn, findsOneWidget);
      await tester.tap(changeBtn);
      await tester.pumpAndSettle();

      expect(find.text('Thiết Lập Mục Tiêu Học Tập'), findsOneWidget);
      expect(find.text('Cấp độ HSK mục tiêu:'), findsOneWidget);
      expect(find.text('Lưu mục tiêu'), findsOneWidget);
    });

    testWidgets('3. Tap on lesson opens LessonDetailSheet modal with prerequisites & actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap "Học ngay" on the recommendation card to open deep detail sheet
      final learnNowBtn = find.text('Học ngay');
      expect(learnNowBtn, findsWidgets);
      await tester.tap(learnNowBtn.first);
      await tester.pumpAndSettle();

      // Lesson detail sheet opens
      expect(find.text('Có thể học ngay'), findsOneWidget);
      expect(find.text('Bắt đầu học'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsWidgets);
    });
  });
}
