import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart' as rec;
import '../utils/app_lifecycle_manager.dart';
import '../utils/permission_helper.dart';
import 'audio_models.dart';

class AudioRecordingPermissionException implements Exception {
  final String message;
  const AudioRecordingPermissionException(this.message);

  @override
  String toString() => 'AudioRecordingPermissionException: $message';
}

class AudioRecordingHardwareException implements Exception {
  final String message;
  final dynamic originalError;
  const AudioRecordingHardwareException(this.message, {this.originalError});

  @override
  String toString() => 'AudioRecordingHardwareException: $message (cause: $originalError)';
}

/// Abstract contract for recording microphone audio with realtime amplitude for waveform.
abstract class AudioRecorderService {
  AudioRecordingStatus get status;
  Duration get recordingDuration;
  String? get currentAudioPath;
  bool get hasMicrophone;

  Stream<AudioRecordingStatus> get statusStream;
  Stream<double> get amplitudeStream;
  Stream<Duration> get durationStream;

  Future<bool> checkPermission();
  Future<void> startRecording({String? destinationPath});
  Future<void> pauseRecording();
  Future<void> resumeRecording();
  Future<String?> stopRecording();
  Future<void> cancelRecording();
  void dispose();
}

/// Production AudioRecorder service powered by the official `record` package.
/// Communicates directly with native OS audio recording hardware (MediaRecorder/AudioRecord on Android).
/// Features real microphone amplitude streaming for waveform visualizers and lifecycle protection.
class DefaultAudioRecorderService implements AudioRecorderService {
  final rec.AudioRecorder _recorder;
  final bool _ownsRecorder;

  AudioRecordingStatus _status = AudioRecordingStatus.idle;
  Duration _recordingDuration = Duration.zero;
  String? _currentAudioPath;
  @override
  final bool hasMicrophone;

  final _statusController = StreamController<AudioRecordingStatus>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  Timer? _durationTimer;
  StreamSubscription<rec.Amplitude>? _amplitudeSub;
  DateTime? _recordingStartTime;
  Duration _accumulatedDuration = Duration.zero;

  DefaultAudioRecorderService({
    this.hasMicrophone = true,
    rec.AudioRecorder? recorder,
  })  : _recorder = recorder ?? rec.AudioRecorder(),
        _ownsRecorder = recorder == null {
    AppLifecycleManager.instance.registerAudioSession(_onLifecycleStop);
  }

  @override
  AudioRecordingStatus get status => _status;

  @override
  Duration get recordingDuration => _recordingDuration;

  @override
  String? get currentAudioPath => _currentAudioPath;

  @override
  Stream<AudioRecordingStatus> get statusStream => _statusController.stream;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  void _updateStatus(AudioRecordingStatus s) {
    if (_status != s) {
      _status = s;
      if (!_statusController.isClosed) {
        _statusController.add(s);
      }
    }
  }

  void _onLifecycleStop(String reason) {
    if (_status == AudioRecordingStatus.recording || _status == AudioRecordingStatus.paused) {
      cancelRecording();
      _updateStatus(AudioRecordingStatus.error);
    }
  }

