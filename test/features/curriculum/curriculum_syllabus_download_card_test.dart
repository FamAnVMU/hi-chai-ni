import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart';

Widget _app(Widget child) => ProviderScope(child: MaterialApp(home: child));

void main() {
  group('CurriculumSyllabusScreen download card (HSK 3+ not installed)', () {
    for (final level in [3, 4, 5, 6]) {
      testWidgets('HSK $level without units shows download card above exit exam', (tester) async {
        await tester.pumpWidget(_app(CurriculumSyllabusScreen(
          units: const [],
          curriculumId: CurriculumConstants.curriculumIdForLevel(level),
          curriculumTitle: 'Giáo trình HSK $level Chuẩn',
        )));
        await tester.pumpAndSettle();

        final title = find.text('Chưa tải giáo trình HSK $level');
        final button = find.text('Tải gói học liệu HSK $level ngay');
        final exam = find.text('Thi tốt nghiệp HSK $level');

        expect(title, findsOneWidget);
        expect(button, findsOneWidget);
        expect(find.byIcon(Icons.cloud_download_rounded), findsOneWidget);
        expect(exam, findsOneWidget, reason: 'Exit exam stays available as secondary option');
        expect(find.text('Hoặc thi tốt nghiệp trực tiếp'), findsOneWidget);

        // Download card must be rendered before the exit exam card.
        expect(
          tester.getTopLeft(title).dy,
          lessThan(tester.getTopLeft(exam).dy),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Installed curriculum hides the download card', (tester) async {
      final unit = CurriculumUnit(
        id: 'hsk3_u1',
        curriculumId: CurriculumConstants.curriculumIdForLevel(3),
        orderIndex: 1,
        titleVi: 'Chủ đề 1',
        titleZh: '单元一',
        lessons: const [
          CurriculumLesson(
            id: 'hsk3_l1',
            unitId: 'hsk3_u1',
            orderIndex: 1,
            titleVi: 'Bài đầu',
            titleZh: '第一课',
            pinyin: 'dì yī kè',
            status: LessonStatus.notStarted,
            isLocked: false,
            prerequisites: [],
            segments: [],
          ),
        ],
      );
      await tester.pumpWidget(_app(CurriculumSyllabusScreen(
        units: [unit],
        curriculumId: CurriculumConstants.curriculumIdForLevel(3),
        curriculumTitle: 'Giáo trình HSK 3 Chuẩn',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Chưa tải giáo trình HSK 3'), findsNothing);
      expect(find.text('Thi tốt nghiệp HSK 3'), findsOneWidget);
      expect(find.text('Bài 1: Bài đầu'), findsOneWidget);
    });
  });
}
