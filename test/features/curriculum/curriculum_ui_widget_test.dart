import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/lesson_study_screen.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/level_exit_exam_screen.dart';

void main() {
  final sampleLesson1 = CurriculumLesson(
    id: 'hsk1_l1',
    unitId: 'hsk1_u1',
    orderIndex: 1,
    titleVi: '你好 - Xin chào',
    titleZh: '你好',
    pinyin: 'nǐ hǎo',
    status: LessonStatus.inProgress,
    isLocked: false,
    prerequisites: const [],
    segments: [
      const LessonSegment(
        id: 'seg_warmup',
        lessonId: 'hsk1_l1',
        stepOrder: 1,
        segmentType: 'warmup',
        title: 'Khởi động',
        contentPayload: {'intro': 'Chào mừng bạn đến với bài 1!'},
      ),
      const LessonSegment(
        id: 'seg_vocab',
        lessonId: 'hsk1_l1',
        stepOrder: 2,
        segmentType: 'vocabulary',
        title: 'Từ vựng mới',
        contentPayload: {
          'words': [
            {'hanzi': '你', 'pinyin': 'nǐ', 'meaning': 'bạn, anh, chị', 'type': 'pronoun'},
            {'hanzi': '好', 'pinyin': 'hǎo', 'meaning': 'tốt, khỏe, đẹp', 'type': 'adjective'},
          ]
        },
      ),
      const LessonSegment(
        id: 'seg_grammar',
        lessonId: 'hsk1_l1',
        stepOrder: 3,
        segmentType: 'grammar',
        title: 'Điểm ngữ pháp',
        contentPayload: {
          'points': [
            {'title': 'Câu chào 你好', 'structure': 'Đại từ + 好', 'explanation': 'Lời chào thông dụng nhất.'}
          ]
        },
      ),
      const LessonSegment(
        id: 'seg_dialogue',
        lessonId: 'hsk1_l1',
        stepOrder: 4,
        segmentType: 'dialogue',
        title: 'Hội thoại ứng dụng',
        contentPayload: {
          'lines': [
            {'speaker': 'A', 'hanzi': '你好！', 'pinyin': 'Nǐ hǎo!', 'meaning': 'Xin chào!'},
            {'speaker': 'B', 'hanzi': '你好！', 'pinyin': 'Nǐ hǎo!', 'meaning': 'Xin chào!'},
          ]
        },
      ),
      const LessonSegment(
        id: 'seg_practice',
        lessonId: 'hsk1_l1',
        stepOrder: 5,
        segmentType: 'practice',
        title: 'Luyện tập thích ứng',
        contentPayload: {
          'exercises': [
            {
              'id': 'ex_1',
              'type': 'multiple_choice',
              'skill_type': 'reading',
              'prompt': 'Từ "你" có nghĩa là gì?',
              'options': ['Bạn', 'Tôi', 'Anh ấy'],
              'correct_answer': 'Bạn',
              'explanation': '"你" là đại từ ngôi thứ hai.',
            }
          ]
        },
      ),
      const LessonSegment(
        id: 'seg_mastery',
        lessonId: 'hsk1_l1',
        stepOrder: 6,
        segmentType: 'masteryCheck',
        title: 'Đánh giá hoàn thành',
        contentPayload: {
          'exercises': [
            {
              'id': 'ex_m1',
              'type': 'multiple_choice',
              'skill_type': 'reading',
              'prompt': 'Chọn nghĩa đúng của "好":',
              'options': ['Tốt, khỏe', 'Xấu', 'Bận'],
              'correct_answer': 'Tốt, khỏe',
              'explanation': '"好" có nghĩa là tốt hoặc khỏe.',
            }
          ]
        },
      ),
    ],
  );

  final sampleLesson2 = const CurriculumLesson(
    id: 'hsk1_l2',
    unitId: 'hsk1_u1',
    orderIndex: 2,
    titleVi: '谢谢你 - Cảm ơn bạn',
    titleZh: '谢谢你',
    pinyin: 'xièxie nǐ',
    status: LessonStatus.notStarted,
    isLocked: true,
    prerequisites: ['hsk1_l1'],
    segments: [],
  );

  final sampleUnit = CurriculumUnit(
    id: 'hsk1_u1',
    curriculumId: 'hsk_1_official',
    orderIndex: 1,
    titleVi: 'Chủ đề 1: Chào hỏi & Làm quen',
    titleZh: '第一单元: 问候',
    lessons: [sampleLesson1, sampleLesson2],
  );

  group('Curriculum UI & 6-Step Lesson Flow Widget Tests', () {
    testWidgets('1. CurriculumSyllabusScreen renders units, lessons, locked state, and exit exam', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CurriculumSyllabusScreen(
              units: [sampleUnit],
              curriculumTitle: 'Giáo trình HSK 1 Chuẩn',
            ),
          ),
        ),
      );

      // Verify Title & Unit
      expect(find.text('Giáo trình HSK 1 Chuẩn'), findsWidgets);
      expect(find.text('Chủ đề 1: Chào hỏi & Làm quen'), findsOneWidget);

      // Verify Lessons
      expect(find.text('Bài 1: 你好 - Xin chào'), findsOneWidget);
      expect(find.text('Bài 2: 谢谢你 - Cảm ơn bạn'), findsOneWidget);

      // Verify Locked indicator for Lesson 2
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      // Verify Exit Exam Button / Card
      expect(find.text('Thi tốt nghiệp HSK 1'), findsOneWidget);
    });

    testWidgets('2. LessonStudyScreen navigates through 6 steps', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LessonStudyScreen(lesson: sampleLesson1),
          ),
        ),
      );

      // Step 1: Warmup
      expect(find.textContaining('Khởi động'), findsWidgets);
      expect(find.text('Chào mừng bạn đến với bài 1!'), findsOneWidget);

      // Advance to Step 2: Vocabulary
      final nextButton = find.text('Tiếp theo');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Từ vựng'), findsWidgets);
      expect(find.text('你', skipOffstage: false), findsOneWidget);
      expect(find.text('bạn, anh, chị', skipOffstage: false), findsOneWidget);

      // Advance to Step 3: Grammar
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('ngữ pháp'), findsWidgets);
      expect(find.text('Câu chào 你好', skipOffstage: false), findsOneWidget);

      // Advance to Step 4: Dialogue
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Hội thoại'), findsWidgets);
      expect(find.text('你好！', skipOffstage: false), findsWidgets);

      // Advance to Step 5: Practice
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Luyện tập'), findsWidgets);
      expect(find.text('Từ "你" có nghĩa là gì?', skipOffstage: false), findsOneWidget);

      // Advance to Step 6: Mastery Check
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Đánh giá'), findsWidgets);
      expect(find.textContaining('Chọn nghĩa đúng của "好":', skipOffstage: false), findsOneWidget);
    });

    testWidgets('3. LevelExitExamScreen renders exam header, timer, and submits score', (tester) async {
      final sampleExam = {
        'id': 'exam_hsk1',
        'level': 1,
        'title': 'Đề thi tốt nghiệp HSK 1 Chuẩn Quốc Tế',
        'duration_minutes': 35,
        'passing_score': 120,
        'total_score': 200,
        'questions': [
          {
            'id': 'q_listen_1',
            'section': 'listening',
            'prompt': 'Nghe và chọn bức tranh tương ứng',
            'options': ['A', 'B', 'C'],
            'correct_answer': 'A',
          },
          {
            'id': 'q_read_1',
            'section': 'reading',
            'prompt': 'Chọn từ đúng cho câu: 我是 [ ____ ]。',
            'options': ['学生', '喝', '去'],
            'correct_answer': '学生',
          }
        ]
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LevelExitExamScreen(examData: sampleExam),
          ),
        ),
      );

      // Verify Exam Header & Questions
      expect(find.text('Đề thi tốt nghiệp HSK 1 Chuẩn Quốc Tế'), findsOneWidget);
      expect(find.textContaining('35'), findsWidgets);
      expect(find.text('Phần 1: Nghe hiểu'), findsOneWidget);
      expect(find.text('Phần 2: Đọc hiểu'), findsOneWidget);

      // Tap an option
      await tester.tap(find.text('学生'));
      await tester.pumpAndSettle();

      // Submit Exam
      final submitButton = find.text('Nộp bài thi');
      await tester.scrollUntilVisible(submitButton, 200);
      await tester.pumpAndSettle();
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify Score / Result View
      expect(find.textContaining('Kết quả thi'), findsWidgets);
    });
  });
}
