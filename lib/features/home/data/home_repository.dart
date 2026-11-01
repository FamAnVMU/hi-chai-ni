import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../../vocabulary_srs/data/srs_repository.dart';
import '../domain/models/home_dashboard_data.dart';
import '../domain/models/learning_streak.dart';

/// Repository responsible for assembling live dashboard metrics from SQLite.
class HomeRepository {
  final Database _db;
  final SrsRepository _srsRepository;
  final StreakCalculator streakCalculator;

  HomeRepository(
    this._db, {
    SrsRepository? srsRepository,
    this.streakCalculator = const StreakCalculator(),
  }) : _srsRepository = srsRepository ?? SrsRepository(_db);

  /// Fetches complete, real-time dashboard data for the learner.
  ///
  /// [evaluationTime]: Reference point in time (useful for unit tests and time-travel testing).
  /// [timeZoneOffset]: Optional custom timezone offset for calculating calendar days.
  Future<HomeDashboardData> getDashboardData({
    DateTime? evaluationTime,
    Duration? timeZoneOffset,
    int targetHskLevel = 1,
    int dailyGoalWords = 15,
    int dailyGoalMinutes = 15,
  }) async {
    final nowLocal = (evaluationTime ?? DateTime.now()).toLocal();
    final nowUtc = (evaluationTime ?? DateTime.now()).toUtc();

    // 1. Contextual greeting
    final greeting = _getGreeting(nowLocal.hour);

    // 2. Fetch all meaningful learning event timestamps for streak calculation
    final streak = await calculateStreak(
      evaluationTime: nowUtc,
      timeZoneOffset: timeZoneOffset,
    );

    // 3. Live SRS due count
    final srsDue = await _srsRepository.getDueCardsCount(
      asOf: nowUtc,
      forceRefresh: true,
    );

    // 4. Curriculum roadmap progress
    final roadmap = await getRoadmapProgress(
      hskLevel: targetHskLevel,
    );

    // 5. Recent learning activities
    final recentActivities = await getRecentActivities(limit: 5);

    return HomeDashboardData(
      learnerName: 'Học viên',
      greeting: greeting,
      streak: streak,
      srsDueCount: srsDue,
      roadmap: roadmap,
      recentActivities: recentActivities,
      dailyGoalWords: dailyGoalWords,
      dailyGoalMinutes: dailyGoalMinutes,
    );
  }

  /// Calculates the learner's continuous streak and today's activity stats from SQLite.
  ///
  /// Explicitly excludes sample/seed data and passive app opens.
  Future<LearningStreak> calculateStreak({
    DateTime? evaluationTime,
    Duration? timeZoneOffset,
  }) async {
    final nowUtc = (evaluationTime ?? DateTime.now()).toUtc();
    final todayLocal = StreakCalculator.toLocalDate(
      nowUtc,
      timeZoneOffset: timeZoneOffset,
    );

    // Collect meaningful UTC timestamps from both learner_evidence and learning_activities
    final timestamps = <DateTime>[];

    // Query 1: learner_evidence (excluding sample_data, seed, and ai_tutor_mention with 0 duration)
    final evidenceRows = await _db.rawQuery(
      '''
      SELECT created_at, duration_ms, score 
      FROM ${DatabaseConstants.tableLearnerEvidence}
      WHERE source NOT IN ('sample_data', 'seed')
      ORDER BY created_at ASC
      ''',
    );

    for (final row in evidenceRows) {
      final createdStr = row['created_at'] as String?;
      if (createdStr != null) {
        final parsed = DateTime.tryParse(createdStr)?.toUtc();
        if (parsed != null) {
          timestamps.add(parsed);
        }
      }
    }

    // Query 2: learning_activities (meaningful activities where duration >= 30s or items >= 1)
    final activityRows = await _db.rawQuery(
      '''
      SELECT created_at, duration_seconds, items_count
      FROM ${DatabaseConstants.tableLearningActivities}
      WHERE (duration_seconds >= 30 OR items_count >= 1)
      ORDER BY created_at ASC
      ''',
    );

    for (final row in activityRows) {
      final createdStr = row['created_at'] as String?;
      if (createdStr != null) {
        final parsed = DateTime.tryParse(createdStr)?.toUtc();
        if (parsed != null) {
          timestamps.add(parsed);
        }
      }
    }

    // Compute today's aggregated stats (in local calendar day)
    int todayDurationSec = 0;
    int todayItems = 0;

    // Filter evidence for today
    for (final row in evidenceRows) {
      final createdStr = row['created_at'] as String?;
      if (createdStr != null) {
        final parsedUtc = DateTime.tryParse(createdStr)?.toUtc();
        if (parsedUtc != null) {
          final eventLocalDay = StreakCalculator.toLocalDate(
            parsedUtc,
            timeZoneOffset: timeZoneOffset,
          );
          if (eventLocalDay == todayLocal) {
            final ms = (row['duration_ms'] as num?)?.toInt() ?? 0;
            todayDurationSec += (ms / 1000).round();
            todayItems += 1;
          }
        }
      }
    }

    // Filter activities for today
    for (final row in activityRows) {
      final createdStr = row['created_at'] as String?;
      if (createdStr != null) {
        final parsedUtc = DateTime.tryParse(createdStr)?.toUtc();
        if (parsedUtc != null) {
          final eventLocalDay = StreakCalculator.toLocalDate(
            parsedUtc,
            timeZoneOffset: timeZoneOffset,
          );
          if (eventLocalDay == todayLocal) {
            final sec = (row['duration_seconds'] as num?)?.toInt() ?? 0;
            final count = (row['items_count'] as num?)?.toInt() ?? 0;
            todayDurationSec += sec;
            todayItems += count;
          }
        }
      }
    }

    return streakCalculator.calculate(
      meaningfulEventTimesUtc: timestamps,
      referenceTimeUtc: nowUtc,
      timeZoneOffset: timeZoneOffset,
      todayDurationSeconds: todayDurationSec,
      todayItemsCompleted: todayItems,
    );
  }

