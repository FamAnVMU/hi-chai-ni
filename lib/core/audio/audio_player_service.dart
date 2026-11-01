import 'dart:async';
import 'audio_models.dart';

/// Abstract contract for playing native and asset audio streams with speed & loop control.
abstract class AudioPlayerService {
  AudioPlaybackStatus get status;
  Duration get currentPosition;
  Duration get totalDuration;
  double get playbackSpeed;
  bool get isLooping;

  Stream<AudioPlaybackStatus> get statusStream;
  Stream<Duration> get positionStream;

  Future<void> play(
    String uri, {
    double speed = 1.0,
    bool loop = false,
    Duration? simulatedDuration,
  });

  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> setLooping(bool loop);
  void dispose();
}

/// Robust, testable, and reactive AudioPlayer implementation.
class DefaultAudioPlayerService implements AudioPlayerService {
  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = const Duration(seconds: 3);
  double _playbackSpeed = 1.0;
  bool _isLooping = false;

  final _statusController = StreamController<AudioPlaybackStatus>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  Timer? _tickerTimer;

  @override
  AudioPlaybackStatus get status => _status;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  Duration get totalDuration => _totalDuration;

  @override
  double get playbackSpeed => _playbackSpeed;

  @override
  bool get isLooping => _isLooping;

  @override
  Stream<AudioPlaybackStatus> get statusStream => _statusController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<void> play(
    String uri, {
    double speed = 1.0,
    bool loop = false,
    Duration? simulatedDuration,
  }) async {
    await stop();

    _playbackSpeed = speed.clamp(0.5, 2.0);
    _isLooping = loop;
    _totalDuration = simulatedDuration ?? const Duration(milliseconds: 3200);
    _currentPosition = Duration.zero;

    _updateStatus(AudioPlaybackStatus.playing);
    _startTicker();
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    // 50ms ticks scaled by playback speed
    const tickInterval = Duration(milliseconds: 50);
    _tickerTimer = Timer.periodic(tickInterval, (timer) {
      if (_status != AudioPlaybackStatus.playing) return;

      final incrementMs = (50 * _playbackSpeed).round();
      _currentPosition += Duration(milliseconds: incrementMs);

      if (_currentPosition >= _totalDuration) {
        if (_isLooping) {
          _currentPosition = Duration.zero;
          _positionController.add(_currentPosition);
        } else {
          _currentPosition = _totalDuration;
          _positionController.add(_currentPosition);
          _tickerTimer?.cancel();
          _updateStatus(AudioPlaybackStatus.completed);
        }
      } else {
        _positionController.add(_currentPosition);
      }
    });
  }

  @override
  Future<void> pause() async {
    if (_status == AudioPlaybackStatus.playing) {
      _tickerTimer?.cancel();
      _updateStatus(AudioPlaybackStatus.paused);
    }
  }

  @override
  Future<void> resume() async {
    if (_status == AudioPlaybackStatus.paused) {
      _updateStatus(AudioPlaybackStatus.playing);
      _startTicker();
    }
  }

  @override
  Future<void> stop() async {
    _tickerTimer?.cancel();
    _currentPosition = Duration.zero;
    _positionController.add(_currentPosition);
    if (_status != AudioPlaybackStatus.idle && _status != AudioPlaybackStatus.stopped) {
      _updateStatus(AudioPlaybackStatus.stopped);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (position < Duration.zero) {
      _currentPosition = Duration.zero;
    } else if (position > _totalDuration) {
      _currentPosition = _totalDuration;
    } else {
      _currentPosition = position;
    }
    _positionController.add(_currentPosition);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.5, 2.0);
  }

  @override
  Future<void> setLooping(bool loop) async {
    _isLooping = loop;
  }

  void _updateStatus(AudioPlaybackStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(_status);
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _statusController.close();
    _positionController.close();
  }
}
