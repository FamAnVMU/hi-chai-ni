import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/audio/audio_models.dart';
import 'package:hi_chinese/core/audio/audio_player_service.dart';
import 'package:hi_chinese/core/audio/tts_service.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/lesson_celebration_view.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/lesson_quick_notes_sheet.dart';

class FakeAudioPlayerService implements AudioPlayerService {
  final List<String> playedUris = [];
  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  final _statusController = StreamController<AudioPlaybackStatus>.broadcast();

  @override
  AudioPlaybackStatus get status => _status;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Duration get totalDuration => const Duration(seconds: 2);

  @override
  double get playbackSpeed => 1.0;

  @override
  bool get isLooping => false;

  @override
  Stream<AudioPlaybackStatus> get statusStream => _statusController.stream;

  @override
  Stream<Duration> get positionStream => Stream.value(Duration.zero);

  @override
  Future<void> play(
    String uri, {
    double speed = 1.0,
    bool loop = false,
    Duration? simulatedDuration,
  }) async {
    playedUris.add(uri);
    _status = AudioPlaybackStatus.playing;
    _statusController.add(_status);
  }

  @override
  Future<void> pause() async {
    _status = AudioPlaybackStatus.paused;
    _statusController.add(_status);
  }

  @override
  Future<void> resume() async {
    _status = AudioPlaybackStatus.playing;
    _statusController.add(_status);
  }

  @override
  Future<void> stop() async {
    _status = AudioPlaybackStatus.stopped;
    _statusController.add(_status);
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setLooping(bool loop) async {}

  @override
  void dispose() {
    _statusController.close();
  }
}

class FakeTtsService implements TtsService {
  final List<String> spokenTexts = [];
  bool isZhAvailable = true;

  @override
  Future<bool> isLanguageAvailable(String language) async {
    return isZhAvailable;
  }

  @override
  Future<List<String>> getAvailableVoices() async => ['zh-CN-Standard-A'];

  @override
  Future<void> speak(
    String text, {
    String language = 'zh-CN',
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
    String? voiceName,
  }) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

void main() {
  final sampleLesson = CurriculumLesson(
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
        id: 'seg_vocab',
        lessonId: 'hsk1_l1',
        stepOrder: 2,
        segmentType: 'vocabulary',
        title: 'Từ vựng mới',
        contentPayload: {
          'words': [
            {
              'hanzi': '你',
              'pinyin': 'nǐ',
              'meaning': 'bạn, anh, chị',
              'audio_uri': 'audio/vocab/hsk1_ni.mp3',
            },
            {
              'hanzi': '好',
              'pinyin': 'hǎo',
              'meaning': 'tốt, khỏe, đẹp',
            },
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
            {
              'title': 'Câu chào 你好',
              'structure': 'Đại từ + 好 = Lời chào',
              'explanation': 'Lời chào hỏi thông dụng nhất trong tiếng Trung.',
              'examples': [
                {
                  'sentence_zh': '你好！',
                  'pinyin': 'Nǐ hǎo!',
                  'meaning_vi': 'Xin chào bạn!',
                }
              ]
            }
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
            {
              'speaker': 'A',
              'text_zh': '你好！',
              'pinyin': 'Nǐ hǎo!',
              'text_vi': 'Xin chào bạn!',
            },
            {
              'speaker': 'B',
              'text_zh': '你好！很高兴认识你。',
              'pinyin': 'Nǐ hǎo! Hěn gāoxìng rènshí nǐ.',
              'text_vi': 'Chào bạn! Rất vui được quen biết bạn.',
            },
          ]
        },
      ),
    ],
  );

