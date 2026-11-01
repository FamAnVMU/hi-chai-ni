import 'seed_models.dart';

class ValidationResult {
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    this.errors = const [],
    this.warnings = const [],
  });

  bool get isValid => errors.isEmpty;

  @override
  String toString() =>
      'ValidationResult(isValid: $isValid, errors: ${errors.length}, warnings: ${warnings.length})';
}

class SeedDataValidator {
  // Matches Latin characters, Latin-1 supplement (à, è, ì, ò, ù, á, é, í, ó, ú, ü), Latin Extended A & B (ā, ē, ǎ, ǐ, etc.), spaces, punctuation
  static final RegExp _pinyinRegex = RegExp(
    r'^[a-zA-Z\u00C0-\u00FF\u0100-\u024F\u1E00-\u1EFF\s,·\.\?!' r"'\-:/]+$",
  );

  /// Validates an entire [SeedBundle] against strict integrity rules.
  static ValidationResult validateBundle(SeedBundle bundle) {
    final errors = <String>[];
    final warnings = <String>[];

    if (bundle.bundleName.trim().isEmpty) {
      errors.add('Bundle name cannot be empty.');
    }
    if (bundle.version <= 0) {
      errors.add('Bundle version must be a positive integer.');
    }
    if (bundle.totalItemCount == 0) {
      errors.add('Bundle must contain at least one vocabulary, grammar, or reading item.');
    }

    final seenVocabIds = <String>{};
    final seenSimplified = <String>{};

    for (int i = 0; i < bundle.vocabularies.length; i++) {
      final vocab = bundle.vocabularies[i];
      final prefix = 'Vocab[#$i, id=${vocab.id}]';

      // 1. ID checks
      if (vocab.id.trim().isEmpty) {
        errors.add('$prefix: ID cannot be empty.');
      } else if (!seenVocabIds.add(vocab.id)) {
        errors.add('$prefix: Duplicate ID "${vocab.id}" detected in bundle.');
      }

      // 2. Simplified checks
      if (vocab.simplified.trim().isEmpty) {
        errors.add('$prefix: Simplified Chinese character cannot be empty.');
      } else if (!seenSimplified.add(vocab.simplified)) {
        warnings.add('$prefix: Duplicate simplified word "${vocab.simplified}" in same bundle.');
      }

      // 3. Pinyin checks
      if (vocab.pinyin.trim().isEmpty) {
        errors.add('$prefix: Pinyin cannot be empty.');
      } else if (!_pinyinRegex.hasMatch(vocab.pinyin)) {
        errors.add('$prefix: Pinyin "${vocab.pinyin}" contains illegal characters or malformed tokens.');
      }

      // 4. HSK level checks (1..6)
      if (vocab.hskLevel < 1 || vocab.hskLevel > 6) {
        errors.add('$prefix: HSK level ${vocab.hskLevel} out of valid range (1..6).');
      }

      // 5. Senses checks
      if (vocab.senses.isEmpty) {
        errors.add('$prefix: Must have at least one sense definition.');
      } else {
        final seenSenseIds = <String>{};
        for (int s = 0; s < vocab.senses.length; s++) {
          final sense = vocab.senses[s];
          final sensePrefix = '$prefix Sense[#$s, id=${sense.id}]';

          if (sense.id.trim().isEmpty) {
            errors.add('$sensePrefix: Sense ID cannot be empty.');
          } else if (!seenSenseIds.add(sense.id)) {
            errors.add('$sensePrefix: Duplicate sense ID "${sense.id}" for word "${vocab.simplified}".');
          }

          if (sense.meaningVi.trim().isEmpty) {
            errors.add('$sensePrefix: Vietnamese meaning cannot be empty.');
          }

          // Check examples if present
          for (int e = 0; e < sense.examples.length; e++) {
            final ex = sense.examples[e];
            if (ex.zh.trim().isEmpty || ex.vi.trim().isEmpty) {
              warnings.add('$sensePrefix Example[#$e]: Missing Chinese or Vietnamese text in example.');
            }
          }
        }
      }
    }

    // Grammar checks
    final seenGrammarIds = <String>{};
    for (int i = 0; i < bundle.grammarItems.length; i++) {
      final grammar = bundle.grammarItems[i];
      final prefix = 'Grammar[#$i, id=${grammar.id}]';

      if (grammar.id.trim().isEmpty) {
        errors.add('$prefix: ID cannot be empty.');
      } else if (!seenGrammarIds.add(grammar.id)) {
        errors.add('$prefix: Duplicate Grammar ID "${grammar.id}" detected in bundle.');
      }

      if (grammar.title.trim().isEmpty) {
        errors.add('$prefix: Title cannot be empty.');
      }
      if (grammar.explanationVi.trim().isEmpty) {
        errors.add('$prefix: Vietnamese explanation cannot be empty.');
      }
      if (grammar.hskLevel < 1 || grammar.hskLevel > 6) {
        errors.add('$prefix: HSK level ${grammar.hskLevel} out of valid range (1..6).');
      }
    }

    // Reading checks
    final seenReadingIds = <String>{};
    for (int i = 0; i < bundle.readingPassages.length; i++) {
      final reading = bundle.readingPassages[i];
      final prefix = 'Reading[#$i, id=${reading.id}]';

      if (reading.id.trim().isEmpty) {
        errors.add('$prefix: ID cannot be empty.');
      } else if (!seenReadingIds.add(reading.id)) {
        errors.add('$prefix: Duplicate Reading ID "${reading.id}" detected in bundle.');
      }

      if (reading.title.trim().isEmpty) {
        errors.add('$prefix: Title cannot be empty.');
      }
      if (reading.contentZh.trim().isEmpty) {
        errors.add('$prefix: Chinese content cannot be empty.');
      }
      if (reading.translationVi.trim().isEmpty) {
        errors.add('$prefix: Vietnamese translation cannot be empty.');
      }
      if (reading.hskLevel < 1 || reading.hskLevel > 6) {
        errors.add('$prefix: HSK level ${reading.hskLevel} out of valid range (1..6).');
      }
    }

    return ValidationResult(errors: errors, warnings: warnings);
  }
}