  @override
  Future<bool> checkPermission() async {
    if (!hasMicrophone) return false;
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('[DefaultAudioRecorderService] checkPermission error: $e');
      final status = await PermissionHelper.checkMicrophoneStatus();
      return status.isGranted;
    }
  }

  @override
  Future<void> startRecording({String? destinationPath}) async {
    if (!hasMicrophone) {
      _updateStatus(AudioRecordingStatus.error);
      throw const AudioRecordingHardwareException(
        'Không tìm thấy thiết bị thu âm (No microphone available).',
      );
    }

    _updateStatus(AudioRecordingStatus.requestingPermission);

    final hasPerm = await checkPermission();
    if (!hasPerm) {
      _updateStatus(AudioRecordingStatus.permissionDenied);
      throw const AudioRecordingPermissionException('Quyền truy cập Microphone bị từ chối.');
    }

    try {
      _recordingDuration = Duration.zero;
      _accumulatedDuration = Duration.zero;

      if (destinationPath != null && destinationPath.isNotEmpty) {
        _currentAudioPath = destinationPath;
      } else {
        Directory tempDir;
        try {
          tempDir = await getTemporaryDirectory();
        } catch (_) {
          tempDir = Directory.systemTemp;
        }
        _currentAudioPath =
            '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      // Voice profile: AAC-LC 16kHz Mono 128kbps (high speech clarity, compact size)
      const config = rec.RecordConfig(
        encoder: rec.AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      );

      await _recorder.start(config, path: _currentAudioPath!);
      _recordingStartTime = DateTime.now();

      _updateStatus(AudioRecordingStatus.recording);

      // Duration tracking & periodic amplitude polling
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (_status != AudioRecordingStatus.recording) return;
        final elapsed = DateTime.now().difference(_recordingStartTime!) + _accumulatedDuration;
        _recordingDuration = elapsed;
        if (!_durationController.isClosed) {
          _durationController.add(_recordingDuration);
        }

        try {
          final amp = await _recorder.getAmplitude();
          final normalized = ((amp.current + 60.0) / 60.0).clamp(0.05, 1.0);
          if (!_amplitudeController.isClosed) {
            _amplitudeController.add(normalized);
          }
        } catch (_) {}
      });

      // Stream hardware amplitude
      _amplitudeSub?.cancel();
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        if (_status != AudioRecordingStatus.recording) return;
        // Map dBFS (-160.0 dB to 0.0 dB) to normalized linear scalar [0.05 .. 1.0]
        final normalized = ((amp.current + 60.0) / 60.0).clamp(0.05, 1.0);
        if (!_amplitudeController.isClosed) {
          _amplitudeController.add(normalized);
        }
      }, onError: (err) {
        debugPrint('[DefaultAudioRecorderService] Amplitude stream error: $err');
      });
    } catch (e) {
      _updateStatus(AudioRecordingStatus.error);
      if (e is AudioRecordingHardwareException || e is AudioRecordingPermissionException) {
        rethrow;
      }
      throw AudioRecordingHardwareException(
        'Lỗi khởi động ghi âm phần cứng: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<void> pauseRecording() async {
    if (_status == AudioRecordingStatus.recording) {
      try {
        await _recorder.pause();
        if (_recordingStartTime != null) {
          _accumulatedDuration += DateTime.now().difference(_recordingStartTime!);
          _recordingStartTime = null;
        }
        _durationTimer?.cancel();
        _updateStatus(AudioRecordingStatus.paused);
      } catch (e) {
        debugPrint('[DefaultAudioRecorderService] pauseRecording error: $e');
      }
    }
  }

  @override
  Future<void> resumeRecording() async {
    if (_status == AudioRecordingStatus.paused) {
      try {
        await _recorder.resume();
        _recordingStartTime = DateTime.now();
        _updateStatus(AudioRecordingStatus.recording);

        _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
          if (_status != AudioRecordingStatus.recording) return;
          final elapsed = DateTime.now().difference(_recordingStartTime!) + _accumulatedDuration;
          _recordingDuration = elapsed;
          if (!_durationController.isClosed) {
            _durationController.add(_recordingDuration);
          }

          try {
            final amp = await _recorder.getAmplitude();
            final normalized = ((amp.current + 60.0) / 60.0).clamp(0.05, 1.0);
            if (!_amplitudeController.isClosed) {
              _amplitudeController.add(normalized);
            }
          } catch (_) {}
        });
      } catch (e) {
        debugPrint('[DefaultAudioRecorderService] resumeRecording error: $e');
      }
    }
  }

  @override
  Future<String?> stopRecording() async {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    _recordingStartTime = null;

    try {
      final path = await _recorder.stop();
      _updateStatus(AudioRecordingStatus.stopped);
      return path ?? _currentAudioPath;
    } catch (e) {
      _updateStatus(AudioRecordingStatus.error);
      throw AudioRecordingHardwareException('Lỗi kết thúc ghi âm: $e', originalError: e);
    }
  }

  @override
  Future<void> cancelRecording() async {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    _recordingStartTime = null;

    try {
      await _recorder.cancel();
      if (_currentAudioPath != null) {
        final f = File(_currentAudioPath!);
        if (await f.exists()) {
          await f.delete();
        }
      }
    } catch (_) {}

    _currentAudioPath = null;
    _recordingDuration = Duration.zero;
    _updateStatus(AudioRecordingStatus.idle);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    if (_ownsRecorder) {
      _recorder.dispose();
    }
    _statusController.close();
    _amplitudeController.close();
    _durationController.close();
  }
}
