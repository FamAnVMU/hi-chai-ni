import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/audio/audio_models.dart';
import 'package:hi_chinese/core/audio/audio_player_service.dart';
import 'package:hi_chinese/core/audio/tts_service.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/lesson_vocab_view.dart';

class FakeAudioPlayerService implements AudioPlayerService {
  final List<String> playedUris = [];
  bool shouldThrowOnPlay = false;
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
  Future<void> play(String uri, {double speed = 1.0, bool loop = false, Duration? simulatedDuration}) async {
    if (shouldThrowOnPlay) {
      _status = AudioPlaybackStatus.error;
      _statusController.add(_status);
      throw AudioPlaybackException('Simulated playback error', uri: uri);
    }
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
  const dummyLesson = CurriculumLesson(
    id: 'lesson_1_1',
    unitId: 'unit_1',
    orderIndex: 1,
    titleVi: 'Xin chào',
    titleZh: '你好',
    pinyin: 'Nǐ hǎo',
  );

  final sampleSegmentWithAudio = LessonSegment(
    id: 'seg_vocab',
    lessonId: 'lesson_1_1',
    stepOrder: 2,
    segmentType: 'vocabulary',
    title: 'Từ vựng mới',
    contentPayload: {
      'words': [
        {
          'hanzi': '你',
          'pinyin': 'nǐ',
          'meaning_vi': 'bạn',
          'audio_uri': 'assets/audio/hsk1/你.mp3',
        },
        {
          'hanzi': '好',
          'pinyin': 'hǎo',
          'meaning_vi': 'tốt',
        },
      ],
    },
  );

  Widget buildTestWidget({
    required FakeAudioPlayerService fakePlayer,
    required FakeTtsService fakeTts,
    LessonSegment? segment,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: LessonVocabView(
          lesson: dummyLesson,
          segment: segment ?? sampleSegmentWithAudio,
          onNext: () {},
          audioPlayerOverride: fakePlayer,
          ttsServiceOverride: fakeTts,
        ),
      ),
    );
  }

  group('LessonVocabView Real Audio & TTS Tests (F-20)', () {
    testWidgets('1. Word with audio_uri plays directly via AudioPlayerService', (tester) async {
      final fakePlayer = FakeAudioPlayerService();
      final fakeTts = FakeTtsService();

      await tester.pumpWidget(buildTestWidget(fakePlayer: fakePlayer, fakeTts: fakeTts));
      await tester.pumpAndSettle();

      final speakerButtons = find.byIcon(Icons.volume_up_outlined);
      expect(speakerButtons, findsNWidgets(2));

      await tester.tap(speakerButtons.first);
      await tester.pump();

      expect(fakePlayer.playedUris, contains('assets/audio/hsk1/你.mp3'));
      expect(fakeTts.spokenTexts, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('2. Word without audio_uri seamlessly falls back to TTS', (tester) async {
      final fakePlayer = FakeAudioPlayerService();
      final fakeTts = FakeTtsService();

      await tester.pumpWidget(buildTestWidget(fakePlayer: fakePlayer, fakeTts: fakeTts));
      await tester.pumpAndSettle();

      final speakerButtons = find.byIcon(Icons.volume_up_outlined);
      await tester.tap(speakerButtons.at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));

      expect(fakePlayer.playedUris, isEmpty);
      expect(fakeTts.spokenTexts, contains('好'));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('3. Word where AudioPlayer fails seamlessly falls back to TTS', (tester) async {
      final fakePlayer = FakeAudioPlayerService()..shouldThrowOnPlay = true;
      final fakeTts = FakeTtsService();

      await tester.pumpWidget(buildTestWidget(fakePlayer: fakePlayer, fakeTts: fakeTts));
      await tester.pumpAndSettle();

      final speakerButtons = find.byIcon(Icons.volume_up_outlined);
      await tester.tap(speakerButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));

      expect(fakeTts.spokenTexts, contains('你'));
    });

    testWidgets('4. When neither audio nor TTS is available, warns without fake success snackbar', (tester) async {
      final fakePlayer = FakeAudioPlayerService()..shouldThrowOnPlay = true;
      final fakeTts = FakeTtsService()..isZhAvailable = false;

      await tester.pumpWidget(buildTestWidget(fakePlayer: fakePlayer, fakeTts: fakeTts));
      await tester.pumpAndSettle();

      final speakerButtons = find.byIcon(Icons.volume_up_outlined);
      await tester.tap(speakerButtons.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Phát âm chuẩn:'), findsNothing);
      expect(
        find.textContaining('Chưa có file âm thanh hoặc giọng đọc tiếng Trung cho từ "你".'),
        findsOneWidget,
      );
    });
  });
}
