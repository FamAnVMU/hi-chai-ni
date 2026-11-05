import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/components/ruby_text/ruby_text.dart';
import 'package:hi_chinese/features/reading/reading.dart';

void main() {
  group('Reading Interactive & RubyText Tap Verification Tests', () {
    testWidgets('1. RubyText tap accurately returns wordId and character offset', (tester) async {
      RubySegment? tappedSegment;

      final segments = [
        RubySegment.word(
          hanzi: '你好',
          pinyin: 'nǐ hǎo',
          wordId: 'VOCAB_NIHAO',
          offset: 0,
        ),
        RubySegment.punctuation('，', offset: 2),
        RubySegment.word(
          hanzi: '世界',
          pinyin: 'shìjiè',
          wordId: 'VOCAB_SHIJIE',
          offset: 3,
        ),
        RubySegment.punctuation('！', offset: 5),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RubyText(
                segments: segments,
                onSegmentTap: (seg) {
                  tappedSegment = seg;
                },
              ),
            ),
          ),
        ),
      );

      // Verify rendering
      expect(find.text('你'), findsOneWidget);
      expect(find.text('好'), findsOneWidget);
      expect(find.text('世界'), findsOneWidget);

      // Tap on '世界'
      await tester.tap(find.text('世界'));
      await tester.pumpAndSettle();

      expect(tappedSegment, isNotNull);
      expect(tappedSegment!.text, equals('世界'));
      expect(tappedSegment!.pinyin, equals('shìjiè'));
      expect(tappedSegment!.wordId, equals('VOCAB_SHIJIE'));
      expect(tappedSegment!.offset, equals(3));

      // Tap on '你好' via character '你'
      await tester.tap(find.text('你'));
      await tester.pumpAndSettle();

      expect(tappedSegment!.text, equals('你好'));
      expect(tappedSegment!.wordId, equals('VOCAB_NIHAO'));
      expect(tappedSegment!.offset, equals(0));
    });

    testWidgets('2. RubySegment.fromAnnotatedString parses wordId and offset correctly', (tester) async {
      const annotated = '你好[nǐ hǎo:xin chào#VOCAB_001]，朋友[péngyou:bạn bè#VOCAB_002]！';
      final segments = RubySegment.fromAnnotatedString(annotated);

      expect(segments, hasLength(4));
      expect(segments[0].text, equals('你好'));
      expect(segments[0].pinyin, equals('nǐ hǎo'));
      expect(segments[0].meaning, equals('xin chào'));
      expect(segments[0].wordId, equals('VOCAB_001'));
      expect(segments[0].offset, equals(0));

      expect(segments[1].isPunctuation, isTrue);

      expect(segments[2].text, equals('朋友'));
      expect(segments[2].pinyin, equals('péngyou'));
      expect(segments[2].wordId, equals('VOCAB_002'));
      expect(segments[2].offset, greaterThan(0));
    });

    testWidgets('3. ReadingModeSelector toggles between 4 display modes', (tester) async {
      ReadingDisplayMode activeMode = ReadingDisplayMode.full;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ReadingModeSelector(
                  currentMode: activeMode,
                  onModeChanged: (ReadingDisplayMode mode) {
                    setState(() => activeMode = mode);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Đầy đủ'), findsOneWidget);
      expect(find.text('Chữ + Pinyin'), findsOneWidget);
      expect(find.text('Chỉ Chữ Hán'), findsOneWidget);
      expect(find.text('Luyện dịch'), findsOneWidget);

      // Select 'Chỉ Chữ Hán'
      await tester.tap(find.text('Chỉ Chữ Hán'));
      await tester.pumpAndSettle();
      expect(activeMode, equals(ReadingDisplayMode.hanziOnly));

      // Select 'Chữ + Pinyin'
      await tester.tap(find.text('Chữ + Pinyin'));
      await tester.pumpAndSettle();
      expect(activeMode, equals(ReadingDisplayMode.hanziAndPinyin));
    });

    testWidgets('4. ReadingQuestionsSection handles answering, score calculation, and explanations', (tester) async {
      final questions = [
        const ReadingQuestion(
          id: 'q1',
          type: ReadingQuestionType.singleChoice,
          question: 'Hôm nay trời thế nào?',
          options: ['Trời mưa', 'Trời đẹp'],
          answerIndex: 1,
          explanationVi: 'Trong bài có câu: Hôm nay thời tiết rất đẹp.',
          citationText: '今天天气很好。',
        ),
      ];

      Map<String, int>? submittedAnswers;
      double? submittedScore;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReadingQuestionsSection(
                questions: questions,
                onSubmitted: (ans, score) {
                  submittedAnswers = ans;
                  submittedScore = score;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Câu Hỏi Đọc Hiểu'), findsOneWidget);
      expect(find.text('Hôm nay trời thế nào?'), findsOneWidget);

      // Select correct option 'Trời đẹp' (index 1)
      await tester.tap(find.text('Trời đẹp'));
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Nộp bài kiểm tra đọc hiểu'));
      await tester.pumpAndSettle();

      expect(submittedAnswers, isNotNull);
      expect(submittedAnswers!['q1'], equals(1));
      expect(submittedScore, equals(100.0));

      // Explanation should now be visible
      expect(find.text('Trong bài có câu: Hôm nay thời tiết rất đẹp.'), findsOneWidget);
      expect(find.text('Trích dẫn: "今天天气很好。"'), findsOneWidget);
    });
  });
}
