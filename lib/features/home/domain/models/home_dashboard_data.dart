import 'package:flutter/foundation.dart';
import 'learning_streak.dart';

/// Types of meaningful learning activities displayed on the Home dashboard.
enum ActivityType {
  srsReview,
  aiTutor,
  lesson,
  hanziWriting,
  pronunciationShadowing,
  reading,
  dictionary;

  String get labelVi {
    switch (this) {
      case ActivityType.srsReview:
        return 'Ôn tập Flashcard (SM-2)';
      case ActivityType.aiTutor:
        return 'Đàm thoại AI Tutor';
      case ActivityType.lesson:
        return 'Bài học giáo trình HSK';
      case ActivityType.hanziWriting:
        return 'Luyện viết chữ Hán';
      case ActivityType.pronunciationShadowing:
        return 'Phát âm & Shadowing';
      case ActivityType.reading:
        return 'Đọc hiểu ngữ cảnh';
      case ActivityType.dictionary:
        return 'Tra cứu từ điển';
    }
  }

  static ActivityType fromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'srs_review':
      case 'srs_flashcard':
      case 'srs':
        return ActivityType.srsReview;
      case 'ai_tutor':
      case 'ai_chat':
      case 'tutor':
        return ActivityType.aiTutor;
      case 'lesson':
      case 'curriculum':
        return ActivityType.lesson;
      case 'hanzi_writing':
      case 'stroke':
        return ActivityType.hanziWriting;
      case 'shadowing':
      case 'pronunciation':
        return ActivityType.pronunciationShadowing;
      case 'reading':
      case 'passage':
        return ActivityType.reading;
      default:
        return ActivityType.lesson;
    }
  }
}

/// An immutable item representing a recent completed learning action.
@immutable
class RecentActivityItem {
  final String id;
  final String title;
  final String subtitle;
  final ActivityType type;
  final DateTime timestamp;
  final int durationSeconds;
  final int itemsCount;
  final double? score;

  const RecentActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.timestamp,
    this.durationSeconds = 0,
    this.itemsCount = 1,
    this.score,
  });

  /// Formats relative time (e.g. "Vừa xong", "15 phút trước", "Hôm nay, 14:30", "Hôm qua")
  String formattedRelativeTime([DateTime? nowTime]) {
    final now = nowTime ?? DateTime.now();
    final localTime = timestamp.toLocal();
    final difference = now.difference(localTime);

    if (difference.inSeconds < 60 && difference.inSeconds >= 0) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60 && difference.inMinutes >= 0) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24 &&
        localTime.day == now.day &&
        localTime.month == now.month &&
        localTime.year == now.year) {
      final hourStr = localTime.hour.toString().padLeft(2, '0');
      final minuteStr = localTime.minute.toString().padLeft(2, '0');
      return 'Hôm nay, $hourStr:$minuteStr';
    } else if (difference.inDays <= 1) {
      return 'Hôm qua';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${localTime.day}/${localTime.month}/${localTime.year}';
    }
  }
}

/// Snapshot of the learner's active roadmap and curriculum progress.
@immutable
class RoadmapProgress {
  final int currentHskLevel;
  final String levelTitle;
  final int totalVocabCount;
  final int learnedVocabCount;
  final int masteredVocabCount;
  final String nextLessonTitle;
  final String nextLessonSnippet;

  const RoadmapProgress({
    required this.currentHskLevel,
    required this.levelTitle,
    required this.totalVocabCount,
    required this.learnedVocabCount,
    required this.masteredVocabCount,
    required this.nextLessonTitle,
    required this.nextLessonSnippet,
  });

  /// Ratio of vocabulary learned over total level vocabulary (0.0 to 1.0)
  double get progressRatio {
    if (totalVocabCount <= 0) return 0.0;
    return (learnedVocabCount / totalVocabCount).clamp(0.0, 1.0);
  }

  /// Percentage formatted string (e.g. "25%")
  String get progressPercentageString => '${(progressRatio * 100).toInt()}%';

