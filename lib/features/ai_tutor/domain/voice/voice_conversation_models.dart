import 'package:flutter/foundation.dart';

/// The 10 explicit operational states of the AI Tutor Voice Conversation pipeline.
enum VoiceConversationStatus {
  /// Session is not started.
  idle,

  /// Requesting OS microphone permission.
  requestingPermission,

  /// Initializing audio pipeline, session context, and speech engine.
  connecting,

  /// Microphone is active, capturing user speech with real-time VAD.
  listening,

  /// Transcribing audio and running AI Tutor reasoning / context engine.
  processing,

  /// Playing back AI assistant synthesized speech response.
  speaking,

  /// User interrupted AI speech; playback halted immediately.
  interrupted,

  /// Recovering from transient network or stream drop.
  reconnecting,

  /// An error occurred (permission denied, network failure, etc.).
  error,

  /// Session ended normally; all audio handles and streams released.
  ended,
}

/// A speech transcript segment representing either interim streaming hypotheses
/// or finalized user/assistant utterances.
@immutable
class VoiceTranscriptSegment {
  final String id;
  final String role; // 'user' or 'assistant'
  final String text;
  final String? pinyin;
  final String? translationVi;
  final bool isInterim;
  final DateTime timestamp;

  const VoiceTranscriptSegment({
    required this.id,
    required this.role,
    required this.text,
    this.pinyin,
    this.translationVi,
    this.isInterim = false,
    required this.timestamp,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  VoiceTranscriptSegment copyWith({
    String? id,
    String? role,
    String? text,
    String? pinyin,
    String? translationVi,
    bool? isInterim,
    DateTime? timestamp,
  }) {
    return VoiceTranscriptSegment(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      pinyin: pinyin ?? this.pinyin,
      translationVi: translationVi ?? this.translationVi,
      isInterim: isInterim ?? this.isInterim,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Operational mode for the voice conversation system.
enum VoiceEngineMode {
  /// Production turn-based mode using native AudioRecorder, VAD, AiTutorRepository,
  /// and AudioPlayer.
  turnBasedAudio,

  /// Preview WebSocket bidirectional streaming mode (Gemini Live API via Firebase AI Logic).
  liveStreamingPreview,
}

/// Diagnostic metadata for Firebase AI Logic Live API Preview status.
class LiveApiPreviewInfo {
  final bool isPreview;
  final String previewModelName;
  final String limitationNotice;
  final bool isDeviceSupported;

  const LiveApiPreviewInfo({
    this.isPreview = true,
    this.previewModelName = 'gemini-2.0-flash-exp (Live Multimodal)',
    this.limitationNotice =
        'Tính năng Voice Live API qua Firebase AI Logic hiện đang ở giai đoạn Preview. '
        'Yêu cầu kết nối WebSocket hai chiều và thiết bị thực có cấu hình Audio Focus. '
        'Ứng dụng tự động điều phối giữa Turn-based Audio và Live WebSocket để bảo đảm tính khả dụng.',
    this.isDeviceSupported = true,
  });
}
