import 'package:flutter/foundation.dart';
import 'cat_skill.dart';

/// Represents an item format in the CAT Placement Test.
enum CatItemType {
  multipleChoice,
  pinyinInput,
  strokeOrderChoice,
  audioListeningChoice,
  speakingPrompt;
}

/// An immutable question item in the Computerized Adaptive Testing (CAT) bank.
@immutable
class CatItem {
  final String id;
  final CatSkill skill;
  final CatItemType type;
  final WritingSubType? writingSubType;
  final SpeakingEvaluationMode? speakingMode;

  /// Item difficulty parameter $b$ on the standard normal scale [-3.0, +3.0].
  final double difficulty;

  /// Item discrimination parameter $a$ in the 2PL IRT model (typically 0.8 to 1.8).
  final double discrimination;

  /// Approximate reference HSK level (1 to 5).
  final int hskLevel;

  /// Whether this is a vetted calibration item with known empirical parameters.
  final bool isCalibration;

  /// Prompt text shown to the learner (Vietnamese instruction or Chinese text).
  final String prompt;

  /// Optional Ruby-annotated Chinese text (e.g., `我[wǒ]在[zài]...`).
  final String? annotatedPrompt;

  /// Audio asset path or URI for listening items.
  final String? audioUri;

  /// Multiple choice answer options.
  final List<String> options;

  /// Index of correct option (for multiple choice).
  final int? correctOptionIndex;

  /// Expected string answer (for text/pinyin input).
  final String? correctAnswerText;

  /// Pedagogical explanation shown during review.
  final String explanationVi;

  /// Tag identifier for knowledge gap diagnosis when answered incorrectly.
  final String knowledgeGapTag;

  /// Human-readable Vietnamese label for the knowledge gap.
  final String knowledgeGapLabelVi;

  const CatItem({
    required this.id,
    required this.skill,
    required this.type,
    this.writingSubType,
    this.speakingMode,
    required this.difficulty,
    this.discrimination = 1.0,
    required this.hskLevel,
    this.isCalibration = false,
    required this.prompt,
    this.annotatedPrompt,
    this.audioUri,
    this.options = const [],
    this.correctOptionIndex,
    this.correctAnswerText,
    required this.explanationVi,
    required this.knowledgeGapTag,
    required this.knowledgeGapLabelVi,
  });

  /// Evaluates whether a given user answer string or option index is correct.
  bool checkAnswer(dynamic answer) {
    if (answer == null) return false;

    if (type == CatItemType.multipleChoice ||
        type == CatItemType.strokeOrderChoice ||
        type == CatItemType.audioListeningChoice) {
      if (answer is int && correctOptionIndex != null) {
        return answer == correctOptionIndex;
      }
      if (answer is String && correctOptionIndex != null && correctOptionIndex! < options.length) {
        return answer.trim().toLowerCase() == options[correctOptionIndex!].trim().toLowerCase();
      }
      return false;
    }

    if (type == CatItemType.pinyinInput && correctAnswerText != null) {
      final input = answer.toString().trim().toLowerCase().replaceAll(' ', '');
      final expected = correctAnswerText!.trim().toLowerCase().replaceAll(' ', '');
      return input == expected;
    }

    return false;
  }
}
