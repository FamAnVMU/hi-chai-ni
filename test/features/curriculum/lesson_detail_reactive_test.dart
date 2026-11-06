import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/domain/models/lesson_flow_state.dart';
import 'package:hi_chinese/features/curriculum/presentation/providers/curriculum_providers.dart';
import 'package:hi_chinese/features/curriculum/presentation/providers/lesson_flow_providers.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/lesson_study_screen.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/lesson_content_empty_state.dart';

void main() {
  CurriculumLesson createEmptyTestLesson({
    String id = 'lesson_reactive_test',
    String titleVi = 'Bài 1: Phản ứng động',
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
      segments: const [], // Empty segments initially
    );
  }

  CurriculumLesson createFullTestLesson({
    String id = 'lesson_reactive_test',
    String titleVi = 'Bài 1: Phản ứng động (Đã cập nhật)',
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
      segments: const [
        LessonSegment(
          id: 'seg_warmup',
          lessonId: 'lesson_reactive_test',
          stepOrder: 0,
          segmentType: 'warmup',
          title: 'Khởi động',
          contentPayload: {
            'intro': 'Nội dung khởi động phản ứng đặc biệt!',
          },
        ),
        LessonSegment(
          id: 'seg_vocab',
          lessonId: 'lesson_reactive_test',
          stepOrder: 1,
          segmentType: 'vocabulary',
          title: 'Từ vựng',
          contentPayload: {
            'words': [
              {
                'hanzi': '你好',
                'pinyin': 'nǐ hǎo',
                'meaning': 'xin chào',
                'part_of_speech': 'chào hỏi',
              },
            ],
          },
        ),
        LessonSegment(
          id: 'seg_grammar',
          lessonId: 'lesson_reactive_test',
          stepOrder: 2,
          segmentType: 'grammar',
          title: 'Ngữ pháp',
          contentPayload: {
            'points': [
              {
                'title': 'Câu chào hỏi cơ bản',
                'explanation': 'Dùng 你好 để chào một người.',
              },
            ],
          },
        ),
        LessonSegment(
          id: 'seg_dialogue',
          lessonId: 'lesson_reactive_test',
          stepOrder: 3,
          segmentType: 'dialogue',
          title: 'Hội thoại',
          contentPayload: {
            'lines': [
              {
                'speaker': 'A',
                'hanzi': '你好！',
                'pinyin': 'Nǐ hǎo!',
                'meaning': 'Xin chào!',
              },
            ],
          },
        ),
        LessonSegment(
          id: 'seg_practice',
          lessonId: 'lesson_reactive_test',
          stepOrder: 4,
          segmentType: 'practice',
          title: 'Luyện tập',
          contentPayload: {
            'questions': [
              {
                'id': 'q1',
                'type': 'multiple_choice',
                'prompt': 'Từ "你好" có nghĩa là gì?',
                'options': ['Xin chào', 'Tạm biệt'],
                'correct_answer': 'Xin chào',
              },
            ],
          },
        ),
        LessonSegment(
          id: 'seg_mastery',
          lessonId: 'lesson_reactive_test',
          stepOrder: 5,
          segmentType: 'mastery_check',
          title: 'Đánh giá hoàn thành',
          contentPayload: {
            'questions': [
              {
                'id': 'mq1',
                'type': 'multiple_choice',
                'prompt': 'Đánh giá: Chọn nghĩa đúng của 你好',
                'options': ['Xin chào', 'Cảm ơn'],
                'correct_answer': 'Xin chào',
              },
            ],
          },
        ),
      ],
    );
  }

  group('lessonDetailProvider Reactive Tests', () {
    testWidgets(
      'Test 1: LessonStudyScreen phản ứng với lessonDetailProvider khi ban đầu widget.lesson không có segments',
      (tester) async {
        final initialLesson = createEmptyTestLesson();
        final fullLesson = createFullTestLesson();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lessonDetailProvider(initialLesson.id).overrideWith(
                (ref) => Future.value(fullLesson),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: LessonStudyScreen(lesson: initialLesson),
            ),
          ),
        );

        // Chờ provider nạp xong dữ liệu đầy đủ
        await tester.pumpAndSettle();

        // 1. Kiểm tra Warmup hiển thị đúng intro từ fullLesson.segments
        expect(find.text('Nội dung khởi động phản ứng đặc biệt!'), findsOneWidget);

        // 2. Chuyển sang Step 1 (Từ vựng mới)
        final container = ProviderScope.containerOf(tester.element(find.byType(LessonStudyScreen)));
        container.read(lessonFlowNotifierProvider(initialLesson.id).notifier).nextStep();
        await tester.pumpAndSettle();

        // 3. Kiểm tra Step 1 hiển thị từ vựng từ reactive lesson, không hiển thị EmptyState
        expect(find.text('你好'), findsOneWidget);
        expect(find.text('xin chào'), findsOneWidget);
        expect(find.byType(LessonContentEmptyState), findsNothing);

        // 4. Chuyển sang Step 2 (Điểm ngữ pháp)
        container.read(lessonFlowNotifierProvider(initialLesson.id).notifier).nextStep();
        await tester.pumpAndSettle();

        // Kiểm tra Step 2 hiển thị điểm ngữ pháp từ reactive lesson
        expect(find.text('Câu chào hỏi cơ bản'), findsOneWidget);
        expect(find.byType(LessonContentEmptyState), findsNothing);
      },
    );

    testWidgets(
      'Test 2: LessonStudyScreen fallback mượt mà về widget.lesson khi lessonDetailProvider null/loading',
      (tester) async {
        final initialLesson = createEmptyTestLesson(titleVi: 'Bài học tĩnh');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lessonDetailProvider(initialLesson.id).overrideWith(
                (ref) => Future.value(null),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: LessonStudyScreen(lesson: initialLesson),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Kiểm tra tiêu đề hiển thị từ initialLesson
        expect(find.text('Bài học tĩnh'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