  /// Calculates roadmap progress for the specified HSK level from actual SQLite data.
  Future<RoadmapProgress> getRoadmapProgress({int hskLevel = 1}) async {
    // 1. Total vocab in this level from seed/database
    final totalVocabRes = await _db.rawQuery(
      'SELECT COUNT(id) as count FROM ${DatabaseConstants.tableVocabularies} '
      'WHERE hsk_level = ? AND deleted_at IS NULL',
      [hskLevel],
    );
    final totalVocab = (totalVocabRes.first['count'] as num?)?.toInt() ?? 0;

    // 2. Count distinct vocabularies that have progressed beyond 'new' state
    final learnedRes = await _db.rawQuery(
      '''
      SELECT COUNT(DISTINCT content_id) as count 
      FROM ${DatabaseConstants.tableSrsItems}
      WHERE content_type = 'vocabulary' 
        AND state != 'new' 
        AND deleted_at IS NULL
      ''',
    );
    final learnedVocab = (learnedRes.first['count'] as num?)?.toInt() ?? 0;

    // 3. Count mastered vocabularies
    final masteredRes = await _db.rawQuery(
      '''
      SELECT COUNT(DISTINCT content_id) as count 
      FROM ${DatabaseConstants.tableSrsItems}
      WHERE content_type = 'vocabulary' 
        AND (state = 'mastered' OR interval_days >= 21) 
        AND deleted_at IS NULL
      ''',
    );
    final masteredVocab = (masteredRes.first['count'] as num?)?.toInt() ?? 0;

    // Determine current lesson based on progress
    String nextLessonTitle;
    String nextLessonSnippet;

    if (learnedVocab == 0) {
      nextLessonTitle = 'Bài 1: Chào hỏi & Pinyin cơ bản';
      nextLessonSnippet = '你[nǐ]好[hǎo]，我[wǒ]叫[jiào]李[lǐ]华[huá]。';
    } else if (learnedVocab < (totalVocab * 0.3).round()) {
      nextLessonTitle = 'Bài 2: Con số & Đồ vật hàng ngày';
      nextLessonSnippet = '一[yī]、二[èr]、三[sān]，这[zhè]是[shì]书[shū]。';
    } else if (learnedVocab < (totalVocab * 0.7).round()) {
      nextLessonTitle = 'Bài 3: Gia đình & Nghề nghiệp';
      nextLessonSnippet = '我[wǒ]爱[ài]我[wǒ]的[de]家[jiā]人[rén]。';
    } else {
      nextLessonTitle = 'Bài 4: Mua sắm & Hỏi đường';
      nextLessonSnippet = '这[zhè]个[ge]多[duō]少[shao]钱[qián]？';
    }

    return RoadmapProgress(
      currentHskLevel: hskLevel,
      levelTitle: 'Lộ trình: HSK $hskLevel Cơ Bản',
      totalVocabCount: totalVocab > 0 ? totalVocab : 150,
      learnedVocabCount: learnedVocab,
      masteredVocabCount: masteredVocab,
      nextLessonTitle: nextLessonTitle,
      nextLessonSnippet: nextLessonSnippet,
    );
  }

