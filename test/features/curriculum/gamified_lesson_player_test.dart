import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/domain/models/micro_card_model.dart';
import 'package:hi_chinese/features/curriculum/domain/engine/lesson_micro_card_adapter.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/gamified_lesson_player.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/lesson_celebration_view.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/lesson_study_screen.dart';

void main() {
  final standardHskLesson = CurriculumLesson(
    id: 'hsk1_l1',
    unitId: 'hsk1_u1',
    orderIndex: 1,
    titleVi: 'Bài 1: Xin chào',
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
        title: 'Từ vựng',
        contentPayload: {
          'words': [
            {'hanzi': '你', 'pinyin': 'nǐ', 'meaning': 'bạn, anh, chị', 'han_viet': 'Nhĩ'},
            {'hanzi': '好', 'pinyin': 'hǎo', 'meaning': 'tốt, khỏe, đẹp', 'han_viet': 'Hảo'},
            {'hanzi': '我', 'pinyin': 'wǒ', 'meaning': 'tôi, mình', 'han_viet': 'Ngã'},
            {'hanzi': '很', 'pinyin': 'hěn', 'meaning': 'rất', 'han_viet': 'Hẩn'},
            {'hanzi': '他', 'pinyin': 'tā', 'meaning': 'anh ấy, ông ấy', 'han_viet': 'Tha'},
          ]
        },
      ),
      const LessonSegment(
        id: 'seg_grammar',
        lessonId: 'hsk1_l1',
        stepOrder: 3,
        segmentType: 'grammar',
        title: 'Ngữ pháp',
        contentPayload: {
          'points': [
            {
              'title': 'Cấu trúc đại từ + 好',
              'structure': 'Đại từ + 好',
              'positive_example': {
                'chinese': '你好！',
                'vietnamese': 'Xin chào bạn!',
              },
            },
            {
              'title': 'Phó từ chỉ mức độ 很',
              'structure': 'Chủ ngữ + 很 + Tính từ',
              'positive_example': {
                'chinese': '我很好。',
                'vietnamese': 'Tôi rất khỏe.',
              },
            },
          ]
        },
      ),
      const LessonSegment(
        id: 'seg_dialogue',
        lessonId: 'hsk1_l1',
        stepOrder: 4,
        segmentType: 'dialogue',
        title: 'Hội thoại',
        contentPayload: {
          'lines': [
            {'chinese': '你好！', 'meaning': 'Xin chào!'},
            {'chinese': '你好，很高兴认识你。', 'meaning': 'Chào bạn, rất vui được làm quen.'},
          ]
        },
      ),
      const LessonSegment(
        id: 'seg_practice',
        lessonId: 'hsk1_l1',
        stepOrder: 5,
        segmentType: 'practice',
        title: 'Luyện tập',
        contentPayload: {
          'exercises': [
            {
              'prompt': 'Từ "好" có nghĩa là gì?',
              'options': ['Tốt, đẹp', 'Bạn bè', 'Xấu', 'Cảm ơn'],
              'correct_index': 0,
            },
            {
              'prompt': 'Chọn câu chào thông dụng:',
              'options': ['你好', '再见', '谢谢', '对不起'],
              'correct_index': 0,
            },
            {
              'prompt': 'Điền từ: 我 [ ____ ] 好。',
              'options': ['很', '不', '去', '吃'],
              'correct_index': 0,
            },
          ]
        },
      ),
    ],
  );

  group('LessonMicroCardAdapter Tests', () {
    test('Test 1: Adapter sinh đủ 15–18 thẻ vi mô từ một bài học HSK chuẩn', () {
      const adapter = LessonMicroCardAdapter();
      final cards = adapter.adapt(standardHskLesson);

      expect(cards.length, inInclusiveRange(15, 18));

      // Verify presence of all 5 card types
      final types = cards.map((c) => c.type).toSet();
      expect(types.contains(MicroCardType.reveal), isTrue);
      expect(types.contains(MicroCardType.audioChoice), isTrue);
      expect(types.contains(MicroCardType.sentenceBuilder), isTrue);
      expect(types.contains(MicroCardType.matchingPairs), isTrue);
      expect(types.contains(MicroCardType.miniQuiz), isTrue);

      // Verify counts per category
      final reveals = cards.where((c) => c.type == MicroCardType.reveal).length;
      final audioChoices = cards.where((c) => c.type == MicroCardType.audioChoice).length;
      final sentenceBuilders = cards.where((c) => c.type == MicroCardType.sentenceBuilder).length;
      final matchingPairs = cards.where((c) => c.type == MicroCardType.matchingPairs).length;
      final miniQuizzes = cards.where((c) => c.type == MicroCardType.miniQuiz).length;

      expect(reveals, inInclusiveRange(4, 5));
      expect(audioChoices, inInclusiveRange(3, 4));
      expect(sentenceBuilders, inInclusiveRange(2, 3));
      expect(matchingPairs, inInclusiveRange(1, 2));
      expect(miniQuizzes, inInclusiveRange(3, 4));
    });
  });

  group('GamifiedLessonPlayer Widget Tests', () {
    testWidgets('Test 2: Trả lời đúng tăng combo 🔥 và thanh tiến độ', (tester) async {
      final testCards = [
        const MicroCardModel(
          id: 'c1',
          type: MicroCardType.reveal,
          hanzi: '你',
          pinyin: 'nǐ',
          meaning: 'bạn',
        ),
        const MicroCardModel(
          id: 'c2',
          type: MicroCardType.reveal,
          hanzi: '好',
          pinyin: 'hǎo',
          meaning: 'tốt',
        ),
        const MicroCardModel(
          id: 'c3',
          type: MicroCardType.reveal,
          hanzi: '我',
          pinyin: 'wǒ',
          meaning: 'tôi',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GamifiedLessonPlayer(
              lesson: standardHskLesson,
              initialCards: testCards,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card 1: Reveal '你'
      expect(find.text('你'), findsOneWidget);
      expect(find.text('Tiếp tục'), findsOneWidget);

      // Complete Card 1
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Card 2: Reveal '好'
      expect(find.text('好'), findsOneWidget);

      // Complete Card 2
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // After 2 consecutive correct answers: Combo badge 🔥 Combo 2 appears
      expect(find.textContaining('Combo 2'), findsOneWidget);

      // Progress capsule bar has increased
      final progressIndicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(progressIndicator.value, greaterThan(0.5));
    });

    testWidgets('Test 3: Trả lời sai đưa thẻ vào retry queue và xuất hiện lại ở cuối', (tester) async {
      final testCards = [
        const MicroCardModel(
          id: 'quiz_1',
          type: MicroCardType.miniQuiz,
          prompt: 'Chọn chữ Hán cho "bạn":',
          options: ['你', '好', '我'],
          correctIndex: 0,
        ),
        const MicroCardModel(
          id: 'rev_2',
          type: MicroCardType.reveal,
          hanzi: '好',
          pinyin: 'hǎo',
          meaning: 'tốt',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GamifiedLessonPlayer(
              lesson: standardHskLesson,
              initialCards: testCards,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Answer Quiz 1 WRONG: Choose option '好' (index 1)
      expect(find.text('Chọn chữ Hán cho "bạn":'), findsOneWidget);
      await tester.tap(find.text('好'));
      await tester.pumpAndSettle();

      // Feedback should indicate incorrect answer
      expect(find.text('Chưa chính xác'), findsOneWidget);

      // Tap 'Tiếp tục' to dismiss feedback and move forward
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // 2. Next card should be Reveal card '好'
      expect(find.textContaining('TỪ MỚI CỐT LÕI'), findsWidgets);
      expect(find.text('好'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // 3. Since Quiz 1 was answered wrong, it reappears from retry queue!
      expect(find.text('Chọn chữ Hán cho "bạn":'), findsOneWidget);

      // Answer correctly now: Choose '你' (index 0)
      await tester.tap(find.text('你'));
      await tester.pumpAndSettle();

      expect(find.text('Tuyệt vời!'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // 4. Now both cards are completed -> Celebration view is triggered!
      expect(find.byType(LessonCelebrationView), findsOneWidget);
    });

    testWidgets('Test 4: Hoàn thành bài học kích hoạt màn hình ăn mừng và gọi completeLesson', (tester) async {
      bool completionCalled = false;

      final singleCard = [
        const MicroCardModel(
          id: 'c_final',
          type: MicroCardType.reveal,
          hanzi: '好',
          pinyin: 'hǎo',
          meaning: 'tốt',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GamifiedLessonPlayer(
              lesson: standardHskLesson,
              initialCards: singleCard,
              onFinishLesson: () async {
                completionCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Complete the single card
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Celebration View should be visible
      expect(find.byType(LessonCelebrationView), findsOneWidget);
      expect(find.text('Chúc mừng bạn đã hoàn thành bài học!'), findsOneWidget);
      expect(find.text('Đã chinh phục: 1 thẻ tương tác'), findsOneWidget);

      // Tap 'TIẾP TỤC HỌC ➔' on celebration view
      await tester.tap(find.text('TIẾP TỤC HỌC ➔'));
      await tester.pumpAndSettle();

      // Verify onFinishLesson / completeLesson was triggered
      expect(completionCalled, isTrue);
    });
  });

  group('LessonStudyScreen - Gamified Integration Tests', () {
    testWidgets('LessonStudyScreen renders AppBar with Close, Title, and Quick Notes action', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LessonStudyScreen(lesson: standardHskLesson),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AppBar close button
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify AppBar lesson title
      expect(find.text('Bài 1: Xin chào'), findsOneWidget);

      // Verify AppBar Quick Notes book button
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);

      // Verify GamifiedLessonPlayer is present
      expect(find.byType(GamifiedLessonPlayer), findsOneWidget);

      // Tap Quick Notes button to verify sheet opens
      await tester.tap(find.byIcon(Icons.auto_stories_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cẩm nang bài học'), findsOneWidget);
      expect(find.text('Từ vựng trọng tâm'), findsOneWidget);
      expect(find.text('Bí kíp ngữ pháp'), findsOneWidget);
      expect(find.text('Hội thoại mẫu'), findsOneWidget);
    });
  });
}
