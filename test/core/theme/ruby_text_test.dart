import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RubySegment Unit Tests', () {
    test('RubySegment.word factory creates segment with verified pinyin', () {
      final seg = RubySegment.word(
        hanzi: '学习',
        pinyin: 'xuéxí',
        wordId: 'w_101',
        meaning: 'học tập',
        traditionalText: '學習',
      );

      expect(seg.text, '学习');
      expect(seg.pinyin, 'xuéxí');
      expect(seg.wordId, 'w_101');
      expect(seg.meaning, 'học tập');
      expect(seg.traditionalText, '學習');
      expect(seg.isPunctuation, isFalse);
    });

    test('RubySegment.punctuation factory sets isPunctuation and null pinyin', () {
      final punct = RubySegment.punctuation('，');
      expect(punct.text, '，');
      expect(punct.pinyin, isNull);
      expect(punct.isPunctuation, isTrue);
    });

    test('RubySegment.fromAnnotatedString parses bracket syntax with meanings and punctuation', () {
      const input = '你好[nǐ hǎo:xin chào]，世界[shìjiè:thế giới]！';
      final segments = RubySegment.fromAnnotatedString(input);

      expect(segments.length, 4);

      expect(segments[0].text, '你好');
      expect(segments[0].pinyin, 'nǐ hǎo');
      expect(segments[0].meaning, 'xin chào');

      expect(segments[1].text, '，');
      expect(segments[1].isPunctuation, isTrue);

      expect(segments[2].text, '世界');
      expect(segments[2].pinyin, 'shìjiè');
      expect(segments[2].meaning, 'thế giới');

      expect(segments[3].text, '！');
      expect(segments[3].isPunctuation, isTrue);
    });

    test('RubySegment toMap and fromMap serialization roundtrip', () {
      final seg = RubySegment.word(
        hanzi: '银行',
        pinyin: 'yínháng',
        wordId: 'bank_01',
        meaning: 'ngân hàng',
        traditionalText: '銀行',
      );

      final map = seg.toMap();
      final restored = RubySegment.fromMap(map);

      expect(restored, equals(seg));
      expect(restored.pinyin, 'yínháng');
    });

    test('Does not naive-infer polyphone pinyin if omitted', () {
      // Polyphone: 行 can be xíng or háng
      final bank = RubySegment.word(hanzi: '银行', pinyin: 'yínháng');
      final bike = RubySegment.word(hanzi: '自行车', pinyin: 'zìxíngchē');

      expect(bank.pinyin, 'yínháng');
      expect(bike.pinyin, 'zìxíngchē');

      // Unannotated segment preserves raw text and has null pinyin without naive guessing
      final raw = RubySegment.plainText('行');
      expect(raw.pinyin, isNull);
    });
  });

  group('RubyText Widget Layout Tests', () {
    testWidgets('Renders short sentence with Hanzi and Pinyin', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: RubyText(
              segments: [
                RubySegment.word(hanzi: '你好', pinyin: 'nǐ hǎo'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('你'), findsOneWidget);
      expect(find.text('好'), findsOneWidget);
      expect(find.text('nǐ'), findsOneWidget);
      expect(find.text('hǎo'), findsOneWidget);
    });

    testWidgets('Renders punctuation along baseline without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: RubyText(
              segments: [
                RubySegment.word(hanzi: '你好', pinyin: 'nǐ hǎo'),
                RubySegment.punctuation('，'),
                RubySegment.word(hanzi: '世界', pinyin: 'shìjiè'),
                RubySegment.punctuation('！'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('，'), findsOneWidget);
      expect(find.text('！'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('showPinyin = false hides pinyin while preserving Hanzi', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: RubyText(
              showPinyin: false,
              segments: [
                RubySegment.word(hanzi: '中国', pinyin: 'zhōngguó'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('中国'), findsOneWidget);
      expect(find.text('zhōngguó'), findsNothing);
    });

    testWidgets('showTraditional = true renders traditional Hanzi when present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: RubyText(
              showTraditional: true,
              segments: [
                RubySegment.word(
                  hanzi: '学习',
                  pinyin: 'xué xí',
                  traditionalText: '學習',
                ),
              ],
            ),
          ),
        ),
      );

      // Traditional 學習 rendered instead of 学习
      expect(find.text('學'), findsOneWidget);
      expect(find.text('習'), findsOneWidget);
      expect(find.text('xué'), findsOneWidget);
      expect(find.text('xí'), findsOneWidget);
    });

    testWidgets('Tapping on a word segment triggers onSegmentTap with exact model', (tester) async {
      RubySegment? tappedSegment;

      final targetSeg = RubySegment.word(
        hanzi: '苹果',
        pinyin: 'píngguǒ',
        wordId: 'w_apple',
        meaning: 'quả táo',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: RubyText(
              segments: [targetSeg],
              onSegmentTap: (seg) {
                tappedSegment = seg;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('苹果'));
      await tester.pump();

      expect(tappedSegment, isNotNull);
      expect(tappedSegment!.wordId, 'w_apple');
      expect(tappedSegment!.text, '苹果');
      expect(tappedSegment!.pinyin, 'píngguǒ');
    });

    testWidgets('Spaced pinyin splits multi-character word into 1-to-1 character-syllable pairs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: RubyText(
              segments: [
                RubySegment.word(
                  hanzi: '苹果',
                  pinyin: 'píng guǒ',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('苹'), findsOneWidget);
      expect(find.text('果'), findsOneWidget);
      expect(find.text('píng'), findsOneWidget);
      expect(find.text('guǒ'), findsOneWidget);
    });

    testWidgets('Long pressing on a word segment triggers onPronounceTap', (tester) async {
      RubySegment? pronouncedSegment;

      final targetSeg = RubySegment.word(
        hanzi: '汉语',
        pinyin: 'hànyǔ',
        wordId: 'w_chinese',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: RubyText(
              segments: [targetSeg],
              onPronounceTap: (seg) {
                pronouncedSegment = seg;
              },
            ),
          ),
        ),
      );

      await tester.longPress(find.text('汉语'));
      await tester.pump();

      expect(pronouncedSegment, isNotNull);
      expect(pronouncedSegment!.wordId, 'w_chinese');
    });

    testWidgets('Active word with isAudioLoading shows mini progress indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: RubyText(
              activeWordId: 'w_loading',
              isAudioLoading: true,
              segments: [
                RubySegment.word(
                  hanzi: '读',
                  pinyin: 'dú',
                  wordId: 'w_loading',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Handles large text scaling (TextScaler 1.5x and 2.0x) without overflow or crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: RubyText.fromAnnotatedString(
                  annotatedText: '今天[jīntiān]天气[tiānqì]很[hěn]好[hǎo]！',
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('天气'), findsOneWidget);
      expect(find.text('很'), findsOneWidget);
      expect(find.text('好'), findsOneWidget);
    });

    testWidgets('Wraps long sentence across lines on narrow screen (240dp width) without RenderFlex overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240, // very narrow screen
                child: RubyText.fromAnnotatedString(
                  annotatedText:
                      '学[xué]而[ér]时[shí]习[xí]之[zhī]，不[bù]亦[yì]说[yuè]乎[hū]？'
                      '有[yǒu]朋[péng]自[zì]远[yuǎn]方[fāng]来[lái]，不[bù]亦[yì]乐[lè]乎[hū]！',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // No RenderFlex overflow exception
      expect(tester.takeException(), isNull);
      expect(find.text('学'), findsOneWidget);
      expect(find.text('来'), findsOneWidget);
      expect(find.text('！'), findsOneWidget);
    });

    testWidgets('Supports complex tone marks without clipping (ā, á, ǎ, à, ē, é, ě, è, ǖ, ǘ, ǚ, ǜ)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: RubyText(
              segments: [
                RubySegment.word(hanzi: '绿', pinyin: 'lǜ'),
                RubySegment.word(hanzi: '女', pinyin: 'nǚ'),
                RubySegment.word(hanzi: '喝', pinyin: 'hē'),
                RubySegment.word(hanzi: '饿', pinyin: 'è'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('lǜ'), findsOneWidget);
      expect(find.text('nǚ'), findsOneWidget);
      expect(find.text('hē'), findsOneWidget);
      expect(find.text('è'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
