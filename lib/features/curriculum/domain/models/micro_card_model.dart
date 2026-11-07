import 'package:flutter/foundation.dart';

/// Supported types of interactive micro-cards in the Gamified Player
enum MicroCardType {
  /// Reveal card: Hanzi + Pinyin + Audio + Meaning + Han-Viet
  reveal,

  /// Audio choice: Listen to audio/TTS and choose the matching Hanzi
  audioChoice,

  /// Sentence builder: Arrange word chips in correct order
  sentenceBuilder,

  /// Matching pairs: Match Hanzi with Vietnamese meanings
  matchingPairs,

  /// Mini quiz: Quick multiple-choice question
  miniQuiz,
}

@immutable
class MicroCardModel {
  final String id;
  final MicroCardType type;
  final String title;
  final String? hanzi;
  final String? pinyin;
  final String? meaning;
  final String? hanViet;
  final String? audioUrl;
  final String? audioText;
  final String? prompt;
  final List<String> options;
  final int? correctIndex;
  final String? targetSentence;
  final List<String> sentenceChips;
  final Map<String, String> pairs;
  final String? explanation;
  final String? segmentType;

  const MicroCardModel({
    required this.id,
    required this.type,
    this.title = '',
    this.hanzi,
    this.pinyin,
    this.meaning,
    this.hanViet,
    this.audioUrl,
    this.audioText,
    this.prompt,
    this.options = const [],
    this.correctIndex,
    this.targetSentence,
    this.sentenceChips = const [],
    this.pairs = const {},
    this.explanation,
    this.segmentType,
  });

  MicroCardModel copyWith({
    String? id,
    MicroCardType? type,
    String? title,
    String? hanzi,
    String? pinyin,
    String? meaning,
    String? hanViet,
    String? audioUrl,
    String? audioText,
    String? prompt,
    List<String>? options,
    int? correctIndex,
    String? targetSentence,
    List<String>? sentenceChips,
    Map<String, String>? pairs,
    String? explanation,
    String? segmentType,
  }) {
    return MicroCardModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      hanzi: hanzi ?? this.hanzi,
      pinyin: pinyin ?? this.pinyin,
      meaning: meaning ?? this.meaning,
      hanViet: hanViet ?? this.hanViet,
      audioUrl: audioUrl ?? this.audioUrl,
      audioText: audioText ?? this.audioText,
      prompt: prompt ?? this.prompt,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      targetSentence: targetSentence ?? this.targetSentence,
      sentenceChips: sentenceChips ?? this.sentenceChips,
      pairs: pairs ?? this.pairs,
      explanation: explanation ?? this.explanation,
      segmentType: segmentType ?? this.segmentType,
    );
  }

  @override
  String toString() => 'MicroCardModel(id: $id, type: $type, title: $title)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MicroCardModel && other.id == id && other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, type);
}
