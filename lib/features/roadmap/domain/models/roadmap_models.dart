/// Purpose of learning Chinese
enum LearnerPurpose {
  dailyCommunication,
  hskExam,
  businessWork,
  travelCulture,
}

extension LearnerPurposeExtension on LearnerPurpose {
  String get displayName {
    switch (this) {
      case LearnerPurpose.dailyCommunication:
        return 'Giao tiếp hàng ngày';
      case LearnerPurpose.hskExam:
        return 'Thi chứng chỉ HSK';
      case LearnerPurpose.businessWork:
        return 'Công việc & Thương mại';
      case LearnerPurpose.travelCulture:
        return 'Du lịch & Văn hóa';
    }
  }
}

/// Learning timeframe / pace
enum LearnerTimeframe {
  express,
  standard,
  relaxed,
}

extension LearnerTimeframeExtension on LearnerTimeframe {
  String get displayName {
    switch (this) {
      case LearnerTimeframe.express:
        return 'Cấp tốc (1 - 2 tháng)';
      case LearnerTimeframe.standard:
        return 'Tiêu chuẩn (3 - 6 tháng)';
      case LearnerTimeframe.relaxed:
        return 'Thong thả (6 - 12 tháng)';
    }
  }
}

/// Core six skill dimensions in Chinese language acquisition
enum SkillDimension {
  vocabulary,
  grammar,
  reading,
  listening,
  speaking,
  writing,
}

extension SkillDimensionExtension on SkillDimension {
  String get displayName {
    switch (this) {
      case SkillDimension.vocabulary:
        return 'Từ vựng';
      case SkillDimension.grammar:
        return 'Ngữ pháp';
      case SkillDimension.reading:
        return 'Đọc hiểu';
      case SkillDimension.listening:
        return 'Nghe hiểu';
      case SkillDimension.speaking:
        return 'Nói & Phát âm';
      case SkillDimension.writing:
        return 'Viết chữ Hán';
    }
  }
}

enum LearningPathType {
  focused,
  comprehensive,
}

extension LearningPathTypeExtension on LearningPathType {
  String get displayName {
    switch (this) {
      case LearningPathType.focused:
        return 'Trọng tâm 1 kỹ năng';
      case LearningPathType.comprehensive:
        return 'Toàn diện – Học đều 6 kỹ năng';
    }
  }

  String get description {
    switch (this) {
      case LearningPathType.focused:
        return 'Tập trung 40% thời gian vào kỹ năng ưu tiên, 60% còn lại phân bổ đều.';
      case LearningPathType.comprehensive:
        return 'Phân bổ đều 6 kỹ năng: Từ vựng, Ngữ pháp, Đọc, Nghe, Nói, Viết – không ưu tiên riêng lẻ.';
    }
  }

  String get dbValue => name;

  static LearningPathType fromDb(String? value) {
    if (value == 'balanced' || value == 'comprehensive') {
      return LearningPathType.comprehensive;
    }
    return LearningPathType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LearningPathType.focused,
    );
  }
}

/// Progression status of a curriculum lesson
enum LessonStatus {
  locked,
  available,
  inProgress,
  completed,
  skipped,
}

