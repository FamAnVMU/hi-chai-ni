import 'dart:convert';
import 'dart:math';

/// 7 core exercise types supported across all HI Chinese learning modules
enum ExerciseType {
  multipleChoice,
  selectMeaningOrPinyin,
  matchingPairs,
  fillInTheBlank,
  reorderWords,
  trueFalseOrErrorDetection,
  shortAnswer;

  String get displayName {
    switch (this) {
      case ExerciseType.multipleChoice:
        return 'Trắc nghiệm';
      case ExerciseType.selectMeaningOrPinyin:
        return 'Chọn nghĩa / Pinyin';
      case ExerciseType.matchingPairs:
        return 'Ghép cặp tương ứng';
      case ExerciseType.fillInTheBlank:
        return 'Điền chỗ trống';
      case ExerciseType.reorderWords:
        return 'Sắp xếp trật tự câu';
      case ExerciseType.trueFalseOrErrorDetection:
        return 'Đúng/Sai hoặc Phát hiện lỗi';
      case ExerciseType.shortAnswer:
        return 'Câu trả lời ngắn';
    }
  }
}

/// Evaluator mechanism: deterministic domain rules, pedagogical rubric, or generative AI
enum EvaluatorType {
  deterministic,
  rubric,
  ai,
}

/// Practice session lifecycle status
enum PracticeSessionStatus {
  inProgress,
  completed,
  abandoned;

  String get displayName {
    switch (this) {
      case PracticeSessionStatus.inProgress:
        return 'Đang làm';
      case PracticeSessionStatus.completed:
        return 'Đã hoàn thành';
      case PracticeSessionStatus.abandoned:
        return 'Đã hủy';
    }
  }
}

/// Validation error raised when an exercise definition fails schema/pedagogical constraints
class ExerciseValidationError {
  final String field;
  final String message;

  const ExerciseValidationError({required this.field, required this.message});

  @override
  String toString() => '$field: $message';
}

/// Core domain definition of an interactive practice exercise
class ExerciseDefinition {
  final String id;
  final ExerciseType type;
  final String skill; // vocabulary, grammar, reading, listening, writing
  final int hskLevel;
  final String prompt;
  final String? stimulus; // Target Hanzi, text snippet, or sentence
  final String? stimulusPinyin;
  final String? stimulusAudioUri;

  // Specific payloads
  final List<String> options; // For MC, SelectMeaningOrPinyin, TrueFalse
  final int? correctOptionIndex;
  final Map<String, String> matchingPairs; // For MatchingPairs (Left: Right)
  final String? sentenceWithBlank; // e.g. "他 ___ 老师。"
  final String? blankAnswer; // e.g. "是"
  final List<String> blankOptions; // Optional bank of words for blank
  final List<String> tokens; // For ReorderWords
  final String? targetSentence; // For ReorderWords, ShortAnswer
  final List<String> acceptableAnswers; // Multi-phrasing tolerance
  final bool? isTrue; // For True/False judgment
  final String? errorToken; // For ErrorDetection (the wrong part)
  final String? errorCorrection; // Suggested correction
  final List<String> rubricKeywords; // For ShortAnswer rubric scoring

