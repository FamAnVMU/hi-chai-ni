import 'package:flutter/foundation.dart';

/// Categories of pronunciation practice.
enum PronunciationCategory {
  tone,
  initial,
  finalSound,
  hskWord,
}

extension PronunciationCategoryX on PronunciationCategory {
  String get labelVi {
    switch (this) {
      case PronunciationCategory.tone:
        return 'Thanh điệu (Tones)';
      case PronunciationCategory.initial:
        return 'Thanh mẫu / Âm đầu (Initials)';
      case PronunciationCategory.finalSound:
        return 'Vận mẫu / Vần (Finals)';
      case PronunciationCategory.hskWord:
        return 'Từ vựng HSK (Vocabulary)';
    }
  }
}

/// Target phoneme or word for pronunciation assessment.
@immutable
class PronunciationTarget {
  final String id;
  final String text; // Hanzi
  final String pinyin;
  final String meaningVi;
  final PronunciationCategory category;
  final String? audioUri;
  final String? ipa;
  final String hintVi;

  const PronunciationTarget({
    required this.id,
    required this.text,
    required this.pinyin,
    required this.meaningVi,
    required this.category,
    this.audioUri,
    this.ipa,
    this.hintVi = '',
  });
}

/// Status of pronunciation evaluation attempt.
enum PronunciationEvaluationStatus {
  success,
  failed,
  unsupported,
  pending,
  insufficientAudio,
}

/// Confidence level of ASR / speech analysis.
enum PronunciationConfidence {
  low,
  medium,
  high,
}

/// Academic-honest assessment result separating speech recognition from acoustic tone analysis.
@immutable
class PronunciationAssessmentResult {
  final String targetId;
  final String targetText;
  final String targetPinyin;
  final String? recognizedTranscript;
  final double? overallScore; // Nullable if provider does not support scoring or offline
  final PronunciationConfidence confidence;
  final PronunciationEvaluationStatus status;

  /// Crucial academic honesty flag:
  /// True ONLY if an acoustic pitch / tone model actually analyzed the waveform.
  /// False if only basic text transcript string comparison occurred.
  final bool isAcousticallyAnalyzed;
  final double? toneAccuracy; // Null if not acoustically analyzed
  final double? initialFinalAccuracy; // Null if not phonetically analyzed
  final List<String> feedbackList;
  final String? audioLocalPath;
  final int recordedDurationMs;
  final String providerId;
  final DateTime timestamp;

  const PronunciationAssessmentResult({
    required this.targetId,
    required this.targetText,
    required this.targetPinyin,
    this.recognizedTranscript,
    this.overallScore,
    this.confidence = PronunciationConfidence.medium,
    this.status = PronunciationEvaluationStatus.success,
    required this.isAcousticallyAnalyzed,
    this.toneAccuracy,
    this.initialFinalAccuracy,
    this.feedbackList = const [],
    this.audioLocalPath,
    this.recordedDurationMs = 0,
    required this.providerId,
    required this.timestamp,
  });

  bool get isRecognizedAccurately {
    if (recognizedTranscript == null) return false;
    final cleanRecognized = recognizedTranscript!.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final cleanTarget = targetText.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return cleanRecognized.contains(cleanTarget) || cleanTarget.contains(cleanRecognized);
  }

  Map<String, dynamic> toMap() => {
        'target_id': targetId,
        'target_text': targetText,
        'target_pinyin': targetPinyin,
        'recognized_transcript': recognizedTranscript,
        'overall_score': overallScore,
        'confidence': confidence.name,
        'status': status.name,
        'is_acoustically_analyzed': isAcousticallyAnalyzed,
        'tone_accuracy': toneAccuracy,
        'initial_final_accuracy': initialFinalAccuracy,
        'feedback': feedbackList,
        'audio_local_path': audioLocalPath,
        'recorded_duration_ms': recordedDurationMs,
        'provider_id': providerId,
        'timestamp': timestamp.toIso8601String(),
      };
}
