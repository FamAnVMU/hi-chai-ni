import 'dart:convert';
import '../../../roadmap/domain/models/roadmap_models.dart';

/// Pre-defined Chinese learning interests.
class LearnerInterest {
  final String id;
  final String labelVi;
  final String labelZh;
  final String iconName;

  const LearnerInterest({
    required this.id,
    required this.labelVi,
    required this.labelZh,
    required this.iconName,
  });

  static const List<LearnerInterest> defaultInterests = [
    LearnerInterest(id: 'communication', labelVi: 'Giao tiếp đời sống', labelZh: '日常交流', iconName: 'chat'),
    LearnerInterest(id: 'travel', labelVi: 'Du lịch & Khám phá', labelZh: '旅游出行', iconName: 'flight'),
    LearnerInterest(id: 'food', labelVi: 'Ẩm thực Trung Hoa', labelZh: '中华美食', iconName: 'restaurant'),
    LearnerInterest(id: 'music_movie', labelVi: 'Âm nhạc & Điện ảnh', labelZh: '影视音乐', iconName: 'movie'),
    LearnerInterest(id: 'business', labelVi: 'Kinh doanh & Thương mại', labelZh: '商务贸易', iconName: 'work'),
    LearnerInterest(id: 'culture', labelVi: 'Văn hóa & Cổ phong', labelZh: '传统文化', iconName: 'auto_stories'),
    LearnerInterest(id: 'hsk_prep', labelVi: 'Luyện thi chứng chỉ HSK', labelZh: 'HSK考级', iconName: 'school'),
  ];
}

/// Standalone local learner profile.
class UserProfile {
  final String id;
  final String displayName;
  final int currentHskLevel;
  final int targetHskLevel;
  final LearnerPurpose purpose;
  final LearnerTimeframe timeframe;
  final int dailyMinutes;
  final DateTime startDate;
  final List<String> interests;
  final String avatarStyle;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    this.displayName = 'Người học HI Chinese',
    this.currentHskLevel = 1,
    this.targetHskLevel = 3,
    this.purpose = LearnerPurpose.dailyCommunication,
    this.timeframe = LearnerTimeframe.standard,
    this.dailyMinutes = 30,
    required this.startDate,
    this.interests = const ['communication', 'food', 'travel'],
    this.avatarStyle = 'panda',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.defaultProfile({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return UserProfile(
      id: 'default_learner',
      displayName: 'Người học HI Chinese',
      currentHskLevel: 1,
      targetHskLevel: 3,
      purpose: LearnerPurpose.dailyCommunication,
      timeframe: LearnerTimeframe.standard,
      dailyMinutes: 30,
      startDate: timestamp,
      interests: const ['communication', 'travel', 'food'],
      avatarStyle: 'panda',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  UserProfile copyWith({
    String? id,
    String? displayName,
    int? currentHskLevel,
    int? targetHskLevel,
    LearnerPurpose? purpose,
    LearnerTimeframe? timeframe,
    int? dailyMinutes,
    DateTime? startDate,
    List<String>? interests,
    String? avatarStyle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      currentHskLevel: currentHskLevel ?? this.currentHskLevel,
      targetHskLevel: targetHskLevel ?? this.targetHskLevel,
      purpose: purpose ?? this.purpose,
      timeframe: timeframe ?? this.timeframe,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      startDate: startDate ?? this.startDate,
      interests: interests ?? this.interests,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'current_hsk_level': currentHskLevel,
      'target_hsk_level': targetHskLevel,
      'purpose': purpose.name,
      'timeframe': timeframe.name,
      'daily_minutes': dailyMinutes,
      'start_date': startDate.toUtc().toIso8601String(),
      'interests_json': jsonEncode(interests),
      'avatar_style': avatarStyle,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    List<String> parsedInterests = const ['communication', 'food', 'travel'];
    final rawInterests = map['interests_json'];
    if (rawInterests is String && rawInterests.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawInterests);
        if (decoded is List) {
          parsedInterests = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return UserProfile(
      id: map['id'] as String? ?? 'default_learner',
      displayName: map['display_name'] as String? ?? 'Người học HI Chinese',
      currentHskLevel: (map['current_hsk_level'] as num?)?.toInt() ?? 1,
      targetHskLevel: (map['target_hsk_level'] as num?)?.toInt() ?? 3,
      purpose: LearnerPurpose.values.firstWhere(
        (p) => p.name == map['purpose'],
        orElse: () => LearnerPurpose.dailyCommunication,
      ),
      timeframe: LearnerTimeframe.values.firstWhere(
        (t) => t.name == map['timeframe'],
        orElse: () => LearnerTimeframe.standard,
      ),
      dailyMinutes: (map['daily_minutes'] as num?)?.toInt() ?? 30,
      startDate: DateTime.tryParse(map['start_date'] as String? ?? '') ?? DateTime.now(),
      interests: parsedInterests,
      avatarStyle: map['avatar_style'] as String? ?? 'panda',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Meaningful audit trail of goal changes.
class GoalHistoryRecord {
  final String id;
  final int previousTargetHsk;
  final int newTargetHsk;
  final int previousDailyMinutes;
  final int newDailyMinutes;
  final LearnerPurpose previousPurpose;
  final LearnerPurpose newPurpose;
  final String reason;
  final DateTime changedAt;

  const GoalHistoryRecord({
    required this.id,
    required this.previousTargetHsk,
    required this.newTargetHsk,
    required this.previousDailyMinutes,
    required this.newDailyMinutes,
    required this.previousPurpose,
    required this.newPurpose,
    required this.reason,
    required this.changedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'previous_target_hsk': previousTargetHsk,
      'new_target_hsk': newTargetHsk,
      'previous_daily_minutes': previousDailyMinutes,
      'new_daily_minutes': newDailyMinutes,
      'previous_purpose': previousPurpose.name,
      'new_purpose': newPurpose.name,
      'reason': reason,
      'changed_at': changedAt.toUtc().toIso8601String(),
    };
  }

  factory GoalHistoryRecord.fromMap(Map<String, dynamic> map) {
    return GoalHistoryRecord(
      id: map['id'] as String? ?? '',
      previousTargetHsk: (map['previous_target_hsk'] as num?)?.toInt() ?? 1,
      newTargetHsk: (map['new_target_hsk'] as num?)?.toInt() ?? 3,
      previousDailyMinutes: (map['previous_daily_minutes'] as num?)?.toInt() ?? 30,
      newDailyMinutes: (map['new_daily_minutes'] as num?)?.toInt() ?? 30,
      previousPurpose: LearnerPurpose.values.firstWhere(
        (p) => p.name == map['previous_purpose'],
        orElse: () => LearnerPurpose.dailyCommunication,
      ),
      newPurpose: LearnerPurpose.values.firstWhere(
        (p) => p.name == map['new_purpose'],
        orElse: () => LearnerPurpose.dailyCommunication,
      ),
      reason: map['reason'] as String? ?? '',
      changedAt: DateTime.tryParse(map['changed_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
