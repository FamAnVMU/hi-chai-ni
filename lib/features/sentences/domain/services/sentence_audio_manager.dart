import 'dart:async';
import 'dart:io';
import '../../../../core/audio/audio_models.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../models/sentence_models.dart';
import 'native_tts_service.dart';

/// Unified Sentence Audio Manager
/// Manages playback across Human Audio (Tatoeba), Studio Audio, and Native OS TTS.
/// Explicitly reports the audio type and speaker metadata to prevent misleading users.
class SentenceAudioManager {
  final AudioPlayerService _audioPlayer;
  final NativeTtsService _ttsService;

  AudioType _currentAudioType = AudioType.unknown;
  String _currentSpeaker = '';
  double _speed = 1.0;
  bool _isPlaying = false;

  final _playbackStateController = StreamController<bool>.broadcast();
  final _audioTypeController = StreamController<AudioType>.broadcast();

  SentenceAudioManager({
    AudioPlayerService? audioPlayer,
    NativeTtsService? ttsService,
  })  : _audioPlayer = audioPlayer ?? DefaultAudioPlayerService(),
        _ttsService = ttsService ?? DefaultNativeTtsService() {
    _audioPlayer.statusStream.listen((status) {
      if (_currentAudioType != AudioType.nativeOsTts) {
        final playing = status == AudioPlaybackStatus.playing;
        if (_isPlaying != playing) {
          _isPlaying = playing;
          if (!_playbackStateController.isClosed) {
            _playbackStateController.add(playing);
          }
        }
      }
    });

    _ttsService.isSpeakingStream.listen((speaking) {
      if (_currentAudioType == AudioType.nativeOsTts) {
        if (_isPlaying != speaking) {
          _isPlaying = speaking;
          if (!_playbackStateController.isClosed) {
            _playbackStateController.add(speaking);
          }
        }
      }
    });
  }

  AudioType get currentAudioType => _currentAudioType;
  String get currentSpeaker => _currentSpeaker;
  double get speed => _speed;
  bool get isPlaying => _isPlaying;

  Stream<bool> get isPlayingStream => _playbackStateController.stream;
  Stream<AudioType> get audioTypeStream => _audioTypeController.stream;

  /// Plays sentence audio based on prioritized available source:
  /// 1. Real human audio (local file or stream)
  /// 2. Studio simulation audio
  /// 3. Native OS TTS fallback
  Future<void> playSentence(SentenceItem sentence, {double? speed}) async {
    if (speed != null) _speed = speed;

    // 1. Check for human audio
    final humanAudio = sentence.audios.where((a) => a.audioType == AudioType.humanRecording).firstOrNull;
    if (humanAudio != null) {
      final localExists = humanAudio.localPath != null && File(humanAudio.localPath!).existsSync();
      if (localExists) {
        await _playAudioFile(humanAudio.localPath!, AudioType.humanRecording, humanAudio.speakerName);
        return;
      } else if (humanAudio.urlRemote.isNotEmpty) {
        await _playAudioFile(humanAudio.urlRemote, AudioType.humanRecording, humanAudio.speakerName);
        return;
      }
    }

    // 2. Check for studio simulation audio
    final studioAudio = sentence.audios.where((a) => a.audioType == AudioType.studioSimulation).firstOrNull;
    if (studioAudio != null) {
      final localExists = studioAudio.localPath != null && File(studioAudio.localPath!).existsSync();
      if (localExists) {
        await _playAudioFile(studioAudio.localPath!, AudioType.studioSimulation, studioAudio.speakerName);
        return;
      } else if (studioAudio.urlRemote.isNotEmpty) {
        await _playAudioFile(studioAudio.urlRemote, AudioType.studioSimulation, studioAudio.speakerName);
        return;
      }
    }

    // 3. Fallback to Native OS TTS
    await playTts(sentence.chinese, speed: _speed);
  }

  Future<void> playTts(String chineseText, {double? speed}) async {
    await stop();
    _currentAudioType = AudioType.nativeOsTts;
    _currentSpeaker = 'zh-CN (Native TTS)';
    if (!_audioTypeController.isClosed) {
      _audioTypeController.add(_currentAudioType);
    }

    final spd = speed ?? _speed;
    await _ttsService.speak(chineseText, speed: spd);
  }

  Future<void> _playAudioFile(String uri, AudioType type, String speaker) async {
    await stop();
    _currentAudioType = type;
    _currentSpeaker = speaker;
    if (!_audioTypeController.isClosed) {
      _audioTypeController.add(_currentAudioType);
    }

    await _audioPlayer.play(uri, speed: _speed);
  }

  Future<void> setSpeed(double newSpeed) async {
    _speed = newSpeed;
    if (_currentAudioType == AudioType.nativeOsTts) {
      // Will apply on next speak
    } else {
      await _audioPlayer.setPlaybackSpeed(newSpeed);
    }
  }

  Future<void> stop() async {
    if (_currentAudioType == AudioType.nativeOsTts) {
      await _ttsService.stop();
    } else {
      await _audioPlayer.stop();
    }
    _isPlaying = false;
    if (!_playbackStateController.isClosed) {
      _playbackStateController.add(false);
    }
  }

  void dispose() {
    _audioPlayer.stop();
    _ttsService.stop();
    _audioPlayer.dispose();
    _ttsService.dispose();
    _playbackStateController.close();
    _audioTypeController.close();
  }
}
