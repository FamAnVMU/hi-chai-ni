import 'dart:convert';
export '../constants/curriculum_constants.dart';

class Curriculum {
  final String id;
  final String packId;
  final String code;
  final String standardName;
  final int hskLevel;
  final int totalUnits;
  final int totalLessons;

  const Curriculum({
    required this.id,
    required this.packId,
    required this.code,
    required this.standardName,
    required this.hskLevel,
    this.totalUnits = 0,
    this.totalLessons = 0,
  });

  factory Curriculum.fromMap(Map<String, dynamic> map) {
    return Curriculum(
      id: map['id'] as String,
      packId: map['pack_id'] as String,
      code: map['code'] as String,
      standardName: map['standard_name'] as String,
      hskLevel: (map['hsk_level'] as num).toInt(),
      totalUnits: (map['total_units'] as num?)?.toInt() ?? 0,
      totalLessons: (map['total_lessons'] as num?)?.toInt() ?? 0,
    );
  }
}

class CurriculumUnit {
  final String id;
  final String curriculumId;
  final int orderIndex;
  final String titleVi;
  final String titleZh;
  final String? descriptionVi;
  final String? iconName;
  final bool isLocked;
  final List<CurriculumLesson> lessons;

  const CurriculumUnit({
    required this.id,
    required this.curriculumId,
    required this.orderIndex,
    required this.titleVi,
    required this.titleZh,
    this.descriptionVi,
    this.iconName,
    this.isLocked = true,
    this.lessons = const [],
  });

  factory CurriculumUnit.fromMap(Map<String, dynamic> map, {List<CurriculumLesson> lessons = const []}) {
    return CurriculumUnit(
      id: map['id'] as String,
      curriculumId: map['curriculum_id'] as String,
      orderIndex: (map['order_index'] as num).toInt(),
      titleVi: map['title_vi'] as String,
      titleZh: map['title_zh'] as String,
      descriptionVi: map['description_vi'] as String?,
      iconName: map['icon_name'] as String?,
      isLocked: map['is_locked'] == 1 || map['is_locked'] == true,
      lessons: lessons,
    );
  }
}

enum LessonStatus {
  notStarted('not_started'),
  inProgress('in_progress'),
  completed('completed'),
  needsReview('needs_review'),
  mastered('mastered');

  final String value;
  const LessonStatus(this.value);

  static LessonStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'in_progress':
        return LessonStatus.inProgress;
      case 'completed':
        return LessonStatus.completed;
      case 'needs_review':
        return LessonStatus.needsReview;
      case 'mastered':
        return LessonStatus.mastered;
      default:
        return LessonStatus.notStarted;
    }
  }
}

class CurriculumLesson {
  final String id;
  final String unitId;
  final int orderIndex;
  final String titleVi;
  final String titleZh;
  final String pinyin;
  final int estimatedMinutes;
  final bool isLocked;
  final double unlockScoreThreshold;
  final List<String> prerequisites;
  final LessonStatus status;
  final DateTime? completedAt;
  final String? creditedReason;
  final List<LessonSegment> segments;
  final double masteryScore;

  const CurriculumLesson({
    required this.id,
    required this.unitId,
    required this.orderIndex,
    required this.titleVi,
    required this.titleZh,
    required this.pinyin,
    this.estimatedMinutes = 15,
    this.isLocked = true,
    this.unlockScoreThreshold = 0.8,
    this.prerequisites = const [],
    this.status = LessonStatus.notStarted,
    this.completedAt,
    this.creditedReason,
    this.segments = const [],
    this.masteryScore = 0.0,
  });