  final String explanationVi;
  final Map<String, dynamic> metadata;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExerciseDefinition({
    required this.id,
    required this.type,
    required this.skill,
    this.hskLevel = 1,
    required this.prompt,
    this.stimulus,
    this.stimulusPinyin,
    this.stimulusAudioUri,
    this.options = const [],
    this.correctOptionIndex,
    this.matchingPairs = const {},
    this.sentenceWithBlank,
    this.blankAnswer,
    this.blankOptions = const [],
    this.tokens = const [],
    this.targetSentence,
    this.acceptableAnswers = const [],
    this.isTrue,
    this.errorToken,
    this.errorCorrection,
    this.rubricKeywords = const [],
    required this.explanationVi,
    this.metadata = const {},
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Deterministic shuffling with seed support for test reproducibility
  List<String> getShuffledOptions({int? seed}) {
    final list = List<String>.from(options);
    if (seed != null) {
      list.shuffle(Random(seed));
    } else {
      list.shuffle();
    }
    return list;
  }

  /// Returns shuffled Left and Right pair keys/values with seed
  Map<String, List<String>> getShuffledMatchingColumns({int? seed}) {
    final leftList = matchingPairs.keys.toList();
    final rightList = matchingPairs.values.toList();
    final rng = seed != null ? Random(seed) : Random();
    leftList.shuffle(rng);
    rightList.shuffle(rng);
    return {'left': leftList, 'right': rightList};
  }

  /// Shuffled tokens for reorder exercises with optional seed
  List<String> getShuffledTokens({int? seed}) {
    final list = List<String>.from(tokens);
    if (seed != null) {
      list.shuffle(Random(seed));
    } else {
      list.shuffle();
    }
    return list;
  }

  factory ExerciseDefinition.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic raw) {
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

    Map<String, dynamic> payload = {};
    if (map['payload_json'] is String) {
      try {
        payload = json.decode(map['payload_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    } else if (map['payload_json'] is Map) {
      payload = Map<String, dynamic>.from(map['payload_json'] as Map);
    }

    Map<String, dynamic> rubric = {};
    if (map['rubric_json'] is String) {
      try {
        rubric = json.decode(map['rubric_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    } else if (map['rubric_json'] is Map) {
      rubric = Map<String, dynamic>.from(map['rubric_json'] as Map);
    }

    Map<String, dynamic> meta = {};
    if (map['metadata_json'] is String) {
      try {
        meta = json.decode(map['metadata_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    } else if (map['metadata_json'] is Map) {
      meta = Map<String, dynamic>.from(map['metadata_json'] as Map);
    }

    Map<String, String> pairs = {};
    final rawPairs = payload['matching_pairs'];
    if (rawPairs is Map) {
      pairs = rawPairs.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    return ExerciseDefinition(
      id: map['id'] as String? ?? '',
      type: ExerciseType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ExerciseType.multipleChoice,
      ),
      skill: map['skill'] as String? ?? 'vocabulary',
      hskLevel: map['hsk_level'] as int? ?? 1,
      prompt: map['prompt'] as String? ?? '',
      stimulus: map['stimulus'] as String?,
      stimulusPinyin: map['stimulus_pinyin'] as String?,
      stimulusAudioUri: map['stimulus_audio_uri'] as String?,
      options: parseList(payload['options']),
      correctOptionIndex: payload['correct_option_index'] as int?,
      matchingPairs: pairs,
      sentenceWithBlank: payload['sentence_with_blank'] as String?,
      blankAnswer: payload['blank_answer'] as String?,
      blankOptions: parseList(payload['blank_options']),
      tokens: parseList(payload['tokens']),
      targetSentence: payload['target_sentence'] as String?,
      acceptableAnswers: parseList(payload['acceptable_answers']),
      isTrue: payload['is_true'] as bool?,
      errorToken: payload['error_token'] as String?,
      errorCorrection: payload['error_correction'] as String?,
      rubricKeywords: parseList(rubric['rubric_keywords']),
      explanationVi: map['explanation_vi'] as String? ?? '',
      metadata: meta,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    final payload = <String, dynamic>{
      'options': options,
      'correct_option_index': correctOptionIndex,
      'matching_pairs': matchingPairs,
      'sentence_with_blank': sentenceWithBlank,
      'blank_answer': blankAnswer,
      'blank_options': blankOptions,
      'tokens': tokens,
      'target_sentence': targetSentence,
      'acceptable_answers': acceptableAnswers,
      'is_true': isTrue,
      'error_token': errorToken,
      'error_correction': errorCorrection,
    };

    final rubric = <String, dynamic>{
      'rubric_keywords': rubricKeywords,
    };

    return {
      'id': id,
      'type': type.name,
      'skill': skill,
      'hsk_level': hskLevel,
      'prompt': prompt,
      'stimulus': stimulus,
      'stimulus_pinyin': stimulusPinyin,
      'stimulus_audio_uri': stimulusAudioUri,
      'payload_json': json.encode(payload),
      'rubric_json': json.encode(rubric),
      'explanation_vi': explanationVi,
      'metadata_json': json.encode(metadata),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

/// Student's response answer payload
class ExerciseAnswer {
  final String exerciseId;
  final int? selectedOptionIndex; // MC, SelectMeaningOrPinyin
  final Map<String, String>? matchedPairs; // MatchingPairs
  final String? filledBlank; // FillInTheBlank
  final List<String>? orderedTokens; // ReorderWords
  final bool? userBool; // TrueFalse
  final String? selectedErrorToken; // ErrorDetection
  final String? textResponse; // ShortAnswer

  const ExerciseAnswer({
    required this.exerciseId,
    this.selectedOptionIndex,
    this.matchedPairs,
    this.filledBlank,
    this.orderedTokens,
    this.userBool,
    this.selectedErrorToken,
    this.textResponse,
  });

  factory ExerciseAnswer.fromMap(Map<String, dynamic> map) {
    Map<String, String>? pairs;
    if (map['matched_pairs'] is Map) {
      pairs = (map['matched_pairs'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    List<String>? tokens;
    if (map['ordered_tokens'] is List) {
      tokens = (map['ordered_tokens'] as List).map((e) => e.toString()).toList();
    }

    return ExerciseAnswer(
      exerciseId: map['exercise_id'] as String? ?? '',
      selectedOptionIndex: map['selected_option_index'] as int?,
      matchedPairs: pairs,
      filledBlank: map['filled_blank'] as String?,
      orderedTokens: tokens,
      userBool: map['user_bool'] as bool?,
      selectedErrorToken: map['selected_error_token'] as String?,
      textResponse: map['text_response'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'exercise_id': exerciseId,
        if (selectedOptionIndex != null) 'selected_option_index': selectedOptionIndex,
        if (matchedPairs != null) 'matched_pairs': matchedPairs,
        if (filledBlank != null) 'filled_blank': filledBlank,
        if (orderedTokens != null) 'ordered_tokens': orderedTokens,
        if (userBool != null) 'user_bool': userBool,
        if (selectedErrorToken != null) 'selected_error_token': selectedErrorToken,
        if (textResponse != null) 'text_response': textResponse,
      };
}

/// Evaluation result of an exercise attempt
class ScoringResult {
  final bool isCorrect;
  final double score; // 0.0 to 1.0
  final double confidence; // 0.0 to 1.0
  final bool needsHumanReview;
  final EvaluatorType evaluatorType;
  final String feedbackVi;
  final Map<String, dynamic>? aiMetadata; // model, provider, reasoning
  final Map<String, dynamic>? breakdown;

  const ScoringResult({
    required this.isCorrect,
    required this.score,
    required this.confidence,
    this.needsHumanReview = false,
    this.evaluatorType = EvaluatorType.deterministic,
    required this.feedbackVi,
    this.aiMetadata,
    this.breakdown,
  });

  factory ScoringResult.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? aiMeta;
    if (map['ai_metadata_json'] is String && (map['ai_metadata_json'] as String).isNotEmpty) {
      try {
        aiMeta = json.decode(map['ai_metadata_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }
    Map<String, dynamic>? bdown;
    if (map['breakdown_json'] is String && (map['breakdown_json'] as String).isNotEmpty) {
      try {
        bdown = json.decode(map['breakdown_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    return ScoringResult(
      isCorrect: (map['is_correct'] as int? ?? 0) == 1,
      score: (map['score'] as num? ?? 0.0).toDouble(),
      confidence: (map['confidence'] as num? ?? 1.0).toDouble(),
      needsHumanReview: (map['needs_human_review'] as int? ?? 0) == 1,
      evaluatorType: EvaluatorType.values.firstWhere(
        (e) => e.name == map['evaluator_type'],
        orElse: () => EvaluatorType.deterministic,
      ),
      feedbackVi: map['feedback_vi'] as String? ?? '',
      aiMetadata: aiMeta,
      breakdown: bdown,
    );
  }

  Map<String, dynamic> toMap() => {
        'is_correct': isCorrect ? 1 : 0,
        'score': score,
        'confidence': confidence,
        'needs_human_review': needsHumanReview ? 1 : 0,
        'evaluator_type': evaluatorType.name,
        'feedback_vi': feedbackVi,
        'ai_metadata_json': aiMetadata != null ? json.encode(aiMetadata) : null,
        'breakdown_json': breakdown != null ? json.encode(breakdown) : null,
      };
}

/// Recorded attempt for a single exercise
class ExerciseAttempt {
  final String id;
  final String sessionId;
  final String exerciseId;
  final ExerciseAnswer answer;
  final ScoringResult result;
  final int durationMs;
  final DateTime createdAt;

  const ExerciseAttempt({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.answer,
    required this.result,
    required this.durationMs,
    required this.createdAt,
  });

  bool get isCorrect => result.isCorrect;
  double get score => result.score;

  factory ExerciseAttempt.fromMap(Map<String, dynamic> map) {
    ExerciseAnswer parsedAnswer = ExerciseAnswer(exerciseId: map['exercise_id'] as String? ?? '');
    if (map['answer_json'] is String) {
      try {
        parsedAnswer = ExerciseAnswer.fromMap(json.decode(map['answer_json'] as String));
      } catch (_) {}
    }

    final parsedResult = ScoringResult.fromMap(map);

    return ExerciseAttempt(
      id: map['id'] as String? ?? '',
      sessionId: map['session_id'] as String? ?? '',
      exerciseId: map['exercise_id'] as String? ?? '',
      answer: parsedAnswer,
      result: parsedResult,
      durationMs: map['duration_ms'] as int? ?? 0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    final resMap = result.toMap();
    return {
      'id': id,
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'answer_json': json.encode(answer.toMap()),
      'score': resMap['score'],
      'is_correct': resMap['is_correct'],
      'confidence': resMap['confidence'],
      'needs_human_review': resMap['needs_human_review'],
      'evaluator_type': resMap['evaluator_type'],
      'feedback_vi': resMap['feedback_vi'],
      'ai_metadata_json': resMap['ai_metadata_json'],
      'breakdown_json': resMap['breakdown_json'],
      'duration_ms': durationMs,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

/// A multi-exercise practice session with pause/resume support
class PracticeSession {
  final String id;
  final String title;
  final String skill;
  final int hskLevel;
  final List<String> exerciseIds;
  final int currentIndex;
  final List<ExerciseAttempt> attempts;
  final PracticeSessionStatus status;
  final double? score;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const PracticeSession({
    required this.id,
    required this.title,
    required this.skill,
    this.hskLevel = 1,
    required this.exerciseIds,
    this.currentIndex = 0,
    this.attempts = const [],
    this.status = PracticeSessionStatus.inProgress,
    this.score,
    required this.startedAt,
    required this.updatedAt,
    this.completedAt,
  });

  bool get isCompleted => status == PracticeSessionStatus.completed;

  PracticeSession copyWith({
    int? currentIndex,
    List<ExerciseAttempt>? attempts,
    PracticeSessionStatus? status,
    double? score,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return PracticeSession(
      id: id,
      title: title,
      skill: skill,
      hskLevel: hskLevel,
      exerciseIds: exerciseIds,
      currentIndex: currentIndex ?? this.currentIndex,
      attempts: attempts ?? this.attempts,
      status: status ?? this.status,
      score: score ?? this.score,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory PracticeSession.fromMap(Map<String, dynamic> map, {List<ExerciseAttempt> attempts = const []}) {
    List<String> ids = [];
    if (map['exercise_ids_json'] is String) {
      try {
        final decoded = json.decode(map['exercise_ids_json'] as String);
        if (decoded is List) ids = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    return PracticeSession(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Phiên luyện tập',
      skill: map['skill'] as String? ?? 'general',
      hskLevel: map['hsk_level'] as int? ?? 1,
      exerciseIds: ids,
      currentIndex: map['current_index'] as int? ?? 0,
      attempts: attempts,
      status: PracticeSessionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PracticeSessionStatus.inProgress,
      ),
      score: (map['score'] as num?)?.toDouble(),
      startedAt: DateTime.tryParse(map['started_at'] as String? ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now().toUtc(),
      completedAt: map['completed_at'] != null ? DateTime.tryParse(map['completed_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'skill': skill,
        'hsk_level': hskLevel,
        'exercise_ids_json': json.encode(exerciseIds),
        'current_index': currentIndex,
        'status': status.name,
        'score': score,
        'started_at': startedAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
      };
}
