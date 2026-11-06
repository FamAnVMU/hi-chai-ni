import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/domain/models/lesson_flow_state.dart';
import 'package:hi_chinese/features/curriculum/presentation/providers/lesson_flow_providers.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/lesson_study_screen.dart';

void main() {
  CurriculumLesson createTestLesson({
    String id = 'lesson_lifecycle_test',
    String titleVi = 'Bài 1: Khởi động giao tiếp',
  }) {
    return CurriculumLesson(
      id: id,
      unitId: 'unit_1',
      orderIndex: 1,
      titleVi: titleVi,
      titleZh: '第一课',
      pinyin: 'dì yī kè',
      status: LessonStatus.inProgress,
      isLocked: false,
      prerequisites: const [],
      segments: const [],
    );
  }

  group('LessonStudyScreen Lifecycle & AppBar Tests', () {
    testWidgets(
      'Test 1: Khởi tạo với notifier đang ở Step 5 (masteryCheck), mở LessonStudyScreen (không resumeStep) -> reset về Step 0 (Khởi động)',
      (tester) async {
        final lesson = createTestLesson(id: 'lesson_reset_test');
        final container = ProviderContainer();

        // 1. Giả lập state bài học trước đó bị kẹt ở Step 5 (masteryCheck)
        container
            .read(lessonFlowNotifierProvider(lesson.id).notifier)
            .resetToStep(LessonStep.masteryCheck);
        expect(
          container.read(lessonFlowNotifierProvider(lesson.id)).currentStep,
          LessonStep.masteryCheck,
        );

        // 2. Mở LessonStudyScreen không có resumeStep
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: LessonStudyScreen(lesson: lesson),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 3. Xác nhận sau post frame callback, màn hình đã được reset về Step 0 (Khởi động)
        final currentStep =
            container.read(lessonFlowNotifierProvider(lesson.id)).currentStep;
        expect(
          currentStep,
          LessonStep.warmup,
          reason: 'Mở bài học mới phải reset về LessonStep.warmup',
        );

        // Subtitle hiển thị Khởi động (1/6)
        expect(find.text('Khởi động (1/6)'), findsOneWidget);
      },
    );

    testWidgets('Test 2: AppBar hiển thị rõ ràng titleVi và tiến độ (1/6)', (
      tester,
    ) async {
      final lesson = createTestLesson(
        id: 'lesson_appbar_test',
        titleVi: 'Bài 1: Xin chào tiếng Trung',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: LessonStudyScreen(lesson: lesson),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề AppBar
      final titleFinder = find.text('Bài 1: Xin chào tiếng Trung');
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(
        titleWidget.style?.color,
        AppColors.primaryText,
        reason: 'Tiêu đề AppBar phải sử dụng AppColors.primaryText để tương phản rõ ràng',
      );
      expect(titleWidget.style?.fontWeight, FontWeight.bold);

      // Kiểm tra phụ đề tiến độ
      final subtitleFinder = find.text('Khởi động (1/6)');
      expect(subtitleFinder, findsOneWidget);
      final subtitleWidget = tester.widget<Text>(subtitleFinder);
      expect(
        subtitleWidget.style?.color,
        AppColors.secondaryText,
        reason: 'Phụ đề phải sử dụng AppColors.secondaryText',
      );

      // Kiểm tra LinearProgressIndicator tiến độ 1/6
      final progressFinder = find.byType(LinearProgressIndicator);
      expect(progressFinder, findsOneWidget);
      final progressWidget = tester.widget<LinearProgressIndicator>(
        progressFinder,
      );
      expect(progressWidget.value, closeTo(1 / 6, 0.001));
    });

    test('Test 3: Clamping an toàn với index bất kỳ', () {
      const stepTitles = [
        'Khởi động',
        'Từ vựng mới',
        'Điểm ngữ pháp',
        'Hội thoại ứng dụng',
        'Luyện tập thích ứng',
        'Đánh giá hoàn thành',
      ];
      final maxIndex = stepTitles.length - 1;

      expect((-10).clamp(0, maxIndex), 0);
      expect((-1).clamp(0, maxIndex), 0);
      expect(0.clamp(0, maxIndex), 0);
      expect(1.clamp(0, maxIndex), 1);
      expect(4.clamp(0, maxIndex), 4);
      expect(5.clamp(0, maxIndex), 5);
      expect(6.clamp(0, maxIndex), 5);
      expect(100.clamp(0, maxIndex), 5);
    });

    testWidgets(
      'Test bổ sung: Nếu truyền resumeStep cụ thể thì tôn trọng resumeStep đó',
      (tester) async {
        final lesson = createTestLesson(id: 'lesson_resume_test');
        final container = ProviderContainer();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: LessonStudyScreen(
                lesson: lesson,
                resumeStep: LessonStep.grammar,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final currentStep =
            container.read(lessonFlowNotifierProvider(lesson.id)).currentStep;
        expect(currentStep, LessonStep.grammar);
        expect(find.text('Điểm ngữ pháp (3/6)'), findsOneWidget);
      },
    );
  });
}
