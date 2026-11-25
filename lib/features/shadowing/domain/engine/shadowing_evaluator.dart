import '../models/shadowing_models.dart';

/// Pure mathematical and temporal engine evaluating pacing, duration ratio, and fluency.
class ShadowingEvaluator {
  const ShadowingEvaluator();

  /// Evaluates user's shadowing speech recording against the target segment.
  ShadowingAssessmentResult evaluate({
    required ShadowingSegment segment,
    required Duration userDuration,
    required ShadowingMode mode,
    required ShadowingPlaybackSpeed speed,
    String? audioPath,
    List<double>? amplitudeSamples,
    List<double>? rawDbfsSamples,
  }) {
    final userMs = userDuration.inMilliseconds;
    // Base target duration adjusted by playback speed rate
    final effectiveTargetMs = (segment.durationMs / speed.rate).round();

    if (segment.durationMs <= 0 || effectiveTargetMs <= 0) {
      return ShadowingAssessmentResult(
        segmentId: segment.id,
        targetDurationMs: 0,
        userDurationMs: userMs,
        pacingRatio: 0.0,
        pacingVerdict: 'Thời lượng mẫu không hợp lệ.',
        timelineMatchPercent: 0.0,
        fluencyIndex: 0.0,
        userAudioPath: audioPath,
        mode: mode,
        speed: speed,
        timestamp: DateTime.now(),
      );
    }

    if (userMs < 400) {
      return ShadowingAssessmentResult(
        segmentId: segment.id,
        targetDurationMs: effectiveTargetMs,
        userDurationMs: userMs,
        pacingRatio: 0.0,
        pacingVerdict: 'Thời lượng quá ngắn (< 0.4s). Hãy nói trọn vẹn câu mẫu.',
        timelineMatchPercent: 0.0,
        fluencyIndex: 0.0,
        userAudioPath: audioPath,
        mode: mode,
        speed: speed,
        timestamp: DateTime.now(),
      );
    }

    if (_isSilentRecording(
      amplitudeSamples: amplitudeSamples,
      rawDbfsSamples: rawDbfsSamples,
    )) {
      return ShadowingAssessmentResult(
        segmentId: segment.id,
        targetDurationMs: effectiveTargetMs,
        userDurationMs: userMs,
        pacingRatio: 0.0,
        pacingVerdict:
            'Không phát hiện giọng nói rõ ràng (bản ghi quá nhỏ hoặc im lặng). Vui lòng nói gần micro hơn.',
        timelineMatchPercent: 0.0,
        fluencyIndex: 0.0,
        userAudioPath: audioPath,
        mode: mode,
        speed: speed,
        timestamp: DateTime.now(),
      );
    }

    // Pacing ratio: 1.0 means exact same duration as native sample
    final ratio = userMs / effectiveTargetMs;

    final String verdict;
    if (ratio >= 0.85 && ratio <= 1.15) {
      verdict = 'Chuẩn nhịp độ bản xứ (Tốc độ và trường độ rất tốt)';
    } else if (ratio < 0.85) {
      verdict = 'Nói hơi nhanh (Cần ngân đủ trường độ các nguyên âm)';
    } else {
      verdict = 'Nói hơi chậm (Cần giảm bớt khoảng lặng ngắt nghỉ giữa các từ)';
    }

    // Timeline match: percentage proximity to 1.0
    final diff = (ratio - 1.0).abs();
    final timelineMatch = ((1.0 - diff.clamp(0.0, 1.0)) * 100.0).clamp(10.0, 100.0);

    // Fluency Index: weighted between timeline sync and baseline minimum
    final fluency = (timelineMatch / 100.0).clamp(0.1, 1.0);

    return ShadowingAssessmentResult(
      segmentId: segment.id,
      targetDurationMs: effectiveTargetMs,
      userDurationMs: userMs,
      pacingRatio: double.parse(ratio.toStringAsFixed(2)),
      pacingVerdict: verdict,
      timelineMatchPercent: double.parse(timelineMatch.toStringAsFixed(1)),
      fluencyIndex: double.parse(fluency.toStringAsFixed(2)),
      userAudioPath: audioPath,
      mode: mode,
      speed: speed,
      timestamp: DateTime.now(),
    );
  }

  static bool _isSilentRecording({
    List<double>? amplitudeSamples,
    List<double>? rawDbfsSamples,
  }) {
    if (rawDbfsSamples != null && rawDbfsSamples.isNotEmpty) {
      final peakDbfs = rawDbfsSamples.reduce((a, b) => a > b ? a : b);
      final voicedCount = rawDbfsSamples.where((db) => db >= -45.0).length;
      final voicedRatio = voicedCount / rawDbfsSamples.length;
      return peakDbfs < -35.0 || voicedRatio < 0.25;
    }
    if (amplitudeSamples != null && amplitudeSamples.isNotEmpty) {
      // Normalized scale [0.05 .. 1.0] from [-60 .. 0] dBFS: -35 dBFS ~= 0.417, -45 dBFS = 0.25.
      final peak = amplitudeSamples.reduce((a, b) => a > b ? a : b);
      final voicedCount = amplitudeSamples.where((a) => a >= 0.25).length;
      final voicedRatio = voicedCount / amplitudeSamples.length;
      return peak < 0.417 || voicedRatio < 0.25;
    }
    return false;
  }
}
