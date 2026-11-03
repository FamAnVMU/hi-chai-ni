import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/audio/audio_models.dart';
import 'package:hi_chinese/core/audio/audio_player_service.dart';
import 'package:hi_chinese/features/listening/listening.dart';

class _FakeListeningAudioPlayer implements AudioPlayerService {
  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  Duration _position = Duration.zero;
  final Duration _total = const Duration(seconds: 30);
  double _speed = 1.0;
  bool _looping = false;

  final _statusController = StreamController<AudioPlaybackStatus>.broadcast();
  final _posController = StreamController<Duration>.broadcast();

  @override
  AudioPlaybackStatus get status => _status;

  @override
  Duration get currentPosition => _position;

  @override
  Duration get totalDuration => _total;

  @override
  double get playbackSpeed => _speed;

  @override
  bool get isLooping => _looping;

  @override
  Stream<AudioPlaybackStatus> get statusStream => _statusController.stream;

  @override
  Stream<Duration> get positionStream => _posController.stream;

  @override
  Future<void> play(String uri, {double speed = 1.0, bool loop = false, Duration? simulatedDuration}) async {
    _status = AudioPlaybackStatus.playing;
    _speed = speed;
    _looping = loop;
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
    _position = Duration.zero;
    _statusController.add(_status);
    _posController.add(_position);
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    _posController.add(_position);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _speed = speed;
  }

  @override
  Future<void> setLooping(bool loop) async {
    _looping = loop;
  }

  @override
  void dispose() {
    _statusController.close();
    _posController.close();
  }

  void simulatePosition(Duration pos) {
    _position = pos;
    _posController.add(pos);
  }

  void simulateCompleted() {
    _status = AudioPlaybackStatus.completed;
    _position = _total;
    _statusController.add(_status);
    _posController.add(_position);
  }
}

void main() {
  group('Real Listening Playback & Rewind 5s Tests', () {
    late _FakeListeningAudioPlayer fakePlayer;
    late ProviderContainer container;
    late ListeningPlaybackNotifier notifier;

    setUp(() {
      fakePlayer = _FakeListeningAudioPlayer();
      container = ProviderContainer(
        overrides: [
          listeningPlaybackProvider.overrideWith(
            () => ListeningPlaybackNotifier(player: fakePlayer),
          ),
        ],
      );
      notifier = container.read(listeningPlaybackProvider.notifier);
    });

    tearDown(() {
      container.dispose();
      fakePlayer.dispose();
    });

    test('1. Rewind 5 seconds from 15s seeks to exactly 10s', () async {
      await notifier.play('asset:///assets/audio/test.mp3');
      fakePlayer.simulatePosition(const Duration(seconds: 15));
      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.rewind5Seconds();

      expect(container.read(listeningPlaybackProvider).position.inSeconds, equals(10));
      expect(fakePlayer.currentPosition.inSeconds, equals(10));
    });

    test('2. Rewind 5 seconds when current position is < 5s clamps safely to 0:00 (no negative duration)', () async {
      await notifier.play('asset:///assets/audio/test.mp3');
      fakePlayer.simulatePosition(const Duration(seconds: 2));
      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.rewind5Seconds();

      expect(container.read(listeningPlaybackProvider).position, equals(Duration.zero));
      expect(fakePlayer.currentPosition, equals(Duration.zero));
    });

    test('3. Rewind 5 seconds when audio completed rewinds 5 seconds from the end', () async {
      await notifier.play('asset:///assets/audio/test.mp3');
      fakePlayer.simulateCompleted();
      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.rewind5Seconds();

      expect(container.read(listeningPlaybackProvider).position.inSeconds, equals(25)); // 30s total - 5s = 25s
      expect(fakePlayer.currentPosition.inSeconds, equals(25));
    });

    test('4. Slider seek updates audio position and clamps safely to total duration', () async {
      await notifier.play('asset:///assets/audio/test.mp3');

      await notifier.seek(const Duration(seconds: 18));
      expect(container.read(listeningPlaybackProvider).position.inSeconds, equals(18));
      expect(fakePlayer.currentPosition.inSeconds, equals(18));

      // Seek beyond end clamps to totalDuration
      await notifier.seek(const Duration(seconds: 50));
      expect(container.read(listeningPlaybackProvider).position.inSeconds, equals(30));
    });

    test('5. Changing playback speed (0.8x, 1.0x, 1.2x) applies directly to player hardware', () async {
      await notifier.setPlaybackSpeed(0.8);
      expect(container.read(listeningPlaybackProvider).playbackSpeed, equals(0.8));
      expect(fakePlayer.playbackSpeed, equals(0.8));

      await notifier.setPlaybackSpeed(1.2);
      expect(container.read(listeningPlaybackProvider).playbackSpeed, equals(1.2));
      expect(fakePlayer.playbackSpeed, equals(1.2));
    });
  });
}
