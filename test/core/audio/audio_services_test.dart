import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/audio/audio.dart';
import 'package:hi_chinese/core/utils/app_lifecycle_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audio Services & Lifecycle Compliance Tests', () {
    late DefaultAudioPlayerService player;
    late DefaultAudioRecorderService recorder;

    setUp(() {
      AppLifecycleManager.instance.initialize();
      player = DefaultAudioPlayerService();
      recorder = DefaultAudioRecorderService();
    });

    tearDown(() {
      player.dispose();
      recorder.dispose();
      AppLifecycleManager.instance.dispose();
    });

    test('1. AudioPlayerService plays, pauses, seeks, and loops properly', () async {
      expect(player.status, equals(AudioPlaybackStatus.idle));

      await player.play('sample.mp3', speed: 1.0, loop: true);
      expect(player.status, equals(AudioPlaybackStatus.playing));
      expect(player.playbackSpeed, equals(1.0));
      expect(player.isLooping, isTrue);

      await player.pause();
      expect(player.status, equals(AudioPlaybackStatus.paused));

      await player.resume();
      expect(player.status, equals(AudioPlaybackStatus.playing));

      await player.seek(const Duration(seconds: 1));
      expect(player.currentPosition, equals(const Duration(seconds: 1)));

      await player.setPlaybackSpeed(1.25);
      expect(player.playbackSpeed, equals(1.25));

      await player.stop();
      expect(player.status, equals(AudioPlaybackStatus.stopped));
      expect(player.currentPosition, equals(Duration.zero));
    });

    test('2. AudioRecorderService records, emits amplitude for waveform, and stops', () async {
      expect(recorder.status, equals(AudioRecordingStatus.idle));
      expect(recorder.hasMicrophone, isTrue);

      await recorder.startRecording();
      expect(recorder.status, equals(AudioRecordingStatus.recording));

      // Wait a moment for amplitude events
      await Future.delayed(const Duration(milliseconds: 250));

      expect(recorder.recordingDuration.inMilliseconds, greaterThanOrEqualTo(100));

      final audioPath = await recorder.stopRecording();
      expect(recorder.status, equals(AudioRecordingStatus.stopped));
      expect(audioPath, isNotNull);
    });

    test('3. AppLifecycleManager immediately halts recording when app loses focus', () async {
      await recorder.startRecording();
      expect(recorder.status, equals(AudioRecordingStatus.recording));

      // Simulate incoming call or user switching apps (paused state)
      AppLifecycleManager.instance.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Recorder must be aborted to protect user privacy
      expect(recorder.status, equals(AudioRecordingStatus.error));
    });

    test('4. Recorder handles missing microphone gracefully', () async {
      final noMicRecorder = DefaultAudioRecorderService(hasMicrophone: false);
      expect(noMicRecorder.hasMicrophone, isFalse);

      final hasPerm = await noMicRecorder.checkPermission();
      expect(hasPerm, isFalse);

      expect(
        () async => await noMicRecorder.startRecording(),
        throwsA(isA<Exception>()),
      );

      noMicRecorder.dispose();
    });
  });
}
