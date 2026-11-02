import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/listening/listening.dart';

void main() {
  group('Listening Domain & Repository Tests', () {
    test('1. Default lessons are well-formed and contain valid questions', () {
      final lessons = ListeningLesson.defaultLessons;
      expect(lessons.isNotEmpty, isTrue);

      for (final lesson in lessons) {
        expect(lesson.id, isNotEmpty);
        expect(lesson.hskLevel, greaterThanOrEqualTo(1));
        expect(lesson.title, isNotEmpty);
        expect(lesson.transcriptZh, isNotEmpty);
        expect(lesson.transcriptPinyin, isNotEmpty);
        expect(lesson.transcriptVi, isNotEmpty);
        expect(lesson.questions.isNotEmpty, isTrue);

        for (final q in lesson.questions) {
          expect(q.prompt, isNotEmpty);
          expect(q.options.length, greaterThanOrEqualTo(2));
          expect(q.correctOptionIndex, inInclusiveRange(0, q.options.length - 1));
          expect(q.isCorrect(q.correctOptionIndex), isTrue);
          expect(q.isCorrect(999), isFalse);
          expect(q.explanationVi, isNotEmpty);
        }
      }
    });

    test('2. DefaultListeningRepository queries lessons by HSK level and ID', () async {
      final repo = DefaultListeningRepository();

      final allLessons = await repo.getLessons();
      expect(allLessons.length, greaterThanOrEqualTo(2));

      final hsk1Lessons = await repo.getLessons(hskLevel: 1);
      expect(hsk1Lessons.every((l) => l.hskLevel == 1), isTrue);

      final hsk2Lessons = await repo.getLessons(hskLevel: 2);
      expect(hsk2Lessons.every((l) => l.hskLevel == 2), isTrue);

      final found = await repo.getLessonById('LIS_HSK1_01_GREETING');
      expect(found, isNotNull);
      expect(found!.id, 'LIS_HSK1_01_GREETING');

      final notFound = await repo.getLessonById('UNKNOWN_ID');
      expect(notFound, isNull);
    });
  });

  group('Listening Playback State Notifier Tests', () {
    test('1. Playback controls update state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(listeningPlaybackProvider.notifier);

      expect(container.read(listeningPlaybackProvider).isPlaying, isFalse);
      notifier.togglePlay();
      expect(container.read(listeningPlaybackProvider).isPlaying, isTrue);

      notifier.setPlaybackSpeed(0.8);
      expect(container.read(listeningPlaybackProvider).playbackSpeed, 0.8);

      notifier.setPlaybackSpeed(1.2);
      expect(container.read(listeningPlaybackProvider).playbackSpeed, 1.2);

      expect(container.read(listeningPlaybackProvider).showTranscript, isFalse);
      notifier.toggleTranscript();
      expect(container.read(listeningPlaybackProvider).showTranscript, isTrue);
    });

    test('2. Question answering and submission records accurately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(listeningPlaybackProvider.notifier);

      notifier.selectAnswer('q1', 0);
      expect(container.read(listeningPlaybackProvider).selectedAnswers['q1'], 0);

      expect(container.read(listeningPlaybackProvider).submittedQuestions['q1'], isNull);
      notifier.submitQuestion('q1');
      expect(container.read(listeningPlaybackProvider).submittedQuestions['q1'], isTrue);
    });
  });

  group('ListeningScreen Widget Tests', () {
    testWidgets('1. Renders lesson title, player controls, transcript toggle, and questions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ListeningScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Luyện Nghe Hiểu (Listening)'), findsOneWidget);
      expect(find.textContaining('Chào hỏi và làm quen'), findsOneWidget);
      expect(find.text('HSK 1'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('Xem lời thoại (Transcript)'), findsOneWidget);
      expect(find.text('Câu Hỏi Đọc Hiểu Nội Dung'), findsOneWidget);
    });

    testWidgets('2. Tapping transcript toggle reveals Chinese transcript box', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ListeningScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lời thoại tiếng Trung (Hanzi):'), findsNothing);

      await tester.tap(find.text('Xem lời thoại (Transcript)'));
      await tester.pumpAndSettle();

      expect(find.text('Lời thoại tiếng Trung (Hanzi):'), findsOneWidget);
      expect(find.text('Ẩn lời thoại (Transcript)'), findsOneWidget);
    });

    testWidgets('3. Selecting an answer enables submit button and shows result', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ListeningScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Select option 'Vương Lệ'
      await tester.tap(find.text('Vương Lệ'));
      await tester.pumpAndSettle();

      // Tap 'Nộp câu trả lời'
      await tester.tap(find.text('Nộp câu trả lời').first);
      await tester.pumpAndSettle();

      expect(find.text('✓ Chính xác!'), findsOneWidget);
    });
  });
}
