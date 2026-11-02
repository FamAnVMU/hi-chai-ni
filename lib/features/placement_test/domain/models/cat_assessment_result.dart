import 'package:flutter/foundation.dart';
import 'cat_skill.dart';

/// Performance estimation and confidence metrics for an individual skill.
@immutable
class SkillScoreEstimate {
  final CatSkill skill;

  /// Whether this skill was actually attempted and assessed.
  /// If false, this skill was skipped and MUST NOT be scored as zero (0).
  final bool isAssessed;

  /// Estimated latent ability parameter $\theta$ on [-3.0, +3.0] scale (null if unassessed).
  final double? estimatedTheta;

  /// Standard error of the ability estimate (lower indicates higher certainty).
  final double? standardError;

  /// Percentage of correct answers (0.0 to 1.0, null if unassessed).
  final double? accuracyRate;

  final int itemsAttempted;
  final int itemsCorrect;

  /// Confidence level descriptor ('Cao', 'Trung bình', 'Thấp', 'Chưa đánh giá').
  final String confidenceLabel;

  /// Distinct sub-scores (e.g., for Writing: recognition, pinyin, stroke; for Speaking: audio status).
  final Map<String, dynamic> subMetrics;

  const SkillScoreEstimate({
    required this.skill,
    required this.isAssessed,
    this.estimatedTheta,
    this.standardError,
    this.accuracyRate,
    this.itemsAttempted = 0,
    this.itemsCorrect = 0,
    required this.confidenceLabel,
    this.subMetrics = const {},
  });

  /// Factory for skipped or unavailable skill.
  factory SkillScoreEstimate.unassessed(CatSkill skill, {String? reason}) =>
      SkillScoreEstimate(
        skill: skill,
        isAssessed: false,
        confidenceLabel: 'Chưa đánh giá',
        subMetrics: {'reason': reason ?? 'Kỹ năng chưa được thực hiện'},
      );

  Map<String, dynamic> toMap() => {
        'skill': skill.name,
        'is_assessed': isAssessed,
        'estimated_theta': estimatedTheta,
        'standard_error': standardError,
        'accuracy_rate': accuracyRate,
        'items_attempted': itemsAttempted,
        'items_correct': itemsCorrect,
        'confidence_label': confidenceLabel,
        'sub_metrics': subMetrics,
      };

  factory SkillScoreEstimate.fromMap(Map<String, dynamic> map) {
    return SkillScoreEstimate(
      skill: CatSkill.values.firstWhere(
        (e) => e.name == map['skill'],
        orElse: () => CatSkill.vocabulary,
      ),
      isAssessed: map['is_assessed'] as bool? ?? false,
      estimatedTheta: (map['estimated_theta'] as num?)?.toDouble(),
      standardError: (map['standard_error'] as num?)?.toDouble(),
      accuracyRate: (map['accuracy_rate'] as num?)?.toDouble(),
      itemsAttempted: (map['items_attempted'] as num?)?.toInt() ?? 0,
      itemsCorrect: (map['items_correct'] as num?)?.toInt() ?? 0,
      confidenceLabel: map['confidence_label'] as String? ?? 'Chưa đánh giá',
      subMetrics: Map<String, dynamic>.from(map['sub_metrics'] as Map? ?? {}),
    );
  }
}

/// An identified weakness or knowledge gap diagnosed during the assessment.
@immutable
class KnowledgeGapItem {
  final String tag;
  final String labelVi;
  final CatSkill skill;
  final String suggestedRemediationVi;

  const KnowledgeGapItem({
    required this.tag,
    required this.labelVi,
    required this.skill,
    required this.suggestedRemediationVi,
  });

  Map<String, dynamic> toMap() => {
        'tag': tag,
        'label_vi': labelVi,
        'skill': skill.name,
        'suggested_remediation_vi': suggestedRemediationVi,
      };

  factory KnowledgeGapItem.fromMap(Map<String, dynamic> map) =>
      KnowledgeGapItem(
        tag: map['tag'] as String,
        labelVi: map['label_vi'] as String,
        skill: CatSkill.values.firstWhere(
          (e) => e.name == map['skill'],
          orElse: () => CatSkill.vocabulary,
        ),
        suggestedRemediationVi: map['suggested_remediation_vi'] as String,
      );
}

/// Comprehensive, pedagogical diagnostic report generated at test completion.
@immutable
class CatAssessmentResult {
  final String sessionId;
  final double overallTheta;
  final double overallStandardError;
  final String referenceHskBand;
  final double confidenceScore; // 0.0 to 1.0
  final Map<CatSkill, SkillScoreEstimate> skillScores;
  final List<KnowledgeGapItem> knowledgeGaps;
  final int recommendedHskLevel;
  final String recommendedRoadmapTitle;
  final String recommendedRoadmapCode;
  final DateTime completedAt;
  final String blueprintVersion;

  /// Mandatory legal & pedagogical disclaimer
  static const String disclaimerVi =
      'Kết quả HSK chỉ là mức ước lượng tham chiếu nội bộ phục vụ định hướng học tập trên ứng dụng HI Chinese, không có giá trị thay thế chứng chỉ HSK chính thức của Bộ Giáo dục Trung Quốc / CTI.';

  const CatAssessmentResult({
    required this.sessionId,
    required this.overallTheta,
    required this.overallStandardError,
    required this.referenceHskBand,
    required this.confidenceScore,
    required this.skillScores,
    required this.knowledgeGaps,
    required this.recommendedHskLevel,
    required this.recommendedRoadmapTitle,
    required this.recommendedRoadmapCode,
    required this.completedAt,
    this.blueprintVersion = 'v1.0',
  });

  /// Derives reference HSK band string from theta.
  static String mapThetaToHskBand(double theta) {
    if (theta < -1.5) {
      return 'HSK 0 (Khởi đầu từ số 0)';
    } else if (theta < -0.5) {
      return 'HSK 1 (Sơ cấp cơ bản)';
    } else if (theta < 0.5) {
      return 'HSK 2 (Sơ cấp nâng cao)';
    } else if (theta < 1.5) {
      return 'HSK 3 (Trung cấp 1)';
    } else if (theta < 2.2) {
      return 'HSK 4 (Trung cấp 2)';
    } else {
      return 'HSK 5+ (Cao cấp)';
    }
  }

  /// Derives recommended starting HSK level integer (1 to 5).
  static int mapThetaToRecommendedLevel(double theta) {
    if (theta < -0.5) return 1;
    if (theta < 0.5) return 2;
    if (theta < 1.5) return 3;
    if (theta < 2.2) return 4;
    return 5;
  }

  /// Evaluates whether learner demonstrated sufficient Pinyin proficiency to bypass Pinyin Foundation.
  bool get shouldBypassPinyinFoundation {
    final speaking = skillScores[CatSkill.speaking];
    final writing = skillScores[CatSkill.writing];
    if (overallTheta >= -0.5) return true;
    if (speaking != null && speaking.isAssessed && (speaking.accuracyRate ?? 0) >= 0.8) return true;
    if (writing != null && writing.isAssessed && (writing.accuracyRate ?? 0) >= 0.8) return true;
    return false;
  }
}
