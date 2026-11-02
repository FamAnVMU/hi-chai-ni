import 'package:flutter/foundation.dart';

enum PinyinItemType {
  initial,   // Thanh mẫu (b, p, m, f...)
  simpleFinal, // Vận mẫu đơn (a, o, e, i, u, ü)
  compoundFinal, // Vận mẫu kép (ai, ei, ao...)
  frontNasalFinal, // Vận mẫu mũi trước (an, en, in...)
  backNasalFinal, // Vận mẫu mũi sau (ang, eng, ing...)
  tone,      // Thanh điệu (1, 2, 3, 4, light)
  rule,      // Quy tắc chính tả / biến điệu
  syllable,  // Âm tiết ghép
}

enum PinyinExerciseType {
  listenSelectSyllable,     // 1. Nghe audio và chọn âm tiết đúng
  listenIdentifyTone,       // 2. Nghe và xác định thanh điệu
  selectInitial,            // 3. Chọn thanh mẫu đúng
  selectFinal,              // 4. Chọn vận mẫu đúng
  blendInitialFinal,        // 5. Ghép thanh mẫu và vận mẫu
  blendSyllableTone,        // 6. Ghép âm tiết và thanh điệu
  discriminateMinimalPairs, // 7. Phân biệt các âm gần giống (b/p, z/zh...)
  listenInputPinyin,        // 8. Nghe và điền Pinyin
  listenRepeatRecord,       // 9. Đọc theo audio mẫu & nghe lại
  comprehensiveReview,      // 10. Ôn tập tổng hợp
}

@immutable
class PinyinItem {
  final String id;
  final PinyinItemType type;
  final String symbol; // e.g. "b", "p", "a", "1st Tone"
  final String ipa;
  final String vietnameseContrast; // So sánh trực quan với tiếng Việt
  final String articulationGuide; // Hướng dẫn đặt môi, lưỡi, luồng hơi
  final bool isAspirated; // Có bật hơi không
  final String? pitchContour; // Biểu đồ cao độ (55, 35, 214, 51)
  final String audioUri;
  final List<String> exampleWords;
  final List<String> commonMistakes;

  const PinyinItem({
    required this.id,
    required this.type,
    required this.symbol,
    this.ipa = '',
    required this.vietnameseContrast,
    required this.articulationGuide,
    this.isAspirated = false,
    this.pitchContour,
    required this.audioUri,
    this.exampleWords = const [],
    this.commonMistakes = const [],
  });
}

@immutable
class PinyinExercise {
  final String id;
  final PinyinExerciseType type;
  final String prompt;
  final String audioUri;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final Map<String, dynamic> metadata;

  const PinyinExercise({
    required this.id,
    required this.type,
    required this.prompt,
    required this.audioUri,
    this.options = const [],
    required this.correctAnswer,
    required this.explanation,
    this.metadata = const {},
  });
}

@immutable
class PinyinLesson {
  final String id;
  final String unitId;
  final int orderIndex;
  final String titleVi;
  final String titleZh;
  final String summary;
  final List<PinyinItem> items;
  final List<PinyinExercise> exercises;
  final List<String> prerequisites;
  final bool isLocked;

  const PinyinLesson({
    required this.id,
    required this.unitId,
    required this.orderIndex,
    required this.titleVi,
    required this.titleZh,
    required this.summary,
    required this.items,
    required this.exercises,
    this.prerequisites = const [],
    this.isLocked = false,
  });
}

@immutable
class PinyinUnit {
  final String id;
  final int unitNumber;
  final String titleVi;
  final String titleZh;
  final String descriptionVi;
  final List<PinyinLesson> lessons;

  const PinyinUnit({
    required this.id,
    required this.unitNumber,
    required this.titleVi,
    required this.titleZh,
    required this.descriptionVi,
    required this.lessons,
  });
}

@immutable
class PinyinProgressRecord {
  final String itemId;
  final String itemType;
  final String masteryState; // not_started, learning, familiar, mastered
  final int attemptsCount;
  final int correctCount;
  final double score;
  final String? lastPracticedAt;

  const PinyinProgressRecord({
    required this.itemId,
    required this.itemType,
    required this.masteryState,
    this.attemptsCount = 0,
    this.correctCount = 0,
    this.score = 0.0,
    this.lastPracticedAt,
  });
}
