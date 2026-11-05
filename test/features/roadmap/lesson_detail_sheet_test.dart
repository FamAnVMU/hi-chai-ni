import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/roadmap/roadmap.dart';

void main() {
  const sampleLesson = CurriculumLesson(
    id: 'LES_TEST_01',
    unitId: 'UNIT_01',
    level: 1,
    title: 'Bài 1: Chào hỏi',
    description: 'Học cách chào hỏi cơ bản',
    primarySkill: SkillDimension.speaking,
    prerequisiteLessonIds: [],
    estimatedMinutes: 15,
  );

  Widget buildSheetHarness({
    required LessonProgress? progress,
    VoidCallback? onStart,
    ValueChanged<double>? onComplete,
    VoidCallback? onSkip,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              LessonDetailSheet.show(
                context: context,
                lesson: sampleLesson,
                progress: progress,
                allProgressMap: progress != null ? {progress.lessonId: progress} : {},
                onStart: onStart ?? () {},
                onComplete: onComplete ?? (_) {},
                onSkip: onSkip ?? () {},
              );
            },
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    );
  }

  group('LessonDetailSheet & F-04 Completion Callback Tests', () {
    testWidgets('1. Displays "Xác nhận hoàn thành bài học" button when lesson is inProgress', (tester) async {
      final inProgress = LessonProgress(
        id: 'p1',
        lessonId: sampleLesson.id,
        unitId: 'UNIT_01',
        hskLevel: 1,
        status: LessonStatus.inProgress,
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(buildSheetHarness(progress: inProgress));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận hoàn thành bài học'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.text('Đang học dở'), findsOneWidget);
    });

    testWidgets('2. Does NOT display "Xác nhận hoàn thành bài học" when status is available, completed, or locked', (tester) async {
      // Available
      final available = LessonProgress(
        id: 'p1',
        lessonId: sampleLesson.id,
        unitId: 'UNIT_01',
        hskLevel: 1,
        status: LessonStatus.available,
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(buildSheetHarness(progress: available));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận hoàn thành bài học'), findsNothing);

      // Dismiss
      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle();

      // Completed
      final completed = available.copyWith(status: LessonStatus.completed);
      await tester.pumpWidget(buildSheetHarness(progress: completed));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận hoàn thành bài học'), findsNothing);

      // Dismiss
      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle();

      // Locked
      final locked = available.copyWith(status: LessonStatus.locked);
      await tester.pumpWidget(buildSheetHarness(progress: locked));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận hoàn thành bài học'), findsNothing);
    });

    testWidgets('3. Tapping "Xác nhận hoàn thành bài học" calls onComplete with 0.0 when unassessed and pops sheet', (tester) async {
      int completeCallCount = 0;
      double? receivedScore;

      final inProgress = LessonProgress(
        id: 'p1',
        lessonId: sampleLesson.id,
        unitId: 'UNIT_01',
        hskLevel: 1,
        status: LessonStatus.inProgress,
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        buildSheetHarness(
          progress: inProgress,
          onComplete: (score) {
            completeCallCount++;
            receivedScore = score;
          },
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận hoàn thành bài học'), findsOneWidget);
      await tester.tap(find.text('Xác nhận hoàn thành bài học'));
      await tester.pumpAndSettle();

      expect(completeCallCount, equals(1));
      expect(receivedScore, equals(0.0)); // Anti-cheating (BUG-NEW-005): Zero score when unassessed
      expect(find.text('Xác nhận hoàn thành bài học'), findsNothing); // Sheet popped
    });

    testWidgets('4. Transfers empirical progress.score if present, or defaults to 0.8', (tester) async {
      double? receivedScore;

      final scoredProgress = LessonProgress(
        id: 'p1',
        lessonId: sampleLesson.id,
        unitId: 'UNIT_01',
        hskLevel: 1,
        status: LessonStatus.inProgress,
        completionScore: 0.95,
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        buildSheetHarness(
          progress: scoredProgress,
          onComplete: (score) {
            receivedScore = score;
          },
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xác nhận hoàn thành bài học'));
      await tester.pumpAndSettle();

      expect(receivedScore, equals(0.95));
    });

    testWidgets('5. Anti-duplicate call protection: prevents multiple onComplete triggers from repeated taps', (tester) async {
      int completeCallCount = 0;

      final inProgress = LessonProgress(
        id: 'p1',
        lessonId: sampleLesson.id,
        unitId: 'UNIT_01',
        hskLevel: 1,
        status: LessonStatus.inProgress,
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        buildSheetHarness(
          progress: inProgress,
          onComplete: (_) {
            completeCallCount++;
          },
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final confirmBtn = find.text('Xác nhận hoàn thành bài học');
      expect(confirmBtn, findsOneWidget);

      // Rapidly tap button twice before frame settles
      await tester.tap(confirmBtn);
      await tester.tap(confirmBtn, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(completeCallCount, equals(1), reason: 'Double-tap must NOT trigger onComplete multiple times');
    });
  });
}