  /// Default baseline roadmap for a new learner
  factory RoadmapProgress.initial({int hskLevel = 1, int totalVocab = 150}) =>
      RoadmapProgress(
        currentHskLevel: hskLevel,
        levelTitle: 'HSK $hskLevel: Nhập Môn Giao Tiếp',
        totalVocabCount: totalVocab,
        learnedVocabCount: 0,
        masteredVocabCount: 0,
        nextLessonTitle: 'Bài 1: Chào hỏi và làm quen',
        nextLessonSnippet: '你[nǐ]好[hǎo]，我[wǒ]叫[jiào]李[lǐ]华[huá]。',
      );
}

/// Aggregated, deduplicated study time statistics across standard temporal scopes.
@immutable
class StudyTimeStats {
  /// Today's study duration in seconds (sanitized & deduplicated).
  final int todayDurationSeconds;

  /// This week's study duration in seconds (Monday to current local time).
  final int weekDurationSeconds;

  /// Total all-time study duration in seconds.
  final int totalDurationSeconds;

  /// Number of distinct learning items/reviews completed today.
  final int todayItemsCompleted;

  /// Number of distinct learning items/reviews completed this week.
  final int weekItemsCompleted;

  /// Number of distinct learning items/reviews completed all time.
  final int totalItemsCompleted;

  const StudyTimeStats({
    this.todayDurationSeconds = 0,
    this.weekDurationSeconds = 0,
    this.totalDurationSeconds = 0,
    this.todayItemsCompleted = 0,
    this.weekItemsCompleted = 0,
    this.totalItemsCompleted = 0,
  });

  /// Rounded study duration in minutes
  int get todayDurationMinutes => (todayDurationSeconds / 60).round();
  int get weekDurationMinutes => (weekDurationSeconds / 60).round();
  int get totalDurationMinutes => (totalDurationSeconds / 60).round();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyTimeStats &&
          runtimeType == other.runtimeType &&
          todayDurationSeconds == other.todayDurationSeconds &&
          weekDurationSeconds == other.weekDurationSeconds &&
          totalDurationSeconds == other.totalDurationSeconds &&
          todayItemsCompleted == other.todayItemsCompleted &&
          weekItemsCompleted == other.weekItemsCompleted &&
          totalItemsCompleted == other.totalItemsCompleted;

  @override
  int get hashCode => Object.hash(
        todayDurationSeconds,
        weekDurationSeconds,
        totalDurationSeconds,
        todayItemsCompleted,
        weekItemsCompleted,
        totalItemsCompleted,
      );

  @override
  String toString() =>
      'StudyTimeStats(today: ${todayDurationMinutes}m, week: ${weekDurationMinutes}m, total: ${totalDurationMinutes}m)';
}

/// Unified, immutably assembled data bundle for the HI Chinese Home Screen.
@immutable
class HomeDashboardData {
  final String learnerName;
  final String greeting;
  final LearningStreak streak;
  final int srsDueCount;
  final RoadmapProgress roadmap;
  final List<RecentActivityItem> recentActivities;
  final int dailyGoalWords;
  final int dailyGoalMinutes;
  final StudyTimeStats studyStats;
  final bool hasCompletedLessons;

  const HomeDashboardData({
    required this.learnerName,
    required this.greeting,
    required this.streak,
    required this.srsDueCount,
    required this.roadmap,
    required this.recentActivities,
    this.dailyGoalWords = 15,
    this.dailyGoalMinutes = 15,
    this.studyStats = const StudyTimeStats(),
    this.hasCompletedLessons = false,
  });

  /// Progress ratio towards today's word goal (0.0 to 1.0)
  double get dailyGoalProgressRatio {
    if (dailyGoalWords <= 0) return 1.0;
    return (streak.todayItemsCompleted / dailyGoalWords).clamp(0.0, 1.0);
  }

  /// True if the learner has reached today's vocabulary goal
  bool get isDailyGoalAchieved =>
      streak.todayItemsCompleted >= dailyGoalWords && dailyGoalWords > 0;

  /// Default initial dashboard data for empty/fresh state
  factory HomeDashboardData.empty() => HomeDashboardData(
        learnerName: 'Học viên',
        greeting: 'Chào mừng bạn!',
        streak: LearningStreak.empty(),
        srsDueCount: 0,
        roadmap: RoadmapProgress.initial(),
        recentActivities: const [],
        studyStats: const StudyTimeStats(),
        hasCompletedLessons: false,
      );
}
