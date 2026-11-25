import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/audio/audio.dart';
import '../../helpers/mock_audio_platform.dart';

class _RecordingTtsService implements TtsService {
  final List<String> spokenTexts = [];
  int stopCalls = 0;
  bool disposed = false;

  @override
  Future<List<String>> getAvailableVoices() async => [];

  @override
  Future<bool> isLanguageAvailable(String language) async => true;

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
  void dispose() {
    disposed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    MockAudioPlatformHelper.setupMockPlatformChannels();
  });

  group('AudioPlayerService & TtsService Lifecycle', () {
    test('routes tts: URIs directly to TtsService and stops cleanly', () async {
      final fakeTts = _RecordingTtsService();
      final player = DefaultAudioPlayerService(tts: fakeTts);

      final statuses = <AudioPlaybackStatus>[];
      final sub = player.statusStream.listen(statuses.add);

      await player.play('tts:早上好');
      await Future<void>.delayed(Duration.zero);

      expect(fakeTts.spokenTexts, equals(['早上好']));
      expect(statuses, contains(AudioPlaybackStatus.playing));
      expect(statuses, contains(AudioPlaybackStatus.completed));

      await player.stop();
      expect(fakeTts.stopCalls, greaterThanOrEqualTo(1));

      await sub.cancel();
      player.dispose();
      // Caller owns injected fakeTts when ownsTts == false
      expect(fakeTts.disposed, isFalse);
    });

    test('uses fallbackText when relative audio/ asset is missing from bundle', () async {
      final fakeTts = _RecordingTtsService();
      final AudioPlayerService player = DefaultAudioPlayerService(tts: fakeTts);

      await player.playWithFallback(
        'audio/missing_sentence_999.mp3',
        fallbackText: '请问现在几点？',
      );

      expect(fakeTts.spokenTexts, equals(['请问现在几点？']));
      player.dispose();
    });

    test('DefaultTtsService.stop() invokes flutter_tts stop unconditionally & awaits completion on speak', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (call) async {
          calls.add(call.method);
          return 1;
        },
      );

      final tts = DefaultTtsService();
      await tts.stop();
      expect(calls, contains('stop'));

      calls.clear();
      await tts.speak('你好世界');
      expect(calls, contains('awaitSpeakCompletion'));
      expect(calls, contains('speak'));
      tts.dispose();
    });
  });
}
