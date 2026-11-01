import 'package:flutter/foundation.dart';

/// Supported playback speeds for Shadowing audio model.
enum ShadowingPlaybackSpeed {
  slow(0.75, '0.75x (Chậm)'),
  normal(1.0, '1.0x (Chuẩn)'),
  fast(1.25, '1.25x (Nhanh)');

  final double rate;
  final String labelVi;
  const ShadowingPlaybackSpeed(this.rate, this.labelVi);
}

/// Shadowing training modes.
enum ShadowingMode {
  listenThenRepeat('Nghe rồi nhắc lại (Listen then Repeat)'),
  simultaneous('Nói đuổi song song (Simultaneous)');

  final String labelVi;
  const ShadowingMode(this.labelVi);
}

/// Single conversational unit in a Shadowing document.
@immutable
class ShadowingSegment {
  final String id;
  final int order;
  final String hanzi;
  final String pinyin;
  final String meaningVi;
  final String? audioUri;
  final int durationMs;

  const ShadowingSegment({
    required this.id,
    required this.order,
    required this.hanzi,
    required this.pinyin,
    required this.meaningVi,
    this.audioUri,
    this.durationMs = 3000,
  });
}

/// Structured document partitioned into short sentences for Shadowing.
@immutable
class ShadowingDocument {
  final String id;
  final String title;
  final String description;
  final int hskLevel;
  final List<ShadowingSegment> segments;

  const ShadowingDocument({
    required this.id,
    required this.title,
    required this.description,
    required this.hskLevel,
    required this.segments,
  });

  int get totalDurationMs =>
      segments.fold(0, (acc, s) => acc + s.durationMs);
}

/// Assessment result evaluating pacing, timeline overlap, and fluency
/// without manufacturing fake accent biometric scores.
@immutable
class ShadowingAssessmentResult {
  final String segmentId;
  final int targetDurationMs;
  final int userDurationMs;
  final double pacingRatio; // userDuration / targetDuration
  final String pacingVerdict;
  final double timelineMatchPercent; // 0.0 to 100.0
  final double fluencyIndex; // 0.0 to 1.0
  final String? userAudioPath;
  final ShadowingMode mode;
  final ShadowingPlaybackSpeed speed;
  final String disclaimer;
  final DateTime timestamp;

  const ShadowingAssessmentResult({
    required this.segmentId,
    required this.targetDurationMs,
    required this.userDurationMs,
    required this.pacingRatio,
    required this.pacingVerdict,
    required this.timelineMatchPercent,
    required this.fluencyIndex,
    this.userAudioPath,
    required this.mode,
    required this.speed,
    this.disclaimer =
        'Đánh giá tập trung vào nhịp độ (Pacing) và độ trôi chảy (Fluency). Ứng dụng không đưa ra chấm điểm giả về accent bản xứ.',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'segment_id': segmentId,
        'target_duration_ms': targetDurationMs,
        'user_duration_ms': userDurationMs,
        'pacing_ratio': pacingRatio,
        'pacing_verdict': pacingVerdict,
        'timeline_match_percent': timelineMatchPercent,
        'fluency_index': fluencyIndex,
        'user_audio_path': userAudioPath,
        'mode': mode.name,
        'speed': speed.name,
        'disclaimer': disclaimer,
        'timestamp': timestamp.toIso8601String(),
      };
}
