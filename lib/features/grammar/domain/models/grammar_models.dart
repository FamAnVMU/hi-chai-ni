import 'dart:convert';

/// Learning and mastery status of a grammar point
enum GrammarProgressStatus {
  unlearned,
  learning,
  mastered,
}

extension GrammarProgressStatusExtension on GrammarProgressStatus {
  String get displayName {
    switch (this) {
      case GrammarProgressStatus.unlearned:
        return 'Chưa học';
      case GrammarProgressStatus.learning:
        return 'Đang học';
      case GrammarProgressStatus.mastered:
        return 'Đã thành thạo';
    }
  }
}

/// Type of grammar exercise
enum GrammarExerciseType {
  multipleChoice,
  reorderWords,
  openTranslation,
}

/// A standard authentic Chinese sentence example illustrating the grammar point
class GrammarExample {
  final String hanzi;
  final String pinyin;
  final String translationVi;
  final String? audioUri;
  final String? breakdown;

  const GrammarExample({
    required this.hanzi,
    required this.pinyin,
    required this.translationVi,
    this.audioUri,
    this.breakdown,
  });

  factory GrammarExample.fromMap(Map<String, dynamic> map) {
    return GrammarExample(
      hanzi: map['hanzi'] as String? ?? '',
      pinyin: map['pinyin'] as String? ?? '',
      translationVi: map['translation_vi'] as String? ?? '',
      audioUri: map['audio_uri'] as String?,
      breakdown: map['breakdown'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'hanzi': hanzi,
        'pinyin': pinyin,
        'translation_vi': translationVi,
        if (audioUri != null) 'audio_uri': audioUri,
        if (breakdown != null) 'breakdown': breakdown,
      };
}

/// Contrastive example contrasting correct usage with common learner mistakes
class ContrastiveExample {
  final String incorrectSentence;
  final String correctSentence;
  final String explanationVi;
  final String errorType;

  const ContrastiveExample({
    required this.incorrectSentence,
    required this.correctSentence,
    required this.explanationVi,
    this.errorType = 'word_order',
  });

  factory ContrastiveExample.fromMap(Map<String, dynamic> map) {
    return ContrastiveExample(
      incorrectSentence: map['incorrect_sentence'] as String? ?? '',
      correctSentence: map['correct_sentence'] as String? ?? '',
      explanationVi: map['explanation_vi'] as String? ?? '',
      errorType: map['error_type'] as String? ?? 'general',
    );
  }

  Map<String, dynamic> toMap() => {
        'incorrect_sentence': incorrectSentence,
        'correct_sentence': correctSentence,
        'explanation_vi': explanationVi,
        'error_type': errorType,
      };
}

/// Grammar exercise with deterministic rubric criteria
class GrammarExercise {
  final String id;
  final GrammarExerciseType type;
  final String prompt;
  final String? sentenceWithBlank;
  final List<String> options;
  final int? correctAnswerIndex;
  final List<String> shuffledTokens;
  final String targetSentence;
  final List<String> acceptableAnswers;
  final List<String> rubricKeywords;
  final String explanationVi;

  const GrammarExercise({
    required this.id,
    required this.type,
    required this.prompt,
    this.sentenceWithBlank,
    this.options = const [],
    this.correctAnswerIndex,
    this.shuffledTokens = const [],
    required this.targetSentence,
    this.acceptableAnswers = const [],
    this.rubricKeywords = const [],
    required this.explanationVi,
  });

  factory GrammarExercise.fromMap(Map<String, dynamic> map) {
    return GrammarExercise(
      id: map['id'] as String? ?? '',
      type: GrammarExerciseType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => GrammarExerciseType.multipleChoice,
      ),
      prompt: map['prompt'] as String? ?? '',
      sentenceWithBlank: map['sentence_with_blank'] as String?,
      options: List<String>.from(map['options'] as List? ?? []),
      correctAnswerIndex: map['correct_answer_index'] as int?,
      shuffledTokens: List<String>.from(map['shuffled_tokens'] as List? ?? []),
      targetSentence: map['target_sentence'] as String? ?? '',
      acceptableAnswers: List<String>.from(map['acceptable_answers'] as List? ?? []),
      rubricKeywords: List<String>.from(map['rubric_keywords'] as List? ?? []),
      explanationVi: map['explanation_vi'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'prompt': prompt,
        if (sentenceWithBlank != null) 'sentence_with_blank': sentenceWithBlank,
        'options': options,
        if (correctAnswerIndex != null) 'correct_answer_index': correctAnswerIndex,
        'shuffled_tokens': shuffledTokens,
        'target_sentence': targetSentence,
        'acceptable_answers': acceptableAnswers,
        'rubric_keywords': rubricKeywords,
        'explanation_vi': explanationVi,
      };
}

/// Result of evaluating an exercise attempt
class ExerciseEvaluationResult {
  final bool isCorrect;
  final double score; // 0.0 to 1.0
  final double confidence; // 0.0 to 1.0 (academic confidence)
  final bool needsHumanReview; // True if confidence is lower than threshold
  final String feedbackVi;
  final String? matchingRule;

  const ExerciseEvaluationResult({
    required this.isCorrect,
    required this.score,
    required this.confidence,
    this.needsHumanReview = false,
    required this.feedbackVi,
    this.matchingRule,
  });
}

/// Core domain entity for a Chinese Grammar Point
class GrammarItem {
  final String id;
  final int hskLevel;
  final String code;
  final String title;
  final String structure;
  final String meaningVi;
  final String usageConditionsVi;
  final String sentencePositionVi;
  final String explanationVi;
  final String source;
  final List<String> tags;
  final List<String> relatedVocabIds;
  final List<String> relatedGrammarIds;
  final List<String> prerequisiteGrammarIds;
  final List<GrammarExample> examples;
  final List<ContrastiveExample> contrastiveExamples;
  final List<GrammarExercise> exercises;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GrammarItem({
    required this.id,
    required this.hskLevel,
    required this.code,
    required this.title,
    required this.structure,
    required this.meaningVi,
    required this.usageConditionsVi,
    required this.sentencePositionVi,
    required this.explanationVi,
    this.source = 'HSK Standard Course',
    this.tags = const [],
    this.relatedVocabIds = const [],
    this.relatedGrammarIds = const [],
    this.prerequisiteGrammarIds = const [],
    this.examples = const [],
    this.contrastiveExamples = const [],
    this.exercises = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory GrammarItem.fromMap(Map<String, dynamic> map) {
    List<GrammarExample> parseExamples(dynamic raw) {
      if (raw == null) return [];
      if (raw is String) {
        try {
          final decoded = json.decode(raw);
          if (decoded is List) {
            return decoded.map((e) => GrammarExample.fromMap(e as Map<String, dynamic>)).toList();
          }
        } catch (_) {}
        return [];
      }
      if (raw is List) {
        return raw.map((e) => GrammarExample.fromMap(e as Map<String, dynamic>)).toList();
      }
      return [];
    }

    List<ContrastiveExample> parseContrastive(dynamic raw) {
      if (raw == null) return [];
      if (raw is String) {
        try {
          final decoded = json.decode(raw);
          if (decoded is List) {
            return decoded.map((e) => ContrastiveExample.fromMap(e as Map<String, dynamic>)).toList();
          }
        } catch (_) {}
        return [];
      }
      if (raw is List) {
        return raw.map((e) => ContrastiveExample.fromMap(e as Map<String, dynamic>)).toList();
      }
      return [];
    }

    List<GrammarExercise> parseExercises(dynamic raw) {
      if (raw == null) return [];
      if (raw is String) {
        try {
          final decoded = json.decode(raw);
          if (decoded is List) {
            return decoded.map((e) => GrammarExercise.fromMap(e as Map<String, dynamic>)).toList();
          }
        } catch (_) {}
        return [];
      }
      if (raw is List) {
        return raw.map((e) => GrammarExercise.fromMap(e as Map<String, dynamic>)).toList();
      }
      return [];
    }

    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is String) {
        try {
          final decoded = json.decode(raw);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
        return [];
      }
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    return GrammarItem(
      id: map['id'] as String? ?? '',
      hskLevel: map['hsk_level'] as int? ?? 1,
      code: map['code'] as String? ?? '',
      title: map['title'] as String? ?? map['title_vi'] as String? ?? '',
      structure: map['structure'] as String? ?? map['pattern'] as String? ?? '',
      meaningVi: map['meaning_vi'] as String? ?? '',
      usageConditionsVi: map['usage_conditions_vi'] as String? ?? '',
      sentencePositionVi: map['sentence_position_vi'] as String? ?? '',
      explanationVi: map['explanation_vi'] as String? ?? '',
      source: map['source'] as String? ?? 'HSK Standard Course',
      tags: parseStringList(map['tags_json']),
      relatedVocabIds: parseStringList(map['related_vocab_ids_json']),
      relatedGrammarIds: parseStringList(map['related_grammar_ids_json']),
      prerequisiteGrammarIds: parseStringList(map['prerequisite_grammar_ids_json']),
      examples: parseExamples(map['examples_json'] ?? map['examples']),
      contrastiveExamples: parseContrastive(map['contrastive_examples_json']),
      exercises: parseExercises(map['exercises_json']),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'hsk_level': hskLevel,
        'code': code,
        'title': title,
        'title_vi': title,
        'pattern': structure,
        'structure': structure,
        'meaning_vi': meaningVi,
        'usage_conditions_vi': usageConditionsVi,
        'sentence_position_vi': sentencePositionVi,
        'explanation_vi': explanationVi,
        'source': source,
        'tags_json': json.encode(tags),
        'related_vocab_ids_json': json.encode(relatedVocabIds),
        'related_grammar_ids_json': json.encode(relatedGrammarIds),
        'prerequisite_grammar_ids_json': json.encode(prerequisiteGrammarIds),
        'examples_json': json.encode(examples.map((e) => e.toMap()).toList()),
        'contrastive_examples_json': json.encode(contrastiveExamples.map((e) => e.toMap()).toList()),
        'exercises_json': json.encode(exercises.map((e) => e.toMap()).toList()),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

/// Learner's progress record on an individual grammar point
class GrammarProgress {
  final String id;
  final String grammarId;
  final int hskLevel;
  final GrammarProgressStatus status;
  final double? masteryScore;
  final int exercisesCompleted;
  final DateTime? lastStudiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GrammarProgress({
    required this.id,
    required this.grammarId,
    required this.hskLevel,
    this.status = GrammarProgressStatus.unlearned,
    this.masteryScore,
    this.exercisesCompleted = 0,
    this.lastStudiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isMastered => status == GrammarProgressStatus.mastered;

  factory GrammarProgress.fromMap(Map<String, dynamic> map) {
    return GrammarProgress(
      id: map['id'] as String,
      grammarId: map['grammar_id'] as String,
      hskLevel: map['hsk_level'] as int? ?? 1,
      status: GrammarProgressStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => GrammarProgressStatus.unlearned,
      ),
      masteryScore: (map['mastery_score'] as num?)?.toDouble(),
      exercisesCompleted: map['exercises_completed'] as int? ?? 0,
      lastStudiedAt: map['last_studied_at'] != null ? DateTime.tryParse(map['last_studied_at'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'grammar_id': grammarId,
        'hsk_level': hskLevel,
        'status': status.name,
        if (masteryScore != null) 'mastery_score': masteryScore,
        'exercises_completed': exercisesCompleted,
        if (lastStudiedAt != null) 'last_studied_at': lastStudiedAt!.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}
