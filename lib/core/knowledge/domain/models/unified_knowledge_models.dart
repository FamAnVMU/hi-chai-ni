import '../../../../features/dictionary/domain/models/dictionary_models.dart';
import '../../../../features/grammar/domain/models/grammar_models.dart';
import '../../../../features/hanzi/domain/models/hanzi_models.dart';
import '../../../../features/sentences/domain/models/sentence_models.dart';

/// Aggregated, fully resolved vocabulary details linking:
/// 1. Dictionary definition and senses
/// 2. Constituent Hanzi characters with SVG stroke order paths
/// 3. Verified example sentences containing this word with audio
/// 4. Related grammar structures
class UnifiedVocabularyDetails {
  final DictionaryEntry entry;
  final List<HanziCharacter> constituentCharacters;
  final List<SentenceItem> exampleSentences;
  final List<GrammarItem> relatedGrammar;

  const UnifiedVocabularyDetails({
    required this.entry,
    this.constituentCharacters = const [],
    this.exampleSentences = const [],
    this.relatedGrammar = const [],
  });

  bool get hasStrokesData => constituentCharacters.isNotEmpty;
  bool get hasAudioExamples => exampleSentences.any((s) => s.hasHumanAudio == true);
}

/// Aggregated, fully resolved grammar details linking:
/// 1. Canonical grammar rule, pattern, and explanation
/// 2. Curated examples from source
/// 3. Authentic contextual sentences from corpus (Tatoeba)
/// 4. Related vocabulary items
class UnifiedGrammarDetails {
  final GrammarItem item;
  final List<SentenceItem> corpusSentences;
  final List<DictionaryEntry> relatedVocabulary;

  const UnifiedGrammarDetails({
    required this.item,
    this.corpusSentences = const [],
    this.relatedVocabulary = const [],
  });
}

/// Aggregated, fully resolved Hanzi character details linking:
/// 1. Vector strokes and medians for animation/handwriting
/// 2. HSK vocabulary words containing this character
/// 3. Sentences containing this character
class UnifiedHanziDetails {
  final HanziCharacter character;
  final List<DictionaryEntry> vocabularyWords;
  final List<SentenceItem> exampleSentences;

  const UnifiedHanziDetails({
    required this.character,
    this.vocabularyWords = const [],
    this.exampleSentences = const [],
  });
}

/// Aggregated, fully resolved sentence details linking:
/// 1. Sentence text, Pinyin, and translations
/// 2. Constituent vocabulary words (clickable with popups)
/// 3. Constituent Hanzi characters (for handwriting practice)
/// 4. Illustrated grammar points
/// 5. Audios (human recording vs native OS TTS)
class UnifiedSentenceDetails {
  final SentenceItem sentence;
  final List<DictionaryEntry> constituentWords;
  final List<HanziCharacter> constituentCharacters;
  final List<GrammarItem> illustratedGrammar;

  const UnifiedSentenceDetails({
    required this.sentence,
    this.constituentWords = const [],
    this.constituentCharacters = const [],
    this.illustratedGrammar = const [],
  });
}

/// Summary report of Knowledge Registry synchronization
class KnowledgeSyncReport {
  final int vocabulariesRegistered;
  final int grammarRegistered;
  final int hanziRegistered;
  final int sentencesRegistered;
  final Duration elapsed;

  const KnowledgeSyncReport({
    required this.vocabulariesRegistered,
    required this.grammarRegistered,
    required this.hanziRegistered,
    required this.sentencesRegistered,
    required this.elapsed,
  });

  int get totalRegistered =>
      vocabulariesRegistered + grammarRegistered + hanziRegistered + sentencesRegistered;

  @override
  String toString() =>
      'KnowledgeSyncReport: total=$totalRegistered (vocab=$vocabulariesRegistered, '
      'grammar=$grammarRegistered, hanzi=$hanziRegistered, sentences=$sentencesRegistered) in ${elapsed.inMilliseconds}ms';
}
