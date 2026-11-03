import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'audio_models.dart';

class AudioPlaybackException implements Exception {
  final String message;
  final String uri;
  final dynamic originalError;
  const AudioPlaybackException(this.message, {this.uri = '', this.originalError});

  @override
  String toString() => 'AudioPlaybackException($uri): $message (cause: $originalError)';
}

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

/// Production AudioPlayer implementation powered by `just_audio`.
/// Directly connects to native OS audio hardware (ExoPlayer on Android, AVPlayer on iOS).
/// Supports local files, assets, downloaded content packs, and remote streams with zero simulation.
class DefaultAudioPlayerService implements AudioPlayerService {
  final ja.AudioPlayer _player;
  final bool _ownsPlayer;

  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isLooping = false;

  final _statusController = StreamController<AudioPlaybackStatus>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();

  StreamSubscription<ja.PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  DefaultAudioPlayerService({ja.AudioPlayer? player})
      : _player = player ?? ja.AudioPlayer(),
        _ownsPlayer = player == null {
    _initListeners();
  }

  void _initListeners() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      final newStatus = _mapPlayerStateToStatus(state);
      _updateStatus(newStatus);
    }, onError: (err) {
      debugPrint('[DefaultAudioPlayerService] PlayerState stream error: $err');
      _updateStatus(AudioPlaybackStatus.error);
    });

    _positionSub = _player.positionStream.listen((pos) {
      _currentPosition = pos;
      if (!_positionController.isClosed) {
        _positionController.add(pos);
      }
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        _totalDuration = dur;
      }
    });
  }

  AudioPlaybackStatus _mapPlayerStateToStatus(ja.PlayerState state) {
    switch (state.processingState) {
      case ja.ProcessingState.idle:
        return AudioPlaybackStatus.idle;
      case ja.ProcessingState.loading:
      case ja.ProcessingState.buffering:
        return AudioPlaybackStatus.buffering;
      case ja.ProcessingState.ready:
        return state.playing ? AudioPlaybackStatus.playing : AudioPlaybackStatus.paused;
      case ja.ProcessingState.completed:
        return AudioPlaybackStatus.completed;
    }
  }

  void _updateStatus(AudioPlaybackStatus s) {
    if (_status != s) {
      _status = s;
      if (!_statusController.isClosed) {
        _statusController.add(s);
      }
    }
  }

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
    try {
      _playbackSpeed = speed.clamp(0.5, 2.0);
      _isLooping = loop;

      // Stop previous playback and reset position
      await stop();
      _updateStatus(AudioPlaybackStatus.buffering);

      ja.AudioSource source;
      if (uri.startsWith('assets/')) {
        source = ja.AudioSource.asset(uri);
      } else if (uri.startsWith('http://') || uri.startsWith('https://')) {
        source = ja.AudioSource.uri(Uri.parse(uri));
      } else {
        // Local file
        String cleanPath = uri;
        if (cleanPath.startsWith('file://')) {
          cleanPath = Uri.parse(cleanPath).toFilePath();
        }
        final file = File(cleanPath);
        if (!await file.exists()) {
          _updateStatus(AudioPlaybackStatus.error);
          throw AudioPlaybackException(
            'Tệp âm thanh không tồn tại trên thiết bị: $cleanPath',
            uri: uri,
          );
        }
        source = ja.AudioSource.file(cleanPath);
      }

      final loadedDuration = await _player.setAudioSource(source);
      if (loadedDuration != null) {
        _totalDuration = loadedDuration;
      } else if (simulatedDuration != null) {
        _totalDuration = simulatedDuration;
      }

      await _player.setSpeed(_playbackSpeed);
      await _player.setLoopMode(loop ? ja.LoopMode.one : ja.LoopMode.off);
      await _player.play();

      _updateStatus(AudioPlaybackStatus.playing);
    } catch (e) {
      _updateStatus(AudioPlaybackStatus.error);
      if (e is AudioPlaybackException) {
        rethrow;
      }
      throw AudioPlaybackException(
        'Không thể phát âm thanh: $e',
        uri: uri,
        originalError: e,
      );
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      _updateStatus(AudioPlaybackStatus.paused);
    } catch (_) {}
  }

  @override
  Future<void> resume() async {
    try {
      await _player.play();
      _updateStatus(AudioPlaybackStatus.playing);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      _currentPosition = Duration.zero;
      if (!_positionController.isClosed) {
        _positionController.add(Duration.zero);
      }
      _updateStatus(AudioPlaybackStatus.stopped);
    } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      _currentPosition = position;
      if (!_positionController.isClosed) {
        _positionController.add(position);
      }
      await _player.seek(position);
    } catch (_) {}
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.5, 2.0);
    try {
      await _player.setSpeed(_playbackSpeed);
    } catch (_) {}
  }

  @override
  Future<void> setLooping(bool loop) async {
    _isLooping = loop;
    try {
      await _player.setLoopMode(loop ? ja.LoopMode.one : ja.LoopMode.off);
    } catch (_) {}
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    if (_ownsPlayer) {
      _player.dispose();
    }
    _statusController.close();
    _positionController.close();
  }
}
