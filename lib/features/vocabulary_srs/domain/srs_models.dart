/// Four rating choices presented in the UI flashcard study session.
/// Mapped to SM-2 quality grades:
/// - [again]: quality = 1 (complete failure or major mistake, card lapses)
/// - [hard]: quality = 3 (recalled correctly but with high difficulty/hesitation)
/// - [good]: quality = 4 (correct recall after a normal hesitation)
/// - [easy]: quality = 5 (effortless, immediate recall)
enum SrsRating {
  again(quality: 1, label: 'Again', labelVi: 'Quên'),
  hard(quality: 3, label: 'Hard', labelVi: 'Khó'),
  good(quality: 4, label: 'Good', labelVi: 'Nhớ'),
  easy(quality: 5, label: 'Easy', labelVi: 'Dễ');

  final int quality;
  final String label;
  final String labelVi;

  const SrsRating({
    required this.quality,
    required this.label,
    required this.labelVi,
  });

  static SrsRating fromQuality(int quality) {
    if (quality <= 2) return SrsRating.again;
    if (quality == 3) return SrsRating.hard;
    if (quality == 4) return SrsRating.good;
    return SrsRating.easy;
  }
}

/// Lifecycle state of an item in the Spaced Repetition System.
enum SrsItemState {
  newCard('new'),
  learning('learning'),
  review('review'),
  relearning('relearning'),
  mastered('mastered');

  final String value;
  const SrsItemState(this.value);

  static SrsItemState fromString(String value) {
    switch (value.toLowerCase()) {
      case 'learning':
        return SrsItemState.learning;
      case 'review':
        return SrsItemState.review;
      case 'relearning':
        return SrsItemState.relearning;
      case 'mastered':
        return SrsItemState.mastered;
      case 'new':
      default:
        return SrsItemState.newCard;
    }
  }
}

