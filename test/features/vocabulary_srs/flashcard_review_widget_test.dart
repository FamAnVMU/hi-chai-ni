import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/dictionary/presentation/widgets/quick_dictionary_sheet.dart';
import 'package:hi_chinese/features/review/presentation/screens/review_screen.dart';
import 'package:hi_chinese/features/vocabulary_srs/vocabulary_srs.dart';

void main() {
  SrsFlashcardItem createSampleCard({
    String id = 'VOCAB_001',
    String simplified = '银行',
    String? traditional = '銀行',
    String pinyin = 'yínháng',
    int hskLevel = 2,
    int strokeCount = 11,
    String meaningVi = 'Ngân hàng',
    String exampleCn = '我[wǒ]去[qù]银行[yínháng]取[qǔ]钱[qián]。',
    String exampleVi = 'Tôi đến ngân hàng rút tiền.',
    String? audioUri = 'assets/audio/yinhang.mp3',
  }) {
    final srs = SrsCardState(
      id: 'SRS_VOCAB_$id',
      contentId: id,
      repetitions: 1,
      intervalDays: 1,
      dueAt: DateTime.now().toUtc(),
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    return SrsFlashcardItem(
      id: id,
      simplified: simplified,
      traditional: traditional,
      pinyin: pinyin,
      hskLevel: hskLevel,
      strokeCount: strokeCount,
      radicals: '钅',
      audioUri: audioUri,
      partOfSpeech: 'danh từ',
      meaningVi: meaningVi,
      exampleCn: exampleCn,
      examplePinyin: 'Wǒ qù yínháng qǔ qián.',
      exampleVi: exampleVi,
      srsState: srs,
      estimatedIntervalDays: const {
        SrsRating.again: 1,
        SrsRating.hard: 2,
        SrsRating.good: 4,
        SrsRating.easy: 8,
      },
    );
  }

  Widget createTestWidget({
    required Widget child,
    List<dynamic>? overrides,
  }) {
    return ProviderScope(
      overrides: (overrides ?? []).cast(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('Flashcard & SRS Review Widget Tests', () {
    testWidgets('1. Renders front face with Hanzi, Pinyin toggle, and flip button', (tester) async {
      final card = createSampleCard();
      final initialSession = SrsStudySession(queue: [card]);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            srsStudySessionProvider.overrideWith(
              () => _TestSrsStudySessionNotifier(initialSession),
            ),
            srsDueCountProvider.overrideWith(() => _TestSrsDueCountNotifier(1)),
          ],
          child: const ReviewScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Front Face elements
      expect(find.text('银行'), findsOneWidget);
      expect(find.text('yínháng'), findsOneWidget);
      expect(find.text('HSK 2'), findsOneWidget);
      expect(find.text('11 nét'), findsOneWidget);
      expect(find.text('Xem đáp án (Lật thẻ)'), findsOneWidget);

      // Pinyin toggle
      final pinyinToggleFinder = find.byTooltip('Ẩn Pinyin');
      expect(pinyinToggleFinder, findsOneWidget);
      await tester.tap(pinyinToggleFinder);
      await tester.pumpAndSettle();

      // After toggle, tooltip is 'Hiện Pinyin' and pinyin on front is hidden
      expect(find.byTooltip('Hiện Pinyin'), findsOneWidget);
      expect(find.text('yínháng'), findsNothing);
    });

    testWidgets('2. Flipping card reveals back face with definition, examples, audio, and rating bar', (tester) async {
      final card = createSampleCard();
      final initialSession = SrsStudySession(
        queue: [card],
        isAnswerRevealed: true, // Flipped to back
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            srsStudySessionProvider.overrideWith(
              () => _TestSrsStudySessionNotifier(initialSession),
            ),
            srsDueCountProvider.overrideWith(() => _TestSrsDueCountNotifier(1)),
          ],
          child: const ReviewScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Back Face elements
      expect(find.text('Ngân hàng'), findsOneWidget);
      expect(find.text('danh từ'), findsOneWidget);
      expect(find.text('Ví dụ câu:'), findsOneWidget);
      expect(find.text('Tôi đến ngân hàng rút tiền.'), findsOneWidget);

      // 4 Rating buttons
      expect(find.text('Quên'), findsOneWidget);
      expect(find.text('Khó'), findsOneWidget);
      expect(find.text('Nhớ'), findsOneWidget);
      expect(find.text('Dễ'), findsOneWidget);

      // Preview intervals
      expect(find.text('< 10 phút'), findsOneWidget);
      expect(find.text('2 ngày'), findsOneWidget);
      expect(find.text('4 ngày'), findsOneWidget);
      expect(find.text('8 ngày'), findsOneWidget);
    });

    testWidgets('3. Rating selection advances to next card and updates progress', (tester) async {
      final card1 = createSampleCard(id: 'VOCAB_001', simplified: '银行');
      final card2 = createSampleCard(id: 'VOCAB_002', simplified: '朋友', pinyin: 'péngyou', meaningVi: 'Bạn bè');

      final initialSession = SrsStudySession(
        queue: [card1, card2],
        currentIndex: 0,
        isAnswerRevealed: true,
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            srsStudySessionProvider.overrideWith(
              () => _TestSrsStudySessionNotifier(initialSession),
            ),
            srsDueCountProvider.overrideWith(() => _TestSrsDueCountNotifier(2)),
          ],
          child: const ReviewScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Thẻ 1 / 2'), findsOneWidget);

      // Tap 'Nhớ' (Good)
      await tester.ensureVisible(find.text('Nhớ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhớ'));
      await tester.pumpAndSettle();

      // Advanced to card 2: 朋友
      expect(find.text('Thẻ 2 / 2'), findsOneWidget);
      expect(find.text('朋友'), findsOneWidget);
      expect(find.text('Xem đáp án (Lật thẻ)'), findsOneWidget);
    });

    testWidgets('4. Anti-tap protection disables buttons when review is processing', (tester) async {
      final card = createSampleCard();
      final initialSession = SrsStudySession(
        queue: [card],
        isAnswerRevealed: true,
        isProcessingReview: true, // Review in-flight
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            srsStudySessionProvider.overrideWith(
              () => _TestSrsStudySessionNotifier(initialSession),
            ),
            srsDueCountProvider.overrideWith(() => _TestSrsDueCountNotifier(1)),
          ],
          child: const ReviewScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Rating button InkWell onTap should be null when isProcessingReview is true
      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.bySemanticsLabel(RegExp('Đánh giá Nhớ')),
          matching: find.byType(InkWell),
        ),
      );
      expect(inkWell.onTap, isNull);
    });

    testWidgets('5. Empty queue displays FlashcardEmptyState with reload action', (tester) async {
      final initialSession = const SrsStudySession(
        queue: [],
        completedReviewsCount: 15,
        correctReviewsCount: 14,
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            srsStudySessionProvider.overrideWith(
              () => _TestSrsStudySessionNotifier(initialSession),
            ),
            srsDueCountProvider.overrideWith(() => _TestSrsDueCountNotifier(0)),
          ],
          child: const ReviewScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Xuất Sắc! Hoàn Thành Ôn Tập'), findsOneWidget);
      expect(find.text('15 thẻ'), findsOneWidget);
      expect(find.text('93%'), findsOneWidget);
      expect(find.text('Học thêm 15 từ mới'), findsOneWidget);
    });

    testWidgets('6. Tapping dictionary button on back face opens QuickDictionarySheet', (tester) async {
      final card = createSampleCard();
      final initialSession = SrsStudySession(
        queue: [card],
        isAnswerRevealed: true,
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            srsStudySessionProvider.overrideWith(
              () => _TestSrsStudySessionNotifier(initialSession),
            ),
            srsDueCountProvider.overrideWith(() => _TestSrsDueCountNotifier(1)),
          ],
          child: const ReviewScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final dictButton = find.byTooltip('Mở chi tiết từ điển');
      expect(dictButton, findsOneWidget);
      await tester.tap(dictButton);
      await tester.pumpAndSettle();

      // QuickDictionarySheet opened
      expect(find.byType(QuickDictionarySheet), findsOneWidget);
    });

    testWidgets('7. Layout renders without overflow on narrow 320dp screen', (tester) async {
      final card = createSampleCard();
      final initialSession = SrsStudySession(
        queue: [card],
        isAnswerRevealed: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            srsStudySessionProvider.overrideWith(
              () => _TestSrsStudySessionNotifier(initialSession),
            ),
            srsDueCountProvider.overrideWith(() => _TestSrsDueCountNotifier(1)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(320, 600)),
              child: const ReviewScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull); // 0 overflows on narrow viewport
      expect(find.text('Ngân hàng'), findsOneWidget);
    });
  });
}

class _TestSrsStudySessionNotifier extends SrsStudySessionNotifier {
  final SrsStudySession mockSession;

  _TestSrsStudySessionNotifier(this.mockSession);

  @override
  Future<SrsStudySession> build() async {
    return mockSession;
  }

  @override
  void flipCard() {
    final current = state.value ?? mockSession;
    state = AsyncValue.data(
      current.copyWith(isAnswerRevealed: !current.isAnswerRevealed),
    );
  }

  @override
  void togglePinyinVisibility() {
    final current = state.value ?? mockSession;
    state = AsyncValue.data(
      current.copyWith(isPinyinVisibleOnFront: !current.isPinyinVisibleOnFront),
    );
  }

  @override
  Future<void> submitRating(SrsRating rating) async {
    final current = state.value ?? mockSession;
    if (current.isProcessingReview) return;

    final isSuccess = rating != SrsRating.again;
    state = AsyncValue.data(
      current.copyWith(
        currentIndex: current.currentIndex + 1,
        isAnswerRevealed: false,
        completedReviewsCount: current.completedReviewsCount + 1,
        correctReviewsCount: current.correctReviewsCount + (isSuccess ? 1 : 0),
      ),
    );
  }
}

class _TestSrsDueCountNotifier extends SrsDueCountNotifier {
  final int mockCount;

  _TestSrsDueCountNotifier(this.mockCount);

  @override
  Future<int> build() async {
    return mockCount;
  }
}
