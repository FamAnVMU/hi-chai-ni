/// Model representing an atomic segment in a Ruby (Hanzi + Pinyin) sentence.
///
/// Each segment represents either:
/// 1. A Chinese word or character with its verified Pinyin (e.g. `你好` -> `nǐ hǎo`)
/// 2. Punctuation (e.g. `，`, `。`, `！`, `？`)
/// 3. Plain unannotated text or spaces (e.g. English words, numbers)
class RubySegment {
  /// The base Chinese character(s), punctuation, or plain text
  final String text;

  /// The verified Pinyin annotation with tone marks (e.g., `nǐ hǎo`, `zhōngwén`).
  /// Null if this segment is punctuation, spaces, or has no phonetic guide.
  ///
  /// CRITICAL: To prevent polyphone errors (đa âm tự như 行 xíng/háng, 和 hé/hè/huó),
  /// pinyin must come from a verified dataset rather than naive auto-inference.
  final String? pinyin;

  /// Optional vocabulary or sense ID linking back to the SQLite dictionary
  final String? wordId;

  /// Optional Vietnamese/English meaning or gloss for tooltips / word inspection
  final String? meaning;

  /// Optional Traditional Chinese (phồn thể) representation (e.g. `學`, `漢語`)
  final String? traditionalText;

  /// Whether this segment is punctuation
  final bool isPunctuation;

  const RubySegment({
    required this.text,
    this.pinyin,
    this.wordId,
    this.meaning,
    this.traditionalText,
    bool? isPunctuation,
  }) : isPunctuation = isPunctuation ?? false;

  /// Factory constructor for Chinese words or characters with pinyin
  factory RubySegment.word({
    required String hanzi,
    required String pinyin,
    String? wordId,
    String? meaning,
    String? traditionalText,
  }) {
    return RubySegment(
      text: hanzi,
      pinyin: pinyin.trim(),
      wordId: wordId,
      meaning: meaning,
      traditionalText: traditionalText,
      isPunctuation: false,
    );
  }

  /// Factory constructor for punctuation marks
  factory RubySegment.punctuation(String punctuation) {
    return RubySegment(
      text: punctuation,
      pinyin: null,
      wordId: null,
      meaning: null,
      traditionalText: null,
      isPunctuation: true,
    );
  }

  /// Factory constructor for unannotated plain text or whitespace
  factory RubySegment.plainText(String plainText) {
    return RubySegment(
      text: plainText,
      pinyin: null,
      wordId: null,
      meaning: null,
      traditionalText: null,
      isPunctuation: false,
    );
  }

  /// Convenient parser for annotated bracket syntax:
  /// Example: `你好[nǐ hǎo]，世界[shìjiè]！`
  /// or with meaning: `你好[nǐ hǎo:xin chào]，世界[shìjiè:thế giới]！`
  static List<RubySegment> fromAnnotatedString(String annotatedText) {
    final List<RubySegment> segments = [];
    final pattern = RegExp(r'([\u4e00-\u9fa5a-zA-Z0-9]+)\[([^[\]]+)\]|([，。！？；：“”‘’（）《》、\.,!\?;:\(\)\s]+)|([^\[\]\s，。！？；：“”‘’（）《》、\.,!\?;:\(\)]+)');
    final punctuationRegex = RegExp(r'^[，。！？；：“”‘’（）《》、\.,!\?;:\(\)]+$');

    final matches = pattern.allMatches(annotatedText);

    for (final match in matches) {
      if (match.group(1) != null && match.group(2) != null) {
        // Annotated word: hanzi[pinyin] or hanzi[pinyin:meaning]
        final hanzi = match.group(1)!;
        final rawAnnotation = match.group(2)!;
        String pinyin = rawAnnotation;
        String? meaning;

        if (rawAnnotation.contains(':')) {
          final parts = rawAnnotation.split(':');
          pinyin = parts[0].trim();
          meaning = parts.sublist(1).join(':').trim();
        }

        segments.add(RubySegment.word(
          hanzi: hanzi,
          pinyin: pinyin,
          meaning: meaning,
        ));
      } else if (match.group(3) != null) {
        // Punctuation or whitespace
        final val = match.group(3)!;
        if (punctuationRegex.hasMatch(val.trim())) {
          segments.add(RubySegment.punctuation(val));
        } else {
          segments.add(RubySegment.plainText(val));
        }
      } else if (match.group(4) != null) {
        // Unannotated text
        final val = match.group(4)!;
        if (punctuationRegex.hasMatch(val)) {
          segments.add(RubySegment.punctuation(val));
        } else {
          segments.add(RubySegment.plainText(val));
        }
      }
    }

    // Fallback if regex did not match anything
    if (segments.isEmpty && annotatedText.isNotEmpty) {
      segments.add(RubySegment.plainText(annotatedText));
    }

    return segments;
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      if (pinyin != null) 'pinyin': pinyin,
      if (wordId != null) 'word_id': wordId,
      if (meaning != null) 'meaning': meaning,
      if (traditionalText != null) 'traditional_text': traditionalText,
      'is_punctuation': isPunctuation,
    };
  }

  factory RubySegment.fromMap(Map<String, dynamic> map) {
    return RubySegment(
      text: map['text'] as String,
      pinyin: map['pinyin'] as String?,
      wordId: map['word_id'] as String?,
      meaning: map['meaning'] as String?,
      traditionalText: map['traditional_text'] as String?,
      isPunctuation: map['is_punctuation'] as bool? ?? false,
    );
  }

  RubySegment copyWith({
    String? text,
    String? pinyin,
    String? wordId,
    String? meaning,
    String? traditionalText,
    bool? isPunctuation,
  }) {
    return RubySegment(
      text: text ?? this.text,
      pinyin: pinyin ?? this.pinyin,
      wordId: wordId ?? this.wordId,
      meaning: meaning ?? this.meaning,
      traditionalText: traditionalText ?? this.traditionalText,
      isPunctuation: isPunctuation ?? this.isPunctuation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RubySegment &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          pinyin == other.pinyin &&
          wordId == other.wordId &&
          meaning == other.meaning &&
          traditionalText == other.traditionalText &&
          isPunctuation == other.isPunctuation;

  @override
  int get hashCode =>
      text.hashCode ^
      pinyin.hashCode ^
      wordId.hashCode ^
      meaning.hashCode ^
      traditionalText.hashCode ^
      isPunctuation.hashCode;

  @override
  String toString() =>
      'RubySegment(text: $text, pinyin: $pinyin, wordId: $wordId, meaning: $meaning)';
}