/// Immutable state snapshot of an SRS card.
class SrsCardState {
  final String id;
  final String contentId;
  final String contentType;
  final SrsItemState state;
  final int intervalDays;
  final double easeFactor;
  final int repetitions;
  final int lapses;
  final DateTime dueAt;
  final DateTime? lastReviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SrsCardState({
    required this.id,
    required this.contentId,
    this.contentType = 'vocabulary',
    this.state = SrsItemState.newCard,
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    this.lapses = 0,
    required this.dueAt,
    this.lastReviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory creating an initial brand-new card ready for study.
  factory SrsCardState.newCard({
    required String id,
    required String contentId,
    String contentType = 'vocabulary',
    DateTime? now,
    double initialEaseFactor = 2.5,
  }) {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    return SrsCardState(
      id: id,
      contentId: contentId,
      contentType: contentType,
      state: SrsItemState.newCard,
      intervalDays: 0,
      easeFactor: initialEaseFactor,
      repetitions: 0,
      lapses: 0,
      dueAt: nowUtc,
      lastReviewedAt: null,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );
  }

  /// Deserialization from SQLite database row.
  factory SrsCardState.fromMap(Map<String, dynamic> map) {
    return SrsCardState(
      id: map['id'] as String,
      contentId: map['content_id'] as String,
      contentType: map['content_type'] as String? ?? 'vocabulary',
      state: SrsItemState.fromString(map['state'] as String? ?? 'new'),
      intervalDays: (map['interval_days'] as num?)?.toInt() ?? 0,
      easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
      repetitions: (map['repetitions'] as num?)?.toInt() ?? 0,
      lapses: (map['lapses'] as num?)?.toInt() ?? 0,
      dueAt: DateTime.parse(map['due_at'] as String).toUtc(),
      lastReviewedAt: map['last_reviewed_at'] != null
          ? DateTime.parse(map['last_reviewed_at'] as String).toUtc()
          : null,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
    );
  }

  /// Serialization to SQLite database row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content_id': contentId,
      'content_type': contentType,
      'state': state.value,
      'interval_days': intervalDays,
      'ease_factor': easeFactor,
      'repetitions': repetitions,
      'lapses': lapses,
      'due_at': dueAt.toIso8601String(),
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SrsCardState.fromJson(Map<String, dynamic> json) =>
      SrsCardState.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  SrsCardState copyWith({
    String? id,
    String? contentId,
    String? contentType,
    SrsItemState? state,
    int? intervalDays,
    double? easeFactor,
    int? repetitions,
    int? lapses,
    DateTime? dueAt,
    DateTime? lastReviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SrsCardState(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      contentType: contentType ?? this.contentType,
      state: state ?? this.state,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
      repetitions: repetitions ?? this.repetitions,
      lapses: lapses ?? this.lapses,
      dueAt: dueAt ?? this.dueAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'SrsCardState($contentId, state=$state, interval=${intervalDays}d, EF=${easeFactor.toStringAsFixed(2)}, reps=$repetitions, lapses=$lapses, dueAt=$dueAt)';
}

/// The result returned by the pure SM-2 calculation engine.
class SrsReviewResult {
  final SrsCardState nextState;
  final SrsRating rating;
  final int quality;
  final int previousIntervalDays;
  final int newIntervalDays;
  final double previousEaseFactor;
  final double newEaseFactor;
  final DateTime reviewTime;
  final DateTime scheduledDueAt;

  const SrsReviewResult({
    required this.nextState,
    required this.rating,
    required this.quality,
    required this.previousIntervalDays,
    required this.newIntervalDays,
    required this.previousEaseFactor,
    required this.newEaseFactor,
    required this.reviewTime,
    required this.scheduledDueAt,
  });

  bool get isSuccessful => quality >= 3;
  DateTime get reviewedAt => reviewTime;

  @override
  String toString() =>
      'SrsReviewResult(rating=${rating.label}, interval: ${previousIntervalDays}d -> ${newIntervalDays}d, EF: ${previousEaseFactor.toStringAsFixed(2)} -> ${newEaseFactor.toStringAsFixed(2)}, dueAt: $scheduledDueAt)';
}

/// Rich flashcard item joining vocabulary, senses, and live SRS state.
class SrsFlashcardItem {
  final String id;
  final String simplified;
  final String? traditional;
  final String pinyin;
  final int hskLevel;
  final int? strokeCount;
  final String? radicals;
  final String? audioUri;
  final String? partOfSpeech;
  final String meaningVi;
  final String? exampleCn;
  final String? examplePinyin;
  final String? exampleVi;
  final SrsCardState srsState;
  final Map<SrsRating, int> estimatedIntervalDays;

  const SrsFlashcardItem({
    required this.id,
    required this.simplified,
    this.traditional,
    required this.pinyin,
    required this.hskLevel,
    this.strokeCount,
    this.radicals,
    this.audioUri,
    this.partOfSpeech,
    required this.meaningVi,
    this.exampleCn,
    this.examplePinyin,
    this.exampleVi,
    required this.srsState,
    required this.estimatedIntervalDays,
  });

  factory SrsFlashcardItem.fromDatabaseRow({
    required Map<String, dynamic> row,
    required SrsCardState srsState,
    required Map<SrsRating, int> estimatedIntervalDays,
  }) {
    return SrsFlashcardItem(
      id: row['id'] as String,
      simplified: row['simplified'] as String,
      traditional: row['traditional'] as String?,
      pinyin: row['pinyin'] as String,
      hskLevel: (row['hsk_level'] as num).toInt(),
      strokeCount: (row['stroke_count'] as num?)?.toInt(),
      radicals: row['radicals'] as String?,
      audioUri: row['audio_uri'] as String?,
      partOfSpeech: row['part_of_speech'] as String?,
      meaningVi: row['meaning_vi'] as String? ?? 'Chưa có định nghĩa',
      exampleCn: row['example_cn'] as String?,
      examplePinyin: row['example_pinyin'] as String?,
      exampleVi: row['example_vi'] as String?,
      srsState: srsState,
      estimatedIntervalDays: estimatedIntervalDays,
    );
  }

  SrsFlashcardItem copyWith({
    String? id,
    String? simplified,
    String? traditional,
    String? pinyin,
    int? hskLevel,
    int? strokeCount,
    String? radicals,
    String? audioUri,
    String? partOfSpeech,
    String? meaningVi,
    String? exampleCn,
    String? examplePinyin,
    String? exampleVi,
    SrsCardState? srsState,
    Map<SrsRating, int>? estimatedIntervalDays,
  }) {
    return SrsFlashcardItem(
      id: id ?? this.id,
      simplified: simplified ?? this.simplified,
      traditional: traditional ?? this.traditional,
      pinyin: pinyin ?? this.pinyin,
      hskLevel: hskLevel ?? this.hskLevel,
      strokeCount: strokeCount ?? this.strokeCount,
      radicals: radicals ?? this.radicals,
      audioUri: audioUri ?? this.audioUri,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      meaningVi: meaningVi ?? this.meaningVi,
      exampleCn: exampleCn ?? this.exampleCn,
      examplePinyin: examplePinyin ?? this.examplePinyin,
      exampleVi: exampleVi ?? this.exampleVi,
      srsState: srsState ?? this.srsState,
      estimatedIntervalDays: estimatedIntervalDays ?? this.estimatedIntervalDays,
    );
  }
}

/// Snapshot of an ongoing interactive study session.
class SrsStudySession {
  final List<SrsFlashcardItem> queue;
  final int currentIndex;
  final bool isAnswerRevealed;
  final bool isPinyinVisibleOnFront;
  final bool isProcessingReview;
  final bool hasSavedOffline;
  final int completedReviewsCount;
  final int correctReviewsCount;
  final String? errorMessage;

  const SrsStudySession({
    this.queue = const [],
    this.currentIndex = 0,
    this.isAnswerRevealed = false,
    this.isPinyinVisibleOnFront = true,
    this.isProcessingReview = false,
    this.hasSavedOffline = true,
    this.completedReviewsCount = 0,
    this.correctReviewsCount = 0,
    this.errorMessage,
  });

  bool get isEmpty => queue.isEmpty;
  bool get isCompleted => queue.isNotEmpty && currentIndex >= queue.length;
  SrsFlashcardItem? get currentCard =>
      (currentIndex >= 0 && currentIndex < queue.length) ? queue[currentIndex] : null;

  int get remainingCards => (queue.length - currentIndex).clamp(0, queue.length);

  double get progressRatio => queue.isEmpty ? 1.0 : (currentIndex / queue.length).clamp(0.0, 1.0);

  double get accuracyRate =>
      completedReviewsCount == 0 ? 1.0 : (correctReviewsCount / completedReviewsCount);

  SrsStudySession copyWith({
    List<SrsFlashcardItem>? queue,
    int? currentIndex,
    bool? isAnswerRevealed,
    bool? isPinyinVisibleOnFront,
    bool? isProcessingReview,
    bool? hasSavedOffline,
    int? completedReviewsCount,
    int? correctReviewsCount,
    String? errorMessage,
  }) {
    return SrsStudySession(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isAnswerRevealed: isAnswerRevealed ?? this.isAnswerRevealed,
      isPinyinVisibleOnFront: isPinyinVisibleOnFront ?? this.isPinyinVisibleOnFront,
      isProcessingReview: isProcessingReview ?? this.isProcessingReview,
      hasSavedOffline: hasSavedOffline ?? this.hasSavedOffline,
      completedReviewsCount: completedReviewsCount ?? this.completedReviewsCount,
      correctReviewsCount: correctReviewsCount ?? this.correctReviewsCount,
      errorMessage: errorMessage,
    );
  }
}
