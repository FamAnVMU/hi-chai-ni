import 'package:flutter/foundation.dart';

/// Status of audio playback operations.
enum AudioPlaybackStatus {
  idle,
  buffering,
  playing,
  paused,
  stopped,
  completed,
  error,
}

/// Status of microphone recording operations.
enum AudioRecordingStatus {
  idle,
  requestingPermission,
  permissionDenied,
  ready,
  recording,
  paused,
  stopped,
  analyzing,
  error,
}

/// Reasons for immediate audio session aborts to guarantee privacy & OS compliance.
enum AudioSessionInterruptionReason {
  appBackgrounded,
  phoneCallOrLostFocus,
  screenLocked,
  userCanceled,
  permissionRevoked,
}

/// Audio format and specification metadata.
@immutable
class AudioFormatSpec {
  final String mimeType;
  final int sampleRate;
  final int channels;
  final int bitRate;

  const AudioFormatSpec({
    this.mimeType = 'audio/wav',
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitRate = 256000,
  });

  Map<String, dynamic> toMap() => {
        'mime_type': mimeType,
        'sample_rate': sampleRate,
        'channels': channels,
        'bit_rate': bitRate,
      };
}
