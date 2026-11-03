import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/utils/permission_helper.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';

class MockJustAudioPlatform extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    return MockAudioPlayerPlatform(request.id);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) async {
    return DisposeAllPlayersResponse();
  }
}

class MockAudioPlayerPlatform extends AudioPlayerPlatform {
  final _eventController = StreamController<PlaybackEventMessage>.broadcast();
  Duration _position = Duration.zero;
  final Duration _duration = const Duration(seconds: 3);
  double _speed = 1.0;
  bool _playing = false;

  MockAudioPlayerPlatform(super.id) {
    _emitEvent();
  }

  void _emitEvent() {
    if (!_eventController.isClosed) {
      _eventController.add(PlaybackEventMessage(
        processingState: ProcessingStateMessage.ready,
        updatePosition: _position,
        updateTime: DateTime.now(),
        bufferedPosition: _duration,
        duration: _duration,
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ));
    }
  }

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _eventController.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => Stream.value(
        PlayerDataMessage(
          playing: _playing,
          volume: 1.0,
          speed: _speed,
          pitch: 1.0,
          loopMode: LoopModeMessage.off,
          shuffleMode: ShuffleModeMessage.none,
        ),
      );

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _position = Duration.zero;
    _emitEvent();
    return LoadResponse(duration: _duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    _playing = true;
    _emitEvent();
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    _playing = false;
    _emitEvent();
    return PauseResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    return SetVolumeResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    _speed = request.speed;
    return SetSpeedResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async {
    return SetShuffleModeResponse();
  }

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async {
    return SetPitchResponse();
  }

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(SetSkipSilenceRequest request) async {
    return SetSkipSilenceResponse();
  }

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(SetShuffleOrderRequest request) async {
    return SetShuffleOrderResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    if (request.position != null) {
      _position = request.position!;
      _emitEvent();
    }
    return SeekResponse();
  }
}

/// Test utility to mock native audio hardware channels (just_audio, record, permission_handler)
/// during Flutter unit/widget tests without requiring an active Android/iOS emulator.
class MockAudioPlatformHelper {
  static bool _initialized = false;
  static bool _simulatePermissionDenied = false;
  static bool simulateRecordingFailure = false;

  static bool get simulatePermissionDenied => _simulatePermissionDenied;
  static set simulatePermissionDenied(bool val) {
    _simulatePermissionDenied = val;
    if (val) {
      PermissionHelper.mockPermissionStatus = PermissionStatus.denied;
      PermissionHelper.mockPermissionResult = AudioPermissionResult.denied;
    } else {
      PermissionHelper.mockPermissionStatus = PermissionStatus.granted;
      PermissionHelper.mockPermissionResult = AudioPermissionResult.granted;
    }
  }

  static void setupMockPlatformChannels() {
    if (_initialized) return;
    _initialized = true;

    TestWidgetsFlutterBinding.ensureInitialized();

    // 1. Just Audio Platform Mock
    JustAudioPlatform.instance = MockJustAudioPlatform();

    // 2. Permission Handler Mock Channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        if (_simulatePermissionDenied) {
          if (methodCall.method == 'checkPermissionStatus') return 0; // denied
          if (methodCall.method == 'requestPermissions') return {7: 0}; // denied
        }
        if (methodCall.method == 'checkPermissionStatus') {
          return 1; // PermissionStatus.granted
        }
        if (methodCall.method == 'requestPermissions') {
          return {7: 1}; // microphone: granted
        }
        return null;
      },
    );

    // 3. Record Mock Channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'create':
          case 'dispose':
            return null;
          case 'hasPermission':
            return !_simulatePermissionDenied;
          case 'start':
            if (simulateRecordingFailure) {
              throw PlatformException(
                code: 'RECORDING_FAILED',
                message: 'Failed to start native audio recorder',
              );
            }
            return null;
          case 'pause':
          case 'resume':
          case 'cancel':
            return null;
          case 'stop':
            final tempDir = Directory.systemTemp;
            final testFile = File('${tempDir.path}/test_rec_output.m4a');
            testFile.writeAsBytesSync(List.filled(512, 0x01));
            return testFile.path;
          case 'isRecording':
            return true;
          case 'isPaused':
            return false;
          case 'getAmplitude':
            return {'current': -18.5, 'max': -6.0};
          default:
            return null;
        }
      },
    );

    // Sync PermissionHelper
    PermissionHelper.mockPermissionStatus = PermissionStatus.granted;
    PermissionHelper.mockPermissionResult = AudioPermissionResult.granted;
  }

  static void reset() {
    simulatePermissionDenied = false;
    simulateRecordingFailure = false;
    PermissionHelper.mockPermissionStatus = PermissionStatus.granted;
    PermissionHelper.mockPermissionResult = AudioPermissionResult.granted;
  }
}
