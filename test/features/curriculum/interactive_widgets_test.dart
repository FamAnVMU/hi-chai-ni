import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/interactive_audio_choice.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/interactive_matching_pairs.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/interactive_word_tile_builder.dart';

void main() {
  group('Gamified Interactive Micro-Widgets Tests', () {
    testWidgets(
      'Test 1: InteractiveWordTileBuilder selects chips, deselects chips, preserves compound words, and evaluates correct/incorrect submissions',
      (tester) async {
        bool? lastSubmittedResult;
        bool completedCalled = false;

        // Verify safe compound tokenization preserves '学生' and '老师'
        final tokens = InteractiveWordTileBuilder.tokenizePreservingCompounds(
          '我是学生',
          knownWords: const ['我', '是', '学生', '老师'],
        );
        expect(tokens, equals(['我', '是', '学生']));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: InteractiveWordTileBuilder(
                  prompt: 'Tôi là học sinh',
                  correctTokens: const ['我', '是', '学生'],
                  wordPool: const ['我', '是', '学生', '不', '老师'],
                  onResult: (isCorrect) => lastSubmittedResult = isCorrect,
                  onCompleted: () => completedCalled = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Tôi là học sinh'), findsOneWidget);
        expect(find.text('学生'), findsOneWidget);

        // 1. Select chips to form an incorrect sentence: 我 + 不 + 是 + 老师
        await tester.tap(find.byKey(const ValueKey('source_chip_0_我')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('target_chip_0_我')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('source_chip_3_不')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('target_chip_3_不')), findsOneWidget);

        // 2. Deselect '不' from Target Area -> returns to Source Pool
        await tester.tap(find.byKey(const ValueKey('target_chip_3_不')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('target_chip_3_不')), findsNothing);
        expect(find.byKey(const ValueKey('source_chip_3_不')), findsOneWidget);

        // 3. Submit an incorrect combination: 我 + 老师
        await tester.tap(find.byKey(const ValueKey('source_chip_4_老师')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Kiểm tra'));
        await tester.pumpAndSettle();

        expect(lastSubmittedResult, isFalse);
        expect(completedCalled, isFalse);
        expect(
          find.byKey(const ValueKey('word_tile_correct_answer')),
          findsOneWidget,
        );
        expect(find.textContaining('Đáp án đúng: 我 是 学生'), findsOneWidget);

        // 4. Deselect '老师' and select '是' + '学生' to form the correct sentence: 我是学生
        await tester.tap(find.byKey(const ValueKey('target_chip_4_老师')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('source_chip_1_是')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('source_chip_2_学生')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Kiểm tra'));
        await tester.pumpAndSettle();

        expect(lastSubmittedResult, isTrue);
        expect(completedCalled, isTrue);
        expect(find.text('Chính xác! Tuyệt vời!'), findsOneWidget);
      },
    );

    testWidgets(
      'Test 2: InteractiveMatchingPairs eliminates matched pairs and invokes onCompleted when all 4 pairs are matched',
      (tester) async {
        bool completed = false;

        final pairs = const [
          MatchingPairItem(
            id: 'p1',
            hanzi: '你好',
            pinyin: 'nǐ hǎo',
            meaningVi: 'Xin chào',
          ),
          MatchingPairItem(
            id: 'p2',
            hanzi: '谢谢',
            pinyin: 'xiè xie',
            meaningVi: 'Cảm ơn',
          ),
          MatchingPairItem(
            id: 'p3',
            hanzi: '学生',
            pinyin: 'xué sheng',
            meaningVi: 'Học sinh',
          ),
          MatchingPairItem(
            id: 'p4',
            hanzi: '老师',
            pinyin: 'lǎo shī',
            meaningVi: 'Giáo viên',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: InteractiveMatchingPairs(
                  pairs: pairs,
                  onCompleted: () => completed = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('0/4 cặp'), findsOneWidget);

        // Test mismatch first: tap '你好' and 'Cảm ơn'
        await tester.tap(find.text('你好'));
        await tester.pump();
        await tester.tap(find.text('Cảm ơn'));
        await tester.pump();

        // Wait for mismatch reset timer (450ms)
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('0/4 cặp'), findsOneWidget);
        expect(completed, isFalse);

        // Match Pair 1: 你好 <-> Xin chào
        await tester.tap(find.text('你好'));
        await tester.pump();
        await tester.tap(find.text('Xin chào'));
        await tester.pumpAndSettle();
        expect(find.text('1/4 cặp'), findsOneWidget);

        // Verify matched pair has dimmed opacity and ignores further taps
        final matchedHanziOpacity = tester.widget<AnimatedOpacity>(
          find.byKey(const ValueKey('hanzi_tile_p1')),
        );
        expect(matchedHanziOpacity.opacity, lessThan(1.0));

        // Match Pair 2: 谢谢 <-> Cảm ơn
        await tester.tap(find.text('谢谢'));
        await tester.pump();
        await tester.tap(find.text('Cảm ơn'));
        await tester.pumpAndSettle();
        expect(find.text('2/4 cặp'), findsOneWidget);

        // Match Pair 3: 学生 <-> Học sinh
        await tester.tap(find.text('学生'));
        await tester.pump();
        await tester.tap(find.text('Học sinh'));
        await tester.pumpAndSettle();
        expect(find.text('3/4 cặp'), findsOneWidget);
        expect(completed, isFalse);

        // Match Pair 4: 老师 <-> Giáo viên
        await tester.tap(find.text('老师'));
        await tester.pump();
        await tester.tap(find.text('Giáo viên'));
        await tester.pumpAndSettle();

        expect(find.text('4/4 cặp'), findsOneWidget);
        expect(completed, isTrue);
      },
    );

    testWidgets(
      'Test 3: InteractiveAudioChoice renders primaryBlueDark speaker and responds immediately on option selection',
      (tester) async {
        bool speakerTapped = false;
        bool? selectedResult;
        bool completed = false;

        final options = const [
          AudioChoiceOption(
            id: 'opt_1',
            hanzi: '喝水',
            pinyin: 'hē shuǐ',
            meaningVi: 'Uống nước',
          ),
          AudioChoiceOption(
            id: 'opt_2',
            hanzi: '吃饭',
            pinyin: 'chī fàn',
            meaningVi: 'Ăn cơm',
          ),
          AudioChoiceOption(
            id: 'opt_3',
            hanzi: '看书',
            pinyin: 'kàn shū',
            meaningVi: 'Đọc sách',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: InteractiveAudioChoice(
                  options: options,
                  correctOptionId: 'opt_2',
                  onPlayAudio: () => speakerTapped = true,
                  onResult: (res) => selectedResult = res,
                  onCompleted: () => completed = true,
                ),
              ),
            ),
          ),
        );

        // Verify speaker icon is present with AppColors.primaryBlueDark
        final speakerIcon = tester.widget<Icon>(
          find.byIcon(Icons.volume_up_rounded),
        );
        expect(speakerIcon.color, equals(AppColors.primaryBlueDark));

        // Tap speaker button
        await tester.tap(find.byKey(const ValueKey('audio_choice_speaker_button')));
        await tester.pump();
        expect(speakerTapped, isTrue);

        // Tap wrong option first ('喝水') -> immediate feedback false
        await tester.tap(find.text('喝水'));
        await tester.pumpAndSettle();
        expect(selectedResult, isFalse);
        expect(completed, isFalse);
        expect(
          find.text('Chưa chính xác. Hãy thử nghe lại nhé!'),
          findsOneWidget,
        );

        // Tap correct option ('吃饭') -> immediate feedback true
        await tester.tap(find.text('吃饭'));
        await tester.pumpAndSettle();
        expect(selectedResult, isTrue);
        expect(completed, isTrue);
        expect(
          find.text('Chính xác! Bạn nghe rất chuẩn!'),
          findsOneWidget,
        );
      },
    );
  });
}
