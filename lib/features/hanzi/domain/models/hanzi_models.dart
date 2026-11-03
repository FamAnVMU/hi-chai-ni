import 'dart:convert';
import 'dart:math' as math;

/// 2D Point representation for stroke medians and touch canvas positions
class Point2D {
  final double x;
  final double y;

  const Point2D(this.x, this.y);

  factory Point2D.fromJson(dynamic json) {
    if (json is List && json.length >= 2) {
      return Point2D((json[0] as num).toDouble(), (json[1] as num).toDouble());
    } else if (json is Map) {
      return Point2D((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
    }
    return const Point2D(0, 0);
  }

  List<double> toJson() => [x, y];

  double distanceTo(Point2D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  Point2D subtract(Point2D other) => Point2D(x - other.x, y - other.y);

  double get length => math.sqrt(x * x + y * y);

  @override
  String toString() => '($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point2D && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Linked HSK vocabulary word referencing this character
class HanziSampleWord {
  final String id;
  final String word;
  final String pinyin;
  final String meaningVi;

  const HanziSampleWord({
    required this.id,
    required this.word,
    required this.pinyin,
    required this.meaningVi,
  });

  factory HanziSampleWord.fromJson(Map<String, dynamic> json) {
    return HanziSampleWord(
      id: json['id'] as String? ?? '',
      word: json['word'] as String? ?? '',
      pinyin: json['pinyin'] as String? ?? '',
      meaningVi: json['meaning_vi'] as String? ?? json['meaning'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'pinyin': pinyin,
    'meaning_vi': meaningVi,
  };
}

/// Core domain entity for a Chinese character with verified vector stroke geometry
class HanziCharacter {
  final String id;
  final String character;
  final int strokeCount;
  final int hskLevel;
  final List<int> allHskLevels;
  final String pinyin;
  final String hanviet;
  final String meaningVi;
  final String definitionEn;
  final String radical;
  final String decomposition;
  final List<String> strokes;
  final List<List<Point2D>> medians;
  final List<HanziSampleWord> sampleWords;
  final bool isSupported;
  final String source;
  final String license;

  const HanziCharacter({
    required this.id,
    required this.character,
    required this.strokeCount,
    this.hskLevel = 1,
    this.allHskLevels = const [],
    this.pinyin = '',
    this.hanviet = '',
    this.meaningVi = '',
    this.definitionEn = '',
    this.radical = '',
    this.decomposition = '',
    required this.strokes,
    required this.medians,
    this.sampleWords = const [],
    this.isSupported = true,
    this.source = 'Make Me a Hanzi',
    this.license = 'Arphic Public License / OFL',
  });

  factory HanziCharacter.fromJson(Map<String, dynamic> json) {
    // Parse strokes
    final rawStrokes = json['strokes'];
    List<String> parsedStrokes = [];
    if (rawStrokes is List) {
      parsedStrokes = rawStrokes.map((s) => s.toString()).toList();
    } else if (rawStrokes is String) {
      try {
        final decoded = jsonDecode(rawStrokes) as List;
        parsedStrokes = decoded.map((s) => s.toString()).toList();
      } catch (_) {}
    }

    // Parse medians
    final rawMedians = json['medians'];
    List<List<Point2D>> parsedMedians = [];
    if (rawMedians is List) {
      parsedMedians = rawMedians.map((strokeMed) {
        if (strokeMed is List) {
          return strokeMed.map((p) => Point2D.fromJson(p)).toList();
        }
        return <Point2D>[];
      }).toList();
    } else if (rawMedians is String) {
      try {
        final decoded = jsonDecode(rawMedians) as List;
        parsedMedians = decoded.map((strokeMed) {
          if (strokeMed is List) {
            return strokeMed.map((p) => Point2D.fromJson(p)).toList();
          }
          return <Point2D>[];
        }).toList();
      } catch (_) {}
    }

    // Parse sample words
    final rawWords = json['sample_words'];
    List<HanziSampleWord> parsedWords = [];
    if (rawWords is List) {
      parsedWords = rawWords
          .map((w) => HanziSampleWord.fromJson(w as Map<String, dynamic>))
          .toList();
    } else if (rawWords is String) {
      try {
        final decoded = jsonDecode(rawWords) as List;
        parsedWords = decoded
            .map((w) => HanziSampleWord.fromJson(w as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Parse all_hsk_levels
    List<int> parsedLevels = [];
    final rawLevels = json['all_hsk_levels'];
    if (rawLevels is List) {
      parsedLevels = rawLevels.map((l) => (l as num).toInt()).toList();
    } else if (rawLevels is String) {
      try {
        final decoded = jsonDecode(rawLevels) as List;
        parsedLevels = decoded.map((l) => (l as num).toInt()).toList();
      } catch (_) {}
    }

    return HanziCharacter(
      id: json['id'] as String? ?? 'hanzi_${json['character']}',
      character: json['character'] as String? ?? '',
      strokeCount: (json['stroke_count'] as num?)?.toInt() ?? parsedStrokes.length,
      hskLevel: (json['hsk_level'] as num?)?.toInt() ?? 1,
      allHskLevels: parsedLevels,
      pinyin: json['pinyin'] as String? ?? '',
      hanviet: json['hanviet'] as String? ?? '',
      meaningVi: json['meaning_vi'] as String? ?? '',
      definitionEn: json['definition_en'] as String? ?? '',
      radical: json['radical'] as String? ?? '',
      decomposition: json['decomposition'] as String? ?? '',
      strokes: parsedStrokes,
      medians: parsedMedians,
      sampleWords: parsedWords,
      isSupported: (json['is_supported'] == 1 || json['is_supported'] == true),
      source: json['source'] as String? ?? 'Make Me a Hanzi',
      license: json['license'] as String? ?? 'Arphic Public License / OFL',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'character': character,
    'stroke_count': strokeCount,
    'hsk_level': hskLevel,
    'all_hsk_levels': jsonEncode(allHskLevels),
    'pinyin': pinyin,
    'hanviet': hanviet,
    'meaning_vi': meaningVi,
    'definition_en': definitionEn,
    'radical': radical,
    'decomposition': decomposition,
    'strokes_json': jsonEncode(strokes),
    'medians_json': jsonEncode(medians.map((m) => m.map((p) => p.toJson()).toList()).toList()),
    'sample_words_json': jsonEncode(sampleWords.map((w) => w.toJson()).toList()),
    'is_supported': isSupported ? 1 : 0,
    'source': source,
    'license': license,
  };

  factory HanziCharacter.fromMap(Map<String, dynamic> map) {
    return HanziCharacter.fromJson({
      'id': map['id'],
      'character': map['character'],
      'stroke_count': map['stroke_count'],
      'hsk_level': map['hsk_level'],
      'all_hsk_levels': map['all_hsk_levels'],
      'pinyin': map['pinyin'],
      'hanviet': map['hanviet'],
      'meaning_vi': map['meaning_vi'],
      'definition_en': map['definition_en'],
      'radical': map['radical'],
      'decomposition': map['decomposition'],
      'strokes': map['strokes_json'],
      'medians': map['medians_json'],
      'sample_words': map['sample_words_json'],
      'is_supported': map['is_supported'],
      'source': map['source'],
      'license': map['license'],
    });
  }
}

/// Tracks learner writing practice and SRS repetition progress per character
class HanziWritingProgress {
  final String id;
  final String character;
  final int hskLevel;
  final int practiceCount;
  final int testCount;
  final double lastAccuracyScore;
  final double bestAccuracyScore;
  final int mistakesCount;
  final int strokeOrderErrors;
  final DateTime? lastPracticedAt;
  final String masteryLevel; // 'new', 'learning', 'practiced', 'mastered'
  final bool isFavorite;
  final DateTime? srsDueDate;

  const HanziWritingProgress({
    required this.id,
    required this.character,
    this.hskLevel = 1,
    this.practiceCount = 0,
    this.testCount = 0,
    this.lastAccuracyScore = 0.0,
    this.bestAccuracyScore = 0.0,
    this.mistakesCount = 0,
    this.strokeOrderErrors = 0,
    this.lastPracticedAt,
    this.masteryLevel = 'new',
    this.isFavorite = false,
    this.srsDueDate,
  });

  factory HanziWritingProgress.fromMap(Map<String, dynamic> map) {
    return HanziWritingProgress(
      id: map['id'] as String? ?? 'progress_${map['character']}',
      character: map['character'] as String? ?? '',
      hskLevel: (map['hsk_level'] as num?)?.toInt() ?? 1,
      practiceCount: (map['practice_count'] as num?)?.toInt() ?? 0,
      testCount: (map['test_count'] as num?)?.toInt() ?? 0,
      lastAccuracyScore: (map['last_accuracy_score'] as num?)?.toDouble() ?? 0.0,
      bestAccuracyScore: (map['best_accuracy_score'] as num?)?.toDouble() ?? 0.0,
      mistakesCount: (map['mistakes_count'] as num?)?.toInt() ?? 0,
      strokeOrderErrors: (map['stroke_order_errors'] as num?)?.toInt() ?? 0,
      lastPracticedAt: map['last_practiced_at'] != null
          ? DateTime.tryParse(map['last_practiced_at'].toString())
          : null,
      masteryLevel: map['mastery_level'] as String? ?? 'new',
      isFavorite: (map['is_favorite'] == 1 || map['is_favorite'] == true),
      srsDueDate: map['srs_due_date'] != null
          ? DateTime.tryParse(map['srs_due_date'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'character': character,
    'hsk_level': hskLevel,
    'practice_count': practiceCount,
    'test_count': testCount,
    'last_accuracy_score': lastAccuracyScore,
    'best_accuracy_score': bestAccuracyScore,
    'mistakes_count': mistakesCount,
    'stroke_order_errors': strokeOrderErrors,
    'last_practiced_at': lastPracticedAt?.toIso8601String(),
    'mastery_level': masteryLevel,
    'is_favorite': isFavorite ? 1 : 0,
    'srs_due_date': srsDueDate?.toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };

  HanziWritingProgress copyWith({
    int? practiceCount,
    int? testCount,
    double? lastAccuracyScore,
    double? bestAccuracyScore,
    int? mistakesCount,
    int? strokeOrderErrors,
    DateTime? lastPracticedAt,
    String? masteryLevel,
    bool? isFavorite,
    DateTime? srsDueDate,
  }) {
    return HanziWritingProgress(
      id: id,
      character: character,
      hskLevel: hskLevel,
      practiceCount: practiceCount ?? this.practiceCount,
      testCount: testCount ?? this.testCount,
      lastAccuracyScore: lastAccuracyScore ?? this.lastAccuracyScore,
      bestAccuracyScore: bestAccuracyScore ?? this.bestAccuracyScore,
      mistakesCount: mistakesCount ?? this.mistakesCount,
      strokeOrderErrors: strokeOrderErrors ?? this.strokeOrderErrors,
      lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      isFavorite: isFavorite ?? this.isFavorite,
      srsDueDate: srsDueDate ?? this.srsDueDate,
    );
  }
}

/// Handwriting interaction modes
enum WritingMode {
  /// Demonstration & animation stroke-by-stroke
  learn,
  /// Guided touch practice with outlines and stroke hints
  practice,
  /// Freehand test without outlines or hints, strict scoring
  test,
}

/// Canvas background grid style
enum WritingGridType {
  /// 米字格 (8-segment star grid)
  miZiGe,
  /// 田字格 (4-quadrant cross grid)
  tianZiGe,
  /// Clean border without inner guidelines
  none,
}

/// Result of evaluating a user-drawn stroke against reference stroke geometry
class StrokeValidationResult {
  final bool isMatch;
  final bool isBackwards;
  final bool isWrongOrder;
  final int expectedStrokeIndex;
  final int matchedStrokeIndex;
  final double accuracyScore;
  final String message;

  const StrokeValidationResult({
    required this.isMatch,
    this.isBackwards = false,
    this.isWrongOrder = false,
    required this.expectedStrokeIndex,
    required this.matchedStrokeIndex,
    this.accuracyScore = 0.0,
    required this.message,
  });

  factory StrokeValidationResult.correct({
    required int strokeIndex,
    required double accuracy,
  }) {
    return StrokeValidationResult(
      isMatch: true,
      expectedStrokeIndex: strokeIndex,
      matchedStrokeIndex: strokeIndex,
      accuracyScore: accuracy,
      message: 'Chính xác! Nét thứ ${strokeIndex + 1} chuẩn.',
    );
  }

  factory StrokeValidationResult.backwards({
    required int strokeIndex,
  }) {
    return StrokeValidationResult(
      isMatch: false,
      isBackwards: true,
      expectedStrokeIndex: strokeIndex,
      matchedStrokeIndex: strokeIndex,
      accuracyScore: 0.0,
      message: 'Nét bị ngược chiều! Hãy vẽ từ điểm xuất phát theo đúng hướng mũi tên.',
    );
  }

  factory StrokeValidationResult.wrongOrder({
    required int expectedIndex,
    required int matchedIndex,
  }) {
    return StrokeValidationResult(
      isMatch: false,
      isWrongOrder: true,
      expectedStrokeIndex: expectedIndex,
      matchedStrokeIndex: matchedIndex,
      accuracyScore: 0.0,
      message: 'Sai thứ tự nét! Bạn vừa viết nét thứ ${matchedIndex + 1}. Hãy viết nét thứ ${expectedIndex + 1} trước.',
    );
  }

  factory StrokeValidationResult.mismatch({
    required int strokeIndex,
  }) {
    return StrokeValidationResult(
      isMatch: false,
      expectedStrokeIndex: strokeIndex,
      matchedStrokeIndex: -1,
      accuracyScore: 0.0,
      message: 'Nét chưa chuẩn. Hãy quan sát hướng dẫn và thử lại nhé!',
    );
  }
}