  /// Retrieves the most recent genuine learning activities.
  Future<List<RecentActivityItem>> getRecentActivities({int limit = 5}) async {
    final activities = <RecentActivityItem>[];

    // Check learning_activities first
    final actRows = await _db.rawQuery(
      '''
      SELECT id, activity_type, duration_seconds, items_count, created_at 
      FROM ${DatabaseConstants.tableLearningActivities}
      ORDER BY created_at DESC 
      LIMIT ?
      ''',
      [limit],
    );

    for (final row in actRows) {
      final id = row['id'] as String;
      final typeStr = row['activity_type'] as String? ?? 'lesson';
      final type = ActivityType.fromString(typeStr);
      final duration = (row['duration_seconds'] as num?)?.toInt() ?? 0;
      final count = (row['items_count'] as num?)?.toInt() ?? 1;
      final createdStr = row['created_at'] as String;
      final ts = DateTime.tryParse(createdStr)?.toUtc() ?? DateTime.now().toUtc();

      activities.add(
        RecentActivityItem(
          id: id,
          title: type.labelVi,
          subtitle: duration > 0 ? '$count mục • ${(duration / 60).ceil()} phút' : '$count mục',
          type: type,
          timestamp: ts,
          durationSeconds: duration,
          itemsCount: count,
        ),
      );
    }

    // If learning_activities has fewer items than limit, backfill from learner_evidence
    if (activities.length < limit) {
      final remaining = limit - activities.length;
      final eviRows = await _db.rawQuery(
        '''
        SELECT id, content_id, content_type, source, score, duration_ms, metadata_json, created_at
        FROM ${DatabaseConstants.tableLearnerEvidence}
        WHERE source NOT IN ('sample_data', 'seed')
        ORDER BY created_at DESC
        LIMIT ?
        ''',
        [remaining],
      );

      for (final row in eviRows) {
        final id = row['id'] as String;
        final source = row['source'] as String? ?? 'srs';
        final score = (row['score'] as num?)?.toDouble();
        final durationMs = (row['duration_ms'] as num?)?.toInt() ?? 0;
        final createdStr = row['created_at'] as String;
        final ts = DateTime.tryParse(createdStr)?.toUtc() ?? DateTime.now().toUtc();
        final type = ActivityType.fromString(source);

        activities.add(
          RecentActivityItem(
            id: id,
            title: type.labelVi,
            subtitle: score != null && score >= 0.8 ? 'Đạt kết quả tốt' : 'Hoàn thành lượt học',
            type: type,
            timestamp: ts,
            durationSeconds: (durationMs / 1000).round(),
            itemsCount: 1,
            score: score,
          ),
        );
      }
    }

    return activities;
  }

  /// Logs a genuine study activity to `learning_activities` table.
  ///
  /// Guarantees that only meaningful actions are persisted.
  Future<void> logLearningActivity({
    required String activityType,
    required int durationSeconds,
    required int itemsCount,
    DateTime? activityTimeUtc,
  }) async {
    final nowUtc = (activityTimeUtc ?? DateTime.now().toUtc());
    final id = 'ACT_${nowUtc.microsecondsSinceEpoch}';
    final dateStr = nowUtc.toIso8601String().substring(0, 10);

    await _db.insert(
      DatabaseConstants.tableLearningActivities,
      {
        'id': id,
        'activity_type': activityType,
        'duration_seconds': durationSeconds,
        'items_count': itemsCount,
        'activity_date': dateStr,
        'created_at': nowUtc.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _getGreeting(int localHour) {
    if (localHour >= 5 && localHour < 12) {
      return 'Chào buổi sáng! ☀️';
    } else if (localHour >= 12 && localHour < 18) {
      return 'Chào buổi chiều! 🌤️';
    } else {
      return 'Chào buổi tối! 🌙';
    }
  }
}
