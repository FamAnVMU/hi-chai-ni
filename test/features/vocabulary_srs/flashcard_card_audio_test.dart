import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/audio/audio_models.dart';
import 'package:hi_chinese/core/audio/audio_player_service.dart';
import 'package:hi_chinese/core/audio/tts_service.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/vocabulary_srs/domain/srs_models.dart';
import 'package:hi_chinese/features/vocabulary_srs/presentation/widgets/flashcard_card.dart';

class FakeAudioPlayerService implements AudioPlayerService {
  final List<String> playedUris = [];
  bool shouldThrow = false;
  int stopCalls = 0;
  final _statusController = StreamController<AudioPlaybackStatus>.broadcast();

  @override
  AudioPlaybackStatus get status => AudioPlaybackStatus.idle;

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
    if (shouldThrow) throw AudioPlaybackException('Audio failed', uri: uri);
    playedUris.add(uri);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
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
  bool isAvailable = true;
  int stopCalls = 0;

  @override
  Future<bool> isLanguageAvailable(String language) async => isAvailable;

  @override
  Future<List<String>> getAvailableVoices() async => [];

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
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  void dispose() {}
}

void main() {
  final sampleCardWithAudio = SrsFlashcardItem(
    id: 'srs_1',
    simplified: '你好',
    pinyin: 'nǐ hǎo',
    hskLevel: 1,
    audioUri: 'assets/audio/hsk1/你好.mp3',
    meaningVi: 'Xin chào',
    srsState: SrsCardState.newCard(id: 's_1', contentId: 'srs_1'),
    estimatedIntervalDays: const {
      SrsRating.again: 0,
      SrsRating.hard: 2,
      SrsRating.good: 4,
      SrsRating.easy: 7,
    },
  );

  final sampleCardNoAudio = SrsFlashcardItem(
    id: 'srs_2',
    simplified: '谢谢',
    pinyin: 'xièxie',
    hskLevel: 1,
    audioUri: null,
    meaningVi: 'Cảm ơn',
    srsState: SrsCardState.newCard(id: 's_2', contentId: 'srs_2'),
    estimatedIntervalDays: const {
      SrsRating.again: 0,
      SrsRating.hard: 2,
      SrsRating.good: 4,
      SrsRating.easy: 7,
    },
  );

  Widget buildTestWidget({
    required SrsFlashcardItem card,
    bool isFlipped = true,
    VoidCallback? onPlayAudio,
    FakeAudioPlayerService? fakePlayer,
    FakeTtsService? fakeTts,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: FlashcardCard(
          card: card,
          isFlipped: isFlipped,
          onFlip: () {},
          onTogglePinyin: () {},
          onPlayAudio: onPlayAudio,
          audioPlayerOverride: fakePlayer,
          ttsServiceOverride: fakeTts,
        ),
      ),
    );
  }

  group('FlashcardCard Real Audio & TTS Tests (F-20)', () {
    testWidgets('1. When parent provides onPlayAudio callback, it takes precedence', (tester) async {
      bool parentCallbackCalled = false;
      final fakePlayer = FakeAudioPlayerService();
      final fakeTts = FakeTtsService();

      await tester.pumpWidget(
        buildTestWidget(
          card: sampleCardWithAudio,
          isFlipped: true,
          onPlayAudio: () {
            parentCallbackCalled = true;
          },
          fakePlayer: fakePlayer,
          fakeTts: fakeTts,
        ),
      );
      await tester.pumpAndSettle();

      final speakerButton = find.byIcon(Icons.volume_up_rounded);
      expect(speakerButton, findsOneWidget);
      await tester.tap(speakerButton);
      await tester.pump();

      expect(parentCallbackCalled, isTrue);
      expect(fakePlayer.playedUris, isEmpty);
      expect(fakeTts.spokenTexts, isEmpty);
    });

    testWidgets('2. When callback is null, plays real audioUri with AudioPlayerService', (tester) async {
      final fakePlayer = FakeAudioPlayerService();
      final fakeTts = FakeTtsService();

      await tester.pumpWidget(
        buildTestWidget(
          card: sampleCardWithAudio,
          isFlipped: true,
          onPlayAudio: null,
          fakePlayer: fakePlayer,
          fakeTts: fakeTts,
        ),
      );
      await tester.pumpAndSettle();

      final speakerButton = find.byIcon(Icons.volume_up_rounded);
      await tester.tap(speakerButton);
      await tester.pump();

      expect(fakePlayer.playedUris, contains('assets/audio/hsk1/你好.mp3'));
      expect(fakeTts.spokenTexts, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('3. When audioUri is null, falls back cleanly to Chinese TTS', (tester) async {
      final fakePlayer = FakeAudioPlayerService();
      final fakeTts = FakeTtsService();

      await tester.pumpWidget(
        buildTestWidget(
          card: sampleCardNoAudio,
          isFlipped: true,
          onPlayAudio: null,
          fakePlayer: fakePlayer,
          fakeTts: fakeTts,
        ),
      );
      await tester.pumpAndSettle();

      final speakerButton = find.byIcon(Icons.volume_up_rounded);
      await tester.tap(speakerButton);
      await tester.pump();

      expect(fakePlayer.playedUris, isEmpty);
      expect(fakeTts.spokenTexts, contains('谢谢'));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('4. When both audio and TTS are unavailable, warns without fake success snackbar', (tester) async {
      final fakePlayer = FakeAudioPlayerService()..shouldThrow = true;
      final fakeTts = FakeTtsService()..isAvailable = false;

      await tester.pumpWidget(
        buildTestWidget(
          card: sampleCardWithAudio,
          isFlipped: true,
          onPlayAudio: null,
          fakePlayer: fakePlayer,
          fakeTts: fakeTts,
        ),
      );
      await tester.pumpAndSettle();

      final speakerButton = find.byIcon(Icons.volume_up_rounded);
      await tester.tap(speakerButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Đang phát âm thanh:'), findsNothing);
      expect(
        find.textContaining('Chưa có file âm thanh hoặc giọng đọc tiếng Trung cho từ "你好".'),
        findsOneWidget,
      );
    });
  });
}