  group('LessonQuickNotesSheet Tests', () {
    testWidgets('renders all 3 sections: vocabulary, grammar, and dialogue',
        (tester) async {
      final mockAudio = FakeAudioPlayerService();
      final mockTts = FakeTtsService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      LessonQuickNotesSheet.show(
                        context,
                        lesson: sampleLesson,
                        audioPlayer: mockAudio,
                        ttsService: mockTts,
                      );
                    },
                    child: const Text('Open Notes'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Open the sheet
      await tester.tap(find.text('Open Notes'));
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Cẩm nang bài học: 你好 - Xin chào'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify Tab Labels
      expect(find.text('Từ vựng trọng tâm'), findsOneWidget);
      expect(find.text('Bí kíp ngữ pháp'), findsOneWidget);
      expect(find.text('Hội thoại mẫu'), findsOneWidget);

      // 1. Verify Vocabulary Tab Content (active by default)
      expect(find.text('你'), findsOneWidget);
      expect(find.text('nǐ'), findsOneWidget);
      expect(find.text('bạn, anh, chị'), findsOneWidget);
      expect(find.text('好'), findsOneWidget);
      expect(find.text('hǎo'), findsOneWidget);
      expect(find.text('tốt, khỏe, đẹp'), findsOneWidget);

      // Test pronunciation tap
      final speakerButtons = find.byTooltip('Phát âm 你');
      expect(speakerButtons, findsOneWidget);
      await tester.tap(speakerButtons);
      await tester.pump();
      expect(mockAudio.playedUris, contains('audio/vocab/hsk1_ni.mp3'));

      // 2. Switch to Grammar Tab
      await tester.tap(find.text('Bí kíp ngữ pháp'));
      await tester.pumpAndSettle();

      expect(find.text('Câu chào 你好'), findsOneWidget);
      expect(find.text('Đại từ + 好 = Lời chào'), findsOneWidget);
      expect(find.text('Lời chào hỏi thông dụng nhất trong tiếng Trung.'), findsOneWidget);
      expect(find.text('Xin chào bạn!'), findsOneWidget);

      // 3. Switch to Dialogue Tab
      await tester.tap(find.text('Hội thoại mẫu'));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('你好！很高兴认识你。'), findsOneWidget);
      expect(find.text('Nǐ hǎo! Hěn gāoxìng rènshí nǐ.'), findsOneWidget);
      expect(find.text('Chào bạn! Rất vui được quen biết bạn.'), findsOneWidget);

      // 4. Test closing sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Cẩm nang bài học: 你好 - Xin chào'), findsNothing);
    });

    testWidgets('handles fallback cleanly when segments are empty', (tester) async {
      const fallbackLesson = CurriculumLesson(
        id: 'fallback_l1',
        unitId: 'unit_1',
        orderIndex: 1,
        titleVi: 'Bài học cơ bản',
        titleZh: '你好',
        pinyin: 'nǐ hǎo',
        segments: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LessonQuickNotesSheet(
              lesson: fallbackLesson,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Cẩm nang bài học: Bài học cơ bản'), findsOneWidget);

      // Check vocab fallback
      expect(find.text('你好'), findsOneWidget);
      expect(find.text('Bài học cơ bản'), findsOneWidget);

      // Switch to grammar
      await tester.tap(find.text('Bí kíp ngữ pháp'));
      await tester.pumpAndSettle();
      expect(find.text('A + 是 + B = A là B'), findsOneWidget);

      // Switch to dialogue
      await tester.tap(find.text('Hội thoại mẫu'));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('LessonCelebrationView Tests', () {
    testWidgets('displays XP, streak, unlock status card and triggers onContinue',
        (tester) async {
      bool continueCalled = false;
      bool reviewCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonCelebrationView(
              lesson: sampleLesson,
              xpGained: 25,
              streakDays: 5,
              accuracyRate: 0.95,
              nextLessonTitle: 'Bài 2: Cảm ơn bạn',
              onContinue: () {
                continueCalled = true;
              },
              onReviewLesson: () {
                reviewCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Celebratory Visual & Header
      expect(find.text('🎉'), findsOneWidget);
      expect(find.text('Chúc mừng bạn đã hoàn thành bài học!'), findsOneWidget);
      expect(find.text('你好 - Xin chào'), findsOneWidget);

      // 2. Metrics Block (+25 XP & Streak Flame)
      expect(find.text('+25 XP'), findsOneWidget);
      expect(find.text('Điểm kinh nghiệm'), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('5 ngày liên tục'), findsOneWidget);
      expect(find.text('🔥 Chuỗi Streak: 5 ngày liên tục'), findsOneWidget);

      // Accuracy
      expect(find.text('Độ chính xác: 95%'), findsOneWidget);

      // 3. Status card for next lesson unlock
      expect(find.text('✓ Đã mở khóa: Bài 2: Cảm ơn bạn'), findsOneWidget);

      // 4. CTA button
      final continueBtn = find.text('TIẾP TỤC HỌC ➔');
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pump();
      expect(continueCalled, isTrue);

      // 5. Review button
      final reviewBtn = find.text('Xem lại bài học');
      expect(reviewBtn, findsOneWidget);
      await tester.tap(reviewBtn);
      await tester.pump();
      expect(reviewCalled, isTrue);
    });
  });
}