/// High-level learning goal set by the learner
class LearnerGoal {
  final String id;
  final int targetHskLevel;
  final LearnerPurpose purpose;
  final LearnerTimeframe timeframe;
  final int dailyMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LearnerGoal({
    required this.id,
    required this.targetHskLevel,
    this.purpose = LearnerPurpose.dailyCommunication,
    this.timeframe = LearnerTimeframe.standard,
    this.dailyMinutes = 30,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LearnerGoal.defaultGoal() {
    final now = DateTime.now().toUtc();
    return LearnerGoal(
      id: 'default_goal',
      targetHskLevel: 1,
      purpose: LearnerPurpose.dailyCommunication,
      timeframe: LearnerTimeframe.standard,
      dailyMinutes: 30,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory LearnerGoal.fromMap(Map<String, dynamic> map) {
    return LearnerGoal(
      id: map['id'] as String,
      targetHskLevel: map['target_hsk_level'] as int? ?? 1,
      purpose: LearnerPurpose.values.firstWhere(
        (e) => e.name == map['purpose'],
        orElse: () => LearnerPurpose.dailyCommunication,
      ),
      timeframe: LearnerTimeframe.values.firstWhere(
        (e) => e.name == map['timeframe'],
        orElse: () => LearnerTimeframe.standard,
      ),
      dailyMinutes: map['daily_minutes'] as int? ?? 30,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'target_hsk_level': targetHskLevel,
        'purpose': purpose.name,
        'timeframe': timeframe.name,
        'daily_minutes': dailyMinutes,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  LearnerGoal copyWith({
    String? id,
    int? targetHskLevel,
    LearnerPurpose? purpose,
    LearnerTimeframe? timeframe,
    int? dailyMinutes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LearnerGoal(
      id: id ?? this.id,
      targetHskLevel: targetHskLevel ?? this.targetHskLevel,
      purpose: purpose ?? this.purpose,
      timeframe: timeframe ?? this.timeframe,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// An immutable curriculum lesson catalog item
class CurriculumLesson {
  final String id;
  final String unitId;
  final int level;
  final String title;
  final String description;
  final SkillDimension primarySkill;
  final int estimatedMinutes;
  final List<String> prerequisiteLessonIds;
  final List<String> prerequisiteSkills;
  final Map<String, dynamic> contentReferences;

  const CurriculumLesson({
    required this.id,
    required this.unitId,
    required this.level,
    required this.title,
    required this.description,
    required this.primarySkill,
    this.estimatedMinutes = 15,
    this.prerequisiteLessonIds = const [],
    this.prerequisiteSkills = const [],
    this.contentReferences = const {},
  });
}

/// An immutable curriculum unit containing structured lessons
class CurriculumUnit {
  final String id;
  final int level;
  final int unitNumber;
  final String title;
  final String description;
  final List<CurriculumLesson> lessons;

  const CurriculumUnit({
    required this.id,
    required this.level,
    required this.unitNumber,
    required this.title,
    required this.description,
    this.lessons = const [],
  });
}

/// An immutable curriculum level
class CurriculumLevel {
  final int level;
  final String title;
  final String description;
  final List<CurriculumUnit> units;

  const CurriculumLevel({
    required this.level,
    required this.title,
    required this.description,
    this.units = const [],
  });

  List<CurriculumLesson> get allLessons =>
      units.expand((u) => u.lessons).toList();
}

/// Learner's personal progress on an individual lesson
class LessonProgress {
  final String id;
  final String lessonId;
  final String unitId;
  final int hskLevel;
  final LessonStatus status;
  final double? completionScore;
  final int evidenceCount;
  final String? source;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? lastStudiedAt;
  final DateTime updatedAt;

  const LessonProgress({
    required this.id,
    required this.lessonId,
    required this.unitId,
    required this.hskLevel,
    this.status = LessonStatus.locked,
    this.completionScore,
    this.evidenceCount = 0,
    this.source,
    this.startedAt,
    this.completedAt,
    this.lastStudiedAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == LessonStatus.completed;
  bool get isAvailable => status == LessonStatus.available;
  bool get isLocked => status == LessonStatus.locked;
  double? get score => completionScore;

  factory LessonProgress.fromMap(Map<String, dynamic> map) {
    return LessonProgress(
      id: map['id'] as String,
      lessonId: map['lesson_id'] as String,
      unitId: map['unit_id'] as String,
      hskLevel: map['hsk_level'] as int? ?? 1,
      status: LessonStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => LessonStatus.locked,
      ),
      completionScore: (map['completion_score'] as num?)?.toDouble(),
      evidenceCount: map['evidence_count'] as int? ?? 0,
      source: map['source'] as String?,
      startedAt: map['started_at'] != null ? DateTime.tryParse(map['started_at'] as String) : null,
      completedAt: map['completed_at'] != null ? DateTime.tryParse(map['completed_at'] as String) : null,
      lastStudiedAt: map['last_studied_at'] != null ? DateTime.tryParse(map['last_studied_at'] as String) : null,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'lesson_id': lessonId,
        'unit_id': unitId,
        'hsk_level': hskLevel,
        'status': status.name,
        if (completionScore != null) 'completion_score': completionScore,
        'evidence_count': evidenceCount,
        if (source != null) 'source': source,
        if (startedAt != null) 'started_at': startedAt!.toUtc().toIso8601String(),
        if (completedAt != null) 'completed_at': completedAt!.toUtc().toIso8601String(),
        if (lastStudiedAt != null) 'last_studied_at': lastStudiedAt!.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  LessonProgress copyWith({
    String? id,
    String? lessonId,
    String? unitId,
    int? hskLevel,
    LessonStatus? status,
    double? completionScore,
    int? evidenceCount,
    String? source,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? lastStudiedAt,
    DateTime? updatedAt,
  }) {
    return LessonProgress(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      unitId: unitId ?? this.unitId,
      hskLevel: hskLevel ?? this.hskLevel,
      status: status ?? this.status,
      completionScore: completionScore ?? this.completionScore,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      source: source ?? this.source,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Skill mastery rating aggregated across learning evidence
class SkillMastery {
  final SkillDimension skill;
  final double masteryRate; // 0.0 to 1.0
  final int evidenceCount;
  final DateTime? lastAssessedAt;

  const SkillMastery({
    required this.skill,
    required this.masteryRate,
    this.evidenceCount = 0,
    this.lastAssessedAt,
  });

  Map<String, dynamic> toMap() => {
        'skill': skill.name,
        'mastery_rate': masteryRate,
        'evidence_count': evidenceCount,
        if (lastAssessedAt != null) 'last_assessed_at': lastAssessedAt!.toUtc().toIso8601String(),
      };

  factory SkillMastery.fromMap(Map<String, dynamic> map) {
    return SkillMastery(
      skill: SkillDimension.values.firstWhere(
        (s) => s.name == map['skill'],
        orElse: () => SkillDimension.vocabulary,
      ),
      masteryRate: (map['mastery_rate'] as num?)?.toDouble() ?? 0.0,
      evidenceCount: map['evidence_count'] as int? ?? 0,
      lastAssessedAt: map['last_assessed_at'] != null ? DateTime.tryParse(map['last_assessed_at'] as String) : null,
    );
  }
}

/// Recommendation priority level
enum RecommendationPriority {
  urgent, // Fix identified gaps or review overdue lapses
  recommended, // Next standard sequential step
  enrichment, // Deepening mastery / optional practice
}

/// An individual recommendation with transparent pedagogical rationale
class RoadmapRecommendation {
  final CurriculumLesson lesson;
  final RecommendationPriority priority;
  final String reason;
  final List<String> supportingEvidence;
  final bool isOverridden;

  const RoadmapRecommendation({
    required this.lesson,
    required this.priority,
    required this.reason,
    this.supportingEvidence = const [],
    this.isOverridden = false,
  });

  Map<String, dynamic> toMap() => {
        'lesson_id': lesson.id,
        'priority': priority.name,
        'reason': reason,
        'supporting_evidence': supportingEvidence,
        'is_overridden': isOverridden,
      };
}

/// Aggregated roadmap state for a learner
class LearnerRoadmapState {
  final LearnerGoal activeGoal;
  final int currentLevel;
  final Map<String, LessonProgress> lessonProgressMap;
  final Map<SkillDimension, SkillMastery> skillMasteryMap;
  final List<RoadmapRecommendation> recommendations;

  const LearnerRoadmapState({
    required this.activeGoal,
    required this.currentLevel,
    this.lessonProgressMap = const {},
    this.skillMasteryMap = const {},
    this.recommendations = const [],
  });

  double get overallLevelCompletion {
    if (lessonProgressMap.isEmpty) return 0.0;
    final levelLessons = lessonProgressMap.values.where((p) => p.hskLevel == currentLevel);
    if (levelLessons.isEmpty) return 0.0;
    final completed = levelLessons.where((p) => p.isCompleted).length;
    return completed / levelLessons.length;
  }
}