  factory CurriculumLesson.fromMap(
    Map<String, dynamic> map, {
    List<LessonSegment> segments = const [],
    double? masteryScore,
  }) {
    List<String> prereqs = [];
    if (map['prerequisites_json'] is String && (map['prerequisites_json'] as String).isNotEmpty) {
      final raw = map['prerequisites_json'] as String;
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          prereqs = decoded.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
        }
      } catch (_) {
        final quotedMatches = RegExp(r'"([^"]*)"')
            .allMatches(raw)
            .map((m) => m.group(1)!.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (quotedMatches.isNotEmpty) {
          prereqs = quotedMatches;
        } else if (!raw.contains('[')) {
          prereqs = [raw.trim()];
        } else {
          prereqs = raw
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
    }

    DateTime? compAt;
    if (map['completed_at'] != null) {
      compAt = DateTime.tryParse(map['completed_at'] as String);
    }

    return CurriculumLesson(
      id: map['id'] as String,
      unitId: map['unit_id'] as String,
      orderIndex: (map['order_index'] as num).toInt(),
      titleVi: map['title_vi'] as String,
      titleZh: map['title_zh'] as String,
      pinyin: map['pinyin'] as String? ?? '',
      estimatedMinutes: (map['estimated_minutes'] as num?)?.toInt() ?? 15,
      isLocked: map['is_locked'] == 1 || map['is_locked'] == true,
      unlockScoreThreshold: (map['unlock_score_threshold'] as num?)?.toDouble() ?? 0.8,
      prerequisites: prereqs,
      status: LessonStatus.fromString(map['status'] as String? ?? 'not_started'),
      completedAt: compAt,
      creditedReason: map['credited_reason'] as String?,
      segments: segments,
      masteryScore: masteryScore ?? (map['score'] as num?)?.toDouble() ?? (map['mastery_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LessonSegment {
  final String id;
  final String lessonId;
  final int stepOrder;
  final String segmentType; // 'warmup', 'vocabulary', 'grammar', 'dialogue', 'practice', 'mastery_check'
  final String title;
  final String? contentRefId;
  final Map<String, dynamic>? contentPayload;

  const LessonSegment({
    required this.id,
    required this.lessonId,
    required this.stepOrder,
    required this.segmentType,
    required this.title,
    this.contentRefId,
    this.contentPayload,
  });

  static Map<String, dynamic>? safeParsePayload(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = json.decode(trimmed);
        return _deepNormalizeMap(decoded);
      } catch (_) {
        return null;
      }
    }
    return _deepNormalizeMap(raw);
  }

  static Map<String, dynamic>? _deepNormalizeMap(dynamic raw) {
    if (raw is! Map) return null;
    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      result[entry.key.toString()] = _deepNormalizeValue(entry.value);
    }
    return result;
  }

  static dynamic _deepNormalizeValue(dynamic value) {
    if (value is Map) {
      return _deepNormalizeMap(value);
    }
    if (value is List) {
      return value.map(_deepNormalizeValue).toList();
    }
    return value;
  }

  factory LessonSegment.fromMap(Map<String, dynamic> map, {Map<String, dynamic>? contentPayload}) {
    final raw = contentPayload ?? map['content_payload'] ?? map['content_json'];
    final payload = safeParsePayload(raw);

    return LessonSegment(
      id: map['id'] as String,
      lessonId: map['lesson_id'] as String,
      stepOrder: (map['step_order'] as num).toInt(),
      segmentType: map['segment_type'] as String,
      title: map['title'] as String,
      contentRefId: map['content_ref_id'] as String?,
      contentPayload: payload,
    );
  }

  List<GrammarPoint> get grammarPoints {
    final rawPoints = (contentPayload?['points'] as List<dynamic>?) ??
        (contentPayload?['grammar_points'] as List<dynamic>?) ??
        [];
    return rawPoints
        .whereType<Map<String, dynamic>>()
        .map((m) => GrammarPoint.fromMap(m))
        .toList();
  }
}

class GrammarPoint {
  final String title;
  final String structure;
  final String explanation;
  final List<Map<String, dynamic>> examples;
  final String? positiveExample;
  final String? contrastiveExample;

  const GrammarPoint({
    required this.title,
    required this.structure,
    required this.explanation,
    this.examples = const [],
    this.positiveExample,
    this.contrastiveExample,
  });

  factory GrammarPoint.fromMap(Map<String, dynamic> map) {
    final rawExamples = (map['examples'] as List<dynamic>?) ?? [];
    final examplesList = rawExamples
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final pos = (map['positive_example'] ?? map['positiveExample']) as String?;
    final con = (map['contrastive_example'] ?? map['contrastiveExample']) as String?;

    return GrammarPoint(
      title: (map['title'] ?? '') as String,
      structure: (map['structure'] ?? '') as String,
      explanation: (map['explanation'] ?? map['explanation_vi'] ?? '') as String,
      examples: examplesList,
      positiveExample: pos,
      contrastiveExample: con,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'structure': structure,
        'explanation': explanation,
        if (examples.isNotEmpty) 'examples': examples,
        if (positiveExample != null) 'positive_example': positiveExample,
        if (contrastiveExample != null) 'contrastive_example': contrastiveExample,
      };
}
