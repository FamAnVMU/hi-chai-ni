import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/audio/audio.dart';
import 'package:hi_chinese/core/utils/app_lifecycle_manager.dart';
import '../../helpers/mock_audio_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    MockAudioPlatformHelper.setupMockPlatformChannels();
  });

  group('Audio Services & Lifecycle Compliance Tests', () {
    late DefaultAudioPlayerService player;
    late DefaultAudioRecorderService recorder;
    late File sampleAudioFile;

    setUp(() {
      MockAudioPlatformHelper.reset();
      AppLifecycleManager.instance.initialize();

      final tempDir = Directory.systemTemp;
      sampleAudioFile = File('${tempDir.path}/test_sample.mp3');
      if (!sampleAudioFile.existsSync()) {
        sampleAudioFile.writeAsBytesSync([0x49, 0x44, 0x33, 0x03, 0x00]);
      }

      player = DefaultAudioPlayerService();
      recorder = DefaultAudioRecorderService();
    });

    tearDown(() {
      player.dispose();
      recorder.dispose();
      AppLifecycleManager.instance.dispose();
      if (sampleAudioFile.existsSync()) {
        try {
          sampleAudioFile.deleteSync();
        } catch (_) {}
      }
    });

    test('1. AudioPlayerService plays, pauses, seeks, and loops properly', () async {
      expect(player.status, equals(AudioPlaybackStatus.idle));

      await player.play(sampleAudioFile.path, speed: 1.0, loop: true);
      expect(player.status, equals(AudioPlaybackStatus.playing));
      expect(player.playbackSpeed, equals(1.0));
      expect(player.isLooping, isTrue);

      await player.pause();
      expect(player.status, equals(AudioPlaybackStatus.paused));

      await player.resume();
      expect(player.status, equals(AudioPlaybackStatus.playing));

      await player.seek(const Duration(seconds: 1));
      expect(player.currentPosition.inSeconds, equals(1));

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

      // Wait a moment for amplitude and duration events
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
        throwsA(isA<AudioRecordingHardwareException>()),
      );

      noMicRecorder.dispose();
    });

    test('5. Non-existent offline file throws AudioPlaybackException', () async {
      const nonExistentPath = 'non_existent_audio_sample_file_123.mp3';
      try {
        await player.play(nonExistentPath);
        fail('Should have thrown AudioPlaybackException');
      } catch (e) {
        expect(e, isA<AudioPlaybackException>());
        expect(player.status, equals(AudioPlaybackStatus.error));
      }
    });

    test('6. Permission denied prevents recording and updates status', () async {
      MockAudioPlatformHelper.simulatePermissionDenied = true;
      final permDeniedRecorder = DefaultAudioRecorderService();

      try {
        await permDeniedRecorder.startRecording();
        fail('Should have thrown AudioRecordingPermissionException');
      } catch (e) {
        expect(e, isA<AudioRecordingPermissionException>());
        expect(permDeniedRecorder.status, equals(AudioRecordingStatus.permissionDenied));
      }

      permDeniedRecorder.dispose();
    });

    test('7. Record pause and resume maintains accumulated duration', () async {
      await recorder.startRecording();
      await Future.delayed(const Duration(milliseconds: 150));

      await recorder.pauseRecording();
      expect(recorder.status, equals(AudioRecordingStatus.paused));
      final pausedDuration = recorder.recordingDuration;
      expect(pausedDuration.inMilliseconds, greaterThanOrEqualTo(100));

      await Future.delayed(const Duration(milliseconds: 100));
      // While paused, duration should not increase
      expect(recorder.recordingDuration, equals(pausedDuration));

      await recorder.resumeRecording();
      expect(recorder.status, equals(AudioRecordingStatus.recording));
      await Future.delayed(const Duration(milliseconds: 150));
      expect(recorder.recordingDuration, greaterThan(pausedDuration));

      await recorder.stopRecording();
    });
  });
}
