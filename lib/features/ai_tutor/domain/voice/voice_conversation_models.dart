import 'package:flutter/foundation.dart';

enum VoiceConversationStatus {
  idle,
  requestingPermission,
  connecting,
  listening,
  processing,
  speaking,
  interrupted,
  reconnecting,
  error,
  ended,
}

enum PersonaPreviewPlaybackState {
  stopped,
  loading,
  playing,
  error,
  unsupported,
}

@immutable
class PersonaVoicePreviewStatus {
  final String personaId;
  final PersonaPreviewPlaybackState state;
  final String? message;
  final bool isTts;

  const PersonaVoicePreviewStatus({
    required this.personaId,
    required this.state,
    this.message,
    this.isTts = false,
  });

  bool get isLoading => state == PersonaPreviewPlaybackState.loading;
  bool get isPlaying => state == PersonaPreviewPlaybackState.playing;
  bool get isStopped => state == PersonaPreviewPlaybackState.stopped;
  bool get isError => state == PersonaPreviewPlaybackState.error;
  bool get isUnsupported => state == PersonaPreviewPlaybackState.unsupported;

  static const PersonaVoicePreviewStatus initial = PersonaVoicePreviewStatus(
    personaId: '',
    state: PersonaPreviewPlaybackState.stopped,
  );
}

@immutable
class VoiceTranscriptSegment {
  final String id;
  final String role;
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

enum VoiceEngineMode {
  turnBasedAudio,
  liveStreamingPreview,
  offlineRuleBased,
  onlineTtsStream,
  firebaseLiveApi,
}

@immutable
class LiveApiPreviewInfo {
  final bool isPreview;
  final String previewModelName;
  final String limitationNotice;
  final bool isDeviceSupported;
  final bool supportsBidirectionalStreaming;
  final bool supportsRealTimeVad;
  final bool isCostFreeExperiment;

  const LiveApiPreviewInfo({
    this.isPreview = true,
    this.previewModelName = 'gemini-2.0-flash-exp (Live Multimodal)',
    this.limitationNotice =
        'Tính năng Voice Live API qua Firebase AI Logic hiện đang ở giai đoạn Preview. '
        'Yêu cầu kết nối WebSocket hai chiều và thiết bị thực có cấu hình Audio Focus. '
        'Ứng dụng tự động điều phối giữa Turn-based Audio và Live WebSocket để bảo đảm tính khả dụng.',
    this.isDeviceSupported = true,
    this.supportsBidirectionalStreaming = true,
    this.supportsRealTimeVad = true,
    this.isCostFreeExperiment = true,
  });
}
