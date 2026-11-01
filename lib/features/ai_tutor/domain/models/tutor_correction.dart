enum TutorErrorCategory {
  none,
  wordChoice,
  wordOrder,
  tonePinyin,
  missingComponent,
  grammarStructure,
  typo,
}

/// Evaluates a learner's utterance with pedagogical 3-step feedback.
/// Enforces anti-hypercorrection: if the user's sentence is correct and natural,
/// [isCorrect] is true and no artificial errors are flagged.
class TutorEvaluation {
  /// Whether the sentence was grammatically correct and naturally phrased.
  final bool isCorrect;

  /// The learner's original input.
  final String originalText;

  /// Best natural Chinese correction (null if original was already correct).
  final String? correctedText;

  /// Pinyin for the corrected sentence (or original if correct).
  final String? pinyin;

  /// 3-step pedagogical explanation in Vietnamese:
  /// 1. Acknowledge and encourage effort.
  /// 2. Point out specific root cause (word choice/order/structure) with Pinyin.
  /// 3. Provide native expression model.
  final String explanationVi;

  /// Categorized error type for learning analytics and evidence collection.
  final TutorErrorCategory errorCategory;

  const TutorEvaluation({
    required this.isCorrect,
    required this.originalText,
    this.correctedText,
    this.pinyin,
    required this.explanationVi,
    this.errorCategory = TutorErrorCategory.none,
  });

  String get encouragementVi => explanationVi.isNotEmpty ? explanationVi : 'Bạn đã diễn đạt rất tốt!';
  String get gentleFeedbackVi => explanationVi;
  String get modelCorrectionZh => correctedText ?? '';

  Map<String, dynamic> toMap() {
    return {
      'is_correct': isCorrect ? 1 : 0,
      'original_text': originalText,
      'corrected_text': correctedText,
      'pinyin': pinyin,
      'explanation_vi': explanationVi,
      'error_category': _categoryString,
    };
  }

  String get _categoryString {
    switch (errorCategory) {
      case TutorErrorCategory.wordChoice:
        return 'word_choice';
      case TutorErrorCategory.wordOrder:
        return 'word_order';
      case TutorErrorCategory.tonePinyin:
        return 'tone_pinyin';
      case TutorErrorCategory.missingComponent:
        return 'missing_component';
      case TutorErrorCategory.grammarStructure:
        return 'grammar_structure';
      case TutorErrorCategory.typo:
        return 'typo';
      case TutorErrorCategory.none:
        return 'none';
    }
  }

  factory TutorEvaluation.fromMap(Map<String, dynamic> map) {
    return TutorEvaluation(
      isCorrect: map['is_correct'] == 1 || map['is_correct'] == true,
      originalText: map['original_text'] as String? ?? '',
      correctedText: map['corrected_text'] as String?,
      pinyin: map['pinyin'] as String?,
      explanationVi: map['explanation_vi'] as String? ?? '',
      errorCategory: _parseCategory(map['error_category']),
    );
  }

  static TutorErrorCategory _parseCategory(dynamic value) {
    if (value == null) return TutorErrorCategory.none;
    final str = value.toString();
    switch (str) {
      case 'word_choice':
      case 'wordChoice':
        return TutorErrorCategory.wordChoice;
      case 'word_order':
      case 'wordOrder':
        return TutorErrorCategory.wordOrder;
      case 'tone_pinyin':
      case 'tonePinyin':
        return TutorErrorCategory.tonePinyin;
      case 'missing_component':
      case 'missingComponent':
        return TutorErrorCategory.missingComponent;
      case 'grammar_structure':
      case 'grammarStructure':
        return TutorErrorCategory.grammarStructure;
      case 'typo':
        return TutorErrorCategory.typo;
      default:
        return TutorErrorCategory.none;
    }
  }

  /// Factory for a correct student sentence where no correction is needed.
  factory TutorEvaluation.correct(String originalText, {String? praiseVi}) {
    return TutorEvaluation(
      isCorrect: true,
      originalText: originalText,
      correctedText: null,
      explanationVi: praiseVi ?? 'Câu của bạn diễn đạt rất tự nhiên và chính xác!',
      errorCategory: TutorErrorCategory.none,
    );
  }
}
