import '../models/practice_models.dart';

/// Comprehensive validator verifying structural integrity of exercise definitions
class ExerciseValidator {
  const ExerciseValidator();

  /// Validates an exercise definition. Returns empty list if valid.
  List<ExerciseValidationError> validate(ExerciseDefinition def) {
    final errors = <ExerciseValidationError>[];

    // 1. Universal metadata validation
    if (def.id.trim().isEmpty) {
      errors.add(const ExerciseValidationError(field: 'id', message: 'Exercise ID must not be empty.'));
    }
    if (def.prompt.trim().isEmpty) {
      errors.add(const ExerciseValidationError(field: 'prompt', message: 'Prompt must not be empty.'));
    }
    if (def.skill.trim().isEmpty) {
      errors.add(const ExerciseValidationError(field: 'skill', message: 'Skill must not be empty.'));
    }
    if (def.hskLevel < 1 || def.hskLevel > 6) {
      errors.add(const ExerciseValidationError(field: 'hskLevel', message: 'HSK level must be between 1 and 6.'));
    }
    if (def.explanationVi.trim().isEmpty) {
      errors.add(const ExerciseValidationError(field: 'explanationVi', message: 'Pedagogical explanation is required.'));
    }

    // 2. Type-specific validation
    switch (def.type) {
      case ExerciseType.multipleChoice:
        if (def.options.length < 2) {
          errors.add(const ExerciseValidationError(
            field: 'options',
            message: 'Multiple choice exercises require at least 2 options.',
          ));
        }
        if (def.correctOptionIndex == null ||
            def.correctOptionIndex! < 0 ||
            def.correctOptionIndex! >= def.options.length) {
          errors.add(const ExerciseValidationError(
            field: 'correctOptionIndex',
            message: 'A valid correctOptionIndex within range is required.',
          ));
        }
        break;

      case ExerciseType.selectMeaningOrPinyin:
        if (def.stimulus == null || def.stimulus!.trim().isEmpty) {
          errors.add(const ExerciseValidationError(
            field: 'stimulus',
            message: 'SelectMeaningOrPinyin exercise requires a target stimulus (word or character).',
          ));
        }
        if (def.options.length < 2) {
          errors.add(const ExerciseValidationError(
            field: 'options',
            message: 'SelectMeaningOrPinyin exercise requires at least 2 options.',
          ));
        }
        if (def.correctOptionIndex == null ||
            def.correctOptionIndex! < 0 ||
            def.correctOptionIndex! >= def.options.length) {
          errors.add(const ExerciseValidationError(
            field: 'correctOptionIndex',
            message: 'A valid correctOptionIndex within range is required.',
          ));
        }
        break;

      case ExerciseType.matchingPairs:
        if (def.matchingPairs.length < 2) {
          errors.add(const ExerciseValidationError(
            field: 'matchingPairs',
            message: 'Matching pairs exercise requires at least 2 distinct pairs.',
          ));
        }
        for (final entry in def.matchingPairs.entries) {
          if (entry.key.trim().isEmpty || entry.value.trim().isEmpty) {
            errors.add(const ExerciseValidationError(
              field: 'matchingPairs',
              message: 'Pair keys and values must not be blank.',
            ));
            break;
          }
        }
        break;

      case ExerciseType.fillInTheBlank:
        final sentence = def.sentenceWithBlank ?? def.stimulus ?? '';
        if (!sentence.contains('___') && !sentence.contains('{blank}') && !sentence.contains('_')) {
          errors.add(const ExerciseValidationError(
            field: 'sentenceWithBlank',
            message: 'FillInTheBlank sentence must contain a blank indicator ("___" or "_").',
          ));
        }
        final hasAnswer = (def.blankAnswer != null && def.blankAnswer!.trim().isNotEmpty) ||
            def.acceptableAnswers.isNotEmpty;
        if (!hasAnswer) {
          errors.add(const ExerciseValidationError(
            field: 'blankAnswer',
            message: 'A target blankAnswer or acceptableAnswers list is required.',
          ));
        }
        if (def.blankOptions.isNotEmpty && def.blankAnswer != null) {
          if (!def.blankOptions.contains(def.blankAnswer)) {
            errors.add(const ExerciseValidationError(
              field: 'blankOptions',
              message: 'blankOptions bank must contain the correct blankAnswer.',
            ));
          }
        }
        break;

      case ExerciseType.reorderWords:
        if (def.tokens.length < 2) {
          errors.add(const ExerciseValidationError(
            field: 'tokens',
            message: 'Reorder words exercise requires at least 2 tokens.',
          ));
        }
        if (def.targetSentence == null || def.targetSentence!.trim().isEmpty) {
          errors.add(const ExerciseValidationError(
            field: 'targetSentence',
            message: 'Target reconstructed sentence is required for reorder exercises.',
          ));
        }
        break;

      case ExerciseType.trueFalseOrErrorDetection:
        final hasBoolean = def.isTrue != null;
        final hasErrorToken = def.errorToken != null && def.errorToken!.trim().isNotEmpty;

        if (!hasBoolean && !hasErrorToken) {
          errors.add(const ExerciseValidationError(
            field: 'isTrue/errorToken',
            message: 'Must provide either isTrue boolean or errorToken to detect.',
          ));
        }
        if (hasErrorToken) {
          final text = def.stimulus ?? def.sentenceWithBlank ?? '';
          if (!text.contains(def.errorToken!)) {
            errors.add(const ExerciseValidationError(
              field: 'errorToken',
              message: 'The errorToken must be present in stimulus/sentence.',
            ));
          }
        }
        break;

      case ExerciseType.shortAnswer:
        final hasTarget = (def.targetSentence != null && def.targetSentence!.trim().isNotEmpty) ||
            def.acceptableAnswers.isNotEmpty ||
            def.rubricKeywords.isNotEmpty;
        if (!hasTarget) {
          errors.add(const ExerciseValidationError(
            field: 'shortAnswer',
            message: 'ShortAnswer requires targetSentence, acceptableAnswers, or rubricKeywords.',
          ));
        }
        break;
    }

    return errors;
  }

  /// Helper returning true if no validation errors exist
  bool isValid(ExerciseDefinition def) => validate(def).isEmpty;
}
