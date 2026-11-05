import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/presentation/providers/curriculum_providers.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/lesson_study_screen.dart';
import 'package:hi_chinese/features/learning/presentation/screens/learning_screen.dart';

void main() {
  final sampleLessonsUnit1 = [
    const CurriculumLesson(
      id: 'lesson_1_1',
      unitId: 'unit_1',
      orderIndex: 1,
      titleVi: 'Xin chào',
      titleZh: '你好',
      pinyin: 'Nǐ hǎo',
      estimatedMinutes: 15,
      isLocked: false,
      status: LessonStatus.completed,
      segments: [
        LessonSegment(
          id: 'seg_1_1_vocab',
          lessonId: 'lesson_1_1',
          stepOrder: 2,
          segmentType: 'vocabulary',
          title: 'Từ vựng',
          contentPayload: {
            'words': [
              {'hanzi': '你', 'pinyin': 'nǐ'},
              {'hanzi': '好', 'pinyin': 'hǎo'},
            ],
          },
        ),
      ],
    ),
    const CurriculumLesson(
      id: 'lesson_1_2',
      unitId: 'unit_1',
      orderIndex: 2,
      titleVi: 'Cảm ơn bạn',
      titleZh: '谢谢你',
      pinyin: 'Xièxie nǐ',
      estimatedMinutes: 15,
      isLocked: false,
      status: LessonStatus.inProgress,
      masteryScore: 0.65,
      segments: [
        LessonSegment(
          id: 'seg_1_2_vocab',
          lessonId: 'lesson_1_2',
          stepOrder: 2,
          segmentType: 'vocabulary',
          title: 'Từ vựng',
          contentPayload: {
            'words': [
              {'hanzi': '谢', 'pinyin': 'xiè'},
            ],
          },
        ),
      ],
    ),
    const CurriculumLesson(
      id: 'lesson_1_3',
      unitId: 'unit_1',
      orderIndex: 3,
      titleVi: 'Gia đình tôi',
      titleZh: '我的家',
      pinyin: 'Wǒ de jiā',
      estimatedMinutes: 20,
      isLocked: true,
      status: LessonStatus.notStarted,
    ),
  ];

  final sampleUnit1 = CurriculumUnit(
    id: 'unit_1',
    curriculumId: CurriculumConstants.currHsk1,
    orderIndex: 1,
    titleVi: 'Khởi đầu và Chào hỏi',
    titleZh: '问候与起步',
    isLocked: false,
    lessons: sampleLessonsUnit1,
  );

  Widget buildTestWidget({
    required AsyncValue<List<CurriculumUnit>> unitsAsyncValue,
    String curriculumId = CurriculumConstants.currHsk1,
  }) {
    return ProviderScope(
      overrides: [
        curriculumUnitsWithLessonsProvider(curriculumId).overrideWith(
          (ref) => unitsAsyncValue.when(
            data: (data) => Future.value(data),
            error: (err, stack) => Future.error(err, stack),
            loading: () => Completer<List<CurriculumUnit>>().future,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LearningScreen(),
      ),
    );
  }

  group('LearningScreen Dynamic Real Curriculum Tests (F-20)', () {
    testWidgets('1. Renders Real Curriculum Units and Lessons without static mock chapters',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          unitsAsyncValue: AsyncValue.data([sampleUnit1]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chương 1: Khởi đầu và Chào hỏi'), findsOneWidget);
      expect(find.text('问候与起步'), findsOneWidget);
      expect(find.text('Giáo Trình HSK 1 Chuẩn'), findsOneWidget);

      expect(find.text('Chương 1: Khởi Đầu & Phát Âm Cơ Bản'), findsNothing);
      expect(find.text('Chương 2: Đời Sống Hàng Ngày'), findsNothing);

      expect(find.text('Bài 1'), findsOneWidget);
      expect(find.text('Xin chào'), findsOneWidget);
      expect(find.text('你好 • Nǐ hǎo'), findsOneWidget);
      expect(find.text('2 từ vựng'), findsOneWidget);
      expect(find.text('Đã hoàn thành'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      expect(find.text('Bài 2'), findsOneWidget);
      expect(find.text('Cảm ơn bạn'), findsOneWidget);
      expect(find.text('谢谢你 • Xièxie nǐ'), findsOneWidget);
      expect(find.text('1 từ vựng'), findsOneWidget);
      expect(find.text('Đang học (65%)'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);

      expect(find.text('Bài 3'), findsOneWidget);
      expect(find.text('Gia đình tôi'), findsOneWidget);
      expect(find.text('Chưa mở khóa'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('2. Tapping locked lesson displays informative prerequisite warning',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          unitsAsyncValue: AsyncValue.data([sampleUnit1]),
        ),
      );
      await tester.pumpAndSettle();

      final lockedLessonCard = find.text('Gia đình tôi');
      expect(lockedLessonCard, findsOneWidget);
      await tester.tap(lockedLessonCard);
      await tester.pump();

      expect(
        find.textContaining('Bài học đang bị khóa. Hãy hoàn thành đạt ≥ 80% các bài học tiên quyết.'),
        findsOneWidget,
      );
    });

    testWidgets('3. Tapping unlocked lesson navigates to LessonStudyScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          unitsAsyncValue: AsyncValue.data([sampleUnit1]),
        ),
      );
      await tester.pumpAndSettle();

      final lesson1Card = find.text('Xin chào');
      expect(lesson1Card, findsOneWidget);
      await tester.tap(lesson1Card);
      await tester.pumpAndSettle();

      expect(find.byType(LessonStudyScreen), findsOneWidget);
      expect(find.text('Xin chào'), findsOneWidget);
    });

    testWidgets('4. Empty curriculum renders graceful Empty State with Content Pack action',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          unitsAsyncValue: const AsyncValue.data([]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có học liệu cho HSK 1'), findsOneWidget);
      expect(
        find.textContaining('Giáo trình và bài học của cấp độ này chưa được tải về máy.'),
        findsOneWidget,
      );
      expect(find.text('Mở kho học liệu HSK'), findsOneWidget);
    });

    testWidgets('5. Error state renders error card with Retry action',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          unitsAsyncValue: AsyncValue.error(
            'Lỗi kết nối cơ sở dữ liệu học tập',
            StackTrace.current,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không thể tải danh sách bài học HSK 1'), findsOneWidget);
      expect(find.textContaining('Lỗi kết nối cơ sở dữ liệu học tập'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('6. Does not display Placement Test banner (accessible only via onboarding)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          unitsAsyncValue: AsyncValue.data([sampleUnit1]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Khảo sát năng lực đầu vào'), findsNothing);
      expect(find.text('Kiểm tra thích ứng 6 kỹ năng để chọn lớp HSK'), findsNothing);
    });
  });
}
