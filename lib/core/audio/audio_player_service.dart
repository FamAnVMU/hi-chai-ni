import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'audio_models.dart';
import 'tts_service.dart';

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

/// Dispatches `fallbackText` when using [DefaultAudioPlayerService] without
/// breaking existing [AudioPlayerService] test doubles that only override `play`.
extension AudioPlayerServiceFallbackX on AudioPlayerService {
  Future<void> playWithFallback(
    String uri, {
    double speed = 1.0,
    bool loop = false,
    Duration? simulatedDuration,
    String? fallbackText,
  }) {
    final self = this;
    if (self is DefaultAudioPlayerService) {
      return self.play(
        uri,
        speed: speed,
        loop: loop,
        simulatedDuration: simulatedDuration,
        fallbackText: fallbackText,
      );
    }
    return play(
      uri,
      speed: speed,
      loop: loop,
      simulatedDuration: simulatedDuration,
    );
  }
}

/// Production AudioPlayer implementation powered by `just_audio`.
/// Directly connects to native OS audio hardware (ExoPlayer on Android, AVPlayer on iOS).
/// Supports local files, assets, downloaded content packs, and remote streams with zero simulation.
class DefaultAudioPlayerService implements AudioPlayerService {
  final ja.AudioPlayer _player;
  final bool _ownsPlayer;
  TtsService? _tts;
  final bool _ownsTts;

  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _isLooping = false;

  final _statusController = StreamController<AudioPlaybackStatus>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();

  StreamSubscription<ja.PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  DefaultAudioPlayerService({
    ja.AudioPlayer? player,
    TtsService? tts,
  })  : _player = player ?? ja.AudioPlayer(),
        _ownsPlayer = player == null,
        _tts = tts,
        _ownsTts = tts == null {
    _initListeners();
  }

  TtsService get _effectiveTts => _tts ??= DefaultTtsService();

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
    String? fallbackText,
  }) async {
    try {
      _playbackSpeed = speed.clamp(0.5, 2.0);
      _isLooping = loop;

      // Stop previous audio & TTS playback and reset position
      await stop();
      _updateStatus(AudioPlaybackStatus.buffering);

      ja.AudioSource source;
      String cleanUri = uri.trim();
      if (cleanUri.startsWith('asset:///')) {
        cleanUri = cleanUri.replaceFirst('asset:///', '');
      } else if (cleanUri.startsWith('asset://')) {
        cleanUri = cleanUri.replaceFirst('asset://', '');
      }

      // Direct TTS playback URI (`tts:你好`)
      if (cleanUri.startsWith('tts:')) {
        final rawTts = cleanUri.substring(4).trim();
        final ttsText = rawTts.isNotEmpty
            ? rawTts
            : ((fallbackText != null && fallbackText.trim().isNotEmpty)
                ? fallbackText.trim()
                : '你好');
        await _speakWithTtsFallback(ttsText);
        return;
      }

      // Normalize legacy relative `audio/...` paths -> `assets/audio/...`
      if (cleanUri.startsWith('audio/')) {
        cleanUri = 'assets/$cleanUri';
      }

      if (cleanUri.startsWith('assets/')) {
        // Check asset existence before feeding to native player to avoid unhandled crashes
        bool assetExists = false;
        try {
          await rootBundle.load(cleanUri);
          assetExists = true;
        } catch (_) {
          assetExists = false;
        }

        if (assetExists) {
          source = ja.AudioSource.asset(cleanUri);
        } else {
          // Graceful fallback: synthesize speech via TTS engine for missing virtual assets
          debugPrint('[DefaultAudioPlayerService] Asset not bundled: $cleanUri -> Falling back to TTS');
          final effectiveFallback =
              (fallbackText != null && fallbackText.trim().isNotEmpty)
                  ? fallbackText.trim()
                  : _deriveTextFromAudioUri(cleanUri);
          await _speakWithTtsFallback(effectiveFallback);
          return;
        }
      } else if (cleanUri.startsWith('http://') || cleanUri.startsWith('https://')) {
        source = ja.AudioSource.uri(Uri.parse(cleanUri));
      } else {
        // Local file
        String cleanPath = cleanUri;
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
      await _player.setVolume(_volume);
      await _player.setLoopMode(loop ? ja.LoopMode.one : ja.LoopMode.off);
      await _player.play();

      // Do not overwrite `completed` if synchronous/fast playback already completed inside `await _player.play()`
      if (_player.processingState != ja.ProcessingState.completed &&
          _status != AudioPlaybackStatus.completed &&
          _status != AudioPlaybackStatus.stopped &&
          _status != AudioPlaybackStatus.error) {
        _updateStatus(AudioPlaybackStatus.playing);
      }
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

  Future<void> _speakWithTtsFallback(String text) async {
    _updateStatus(AudioPlaybackStatus.playing);
    await _effectiveTts.speak(
      text,
      language: 'zh-CN',
      rate: (_playbackSpeed * 0.5).clamp(0.2, 1.0),
      volume: _volume,
    );
    if (_status != AudioPlaybackStatus.stopped &&
        _status != AudioPlaybackStatus.error) {
      _updateStatus(AudioPlaybackStatus.completed);
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      await _tts?.stop();
      _updateStatus(AudioPlaybackStatus.paused);
    } catch (_) {}
  }

  @override
  Future<void> resume() async {
    try {
      await _player.play();
      if (_player.processingState != ja.ProcessingState.completed &&
          _status != AudioPlaybackStatus.completed &&
          _status != AudioPlaybackStatus.stopped &&
          _status != AudioPlaybackStatus.error) {
        _updateStatus(AudioPlaybackStatus.playing);
      }
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      await _tts?.stop();
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

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
    } catch (_) {}
  }

  /// Extracts a pronounceable Chinese text snippet from the filename for TTS fallback.
  String _deriveTextFromAudioUri(String uri) {
    final fileName = uri.split('/').last.split('.').first;
    final hasHanzi = RegExp(r'[\u4e00-\u9fa5]').hasMatch(fileName);
    if (hasHanzi) {
      return fileName.replaceAll(RegExp(r'^hsk\d+_'), '').replaceAll('_', ' ').trim();
    }
    // Avoid reading internal numeric/ID filenames like `listening_hsk1_01` or `1276691` aloud
    final clean = fileName.replaceAll('_', ' ').replaceAll(RegExp(r'\d+'), '').trim();
    if (clean.isEmpty ||
        RegExp(r'^(hsk|listening|lesson|tat|doc|audio|vocab|dialogue|shadowing|sample)(\s+(hsk|listening|lesson|tat|doc|audio|vocab|dialogue|shadowing|sample|[a-z]{1,2}))*$',
                caseSensitive: false)
            .hasMatch(clean)) {
      return '你好';
    }
    return clean;
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    if (_ownsPlayer) {
      _player.dispose();
    }
    if (_ownsTts && _tts != null) {
      try {
        _tts!.dispose();
      } catch (_) {}
    }
    _statusController.close();
    _positionController.close();
  }
}
