import 'dart:async';
import 'dart:io';
import 'audio_models.dart';
import 'audio_player_service.dart';

/// Unified, lifecycle-safe, and singleton audio playback coordinator for HI Chinese.
/// Ensures single-audio focus across Pinyin, Vocabulary, Listening, Reading, and Shadowing.
class UnifiedAudioPlaybackService {
  static final UnifiedAudioPlaybackService instance = UnifiedAudioPlaybackService._internal();

  UnifiedAudioPlaybackService._internal({AudioPlayerService? underlyingPlayer})
      : _player = underlyingPlayer ?? DefaultAudioPlayerService() {
    _statusSubscription = _player.statusStream.listen((status) {
      _statusController.add(status);
    });
    _positionSubscription = _player.positionStream.listen((position) {
      _positionController.add(position);
    });
  }

  factory UnifiedAudioPlaybackService({AudioPlayerService? underlyingPlayer}) {
    if (underlyingPlayer != null) {
      return UnifiedAudioPlaybackService._internal(underlyingPlayer: underlyingPlayer);
    }
    return instance;
  }

  final AudioPlayerService _player;
  StreamSubscription<AudioPlaybackStatus>? _statusSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  final _statusController = StreamController<AudioPlaybackStatus>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();

  String? _currentlyPlayingUri;
  double _volume = 1.0;
  double _speed = 1.0;

  AudioPlaybackStatus get status => _player.status;
  Duration get currentPosition => _player.currentPosition;
  Duration get totalDuration => _player.totalDuration;
  double get playbackSpeed => _speed;
  double get volume => _volume;
  String? get currentlyPlayingUri => _currentlyPlayingUri;

  Stream<AudioPlaybackStatus> get statusStream => _statusController.stream;
  Stream<Duration> get positionStream => _positionController.stream;

  /// Plays an audio file from local path, asset, or remote URI with single-player focus.
  Future<void> playAudio(
    String uri, {
    double speed = 1.0,
    bool loop = false,
    Duration? simulatedDuration,
  }) async {
    // 1. Single-player focus: Stop previous playback immediately
    if (_player.status == AudioPlaybackStatus.playing || _player.status == AudioPlaybackStatus.paused) {
      await _player.stop();
    }

    _speed = speed.clamp(0.5, 2.0);
    _currentlyPlayingUri = uri;

    // 2. Offline file verification
    if (!uri.startsWith('assets/') && !uri.startsWith('http://') && !uri.startsWith('https://')) {
      final file = File(uri);
      if (!await file.exists()) {
        _statusController.add(AudioPlaybackStatus.error);
        throw AudioPlaybackException('Tệp âm thanh ngoại tuyến không tồn tại trên thiết bị.', uri: uri);
      }
    }

    // 3. Delegate to player
    await _player.play(
      uri,
      speed: _speed,
      loop: loop,
      simulatedDuration: simulatedDuration,
    );
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.resume();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentlyPlayingUri = null;
  }

  Future<void> replay() async {
    if (_currentlyPlayingUri != null) {
      await playAudio(_currentlyPlayingUri!, speed: _speed);
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    await _player.setPlaybackSpeed(_speed);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
  }

  void dispose() {
    _statusSubscription?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
  }
}
