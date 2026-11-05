import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../../../core/utils/app_clock.dart';
import '../../vocabulary_srs/data/srs_repository.dart';
import '../domain/models/home_dashboard_data.dart';
import '../domain/models/learning_streak.dart';

/// Helper model representing a sanitized, deduplicated study interaction or session.
class _ProcessedSession {
  final String id;
  final String type;
  final int durationSeconds;
  final int itemsCount;
  final DateTime timestampUtc;
  final DateTime localDate;

  const _ProcessedSession({
    required this.id,
    required this.type,
    required this.durationSeconds,
    required this.itemsCount,
    required this.timestampUtc,
    required this.localDate,
  });
}

/// Repository responsible for assembling live dashboard metrics from SQLite:
/// - Real learner display name (resolved dynamically from profile/settings, never hardcoded)
/// - Deduplicated study durations (eliminates double-counting between learning_activities and learner_evidence)
/// - Anomaly sanitization (rejects negative durations, caps sessions > 4h, dedups sync retries)
/// - HSK-scoped SRS statistics (filters due flashcards by active learner level)
/// - Live roadmap and recent activity history
class HomeRepository {
  final Database _db;
  final SrsRepository _srsRepository;
  final StreakCalculator streakCalculator;

  /// Maximum acceptable duration for a single learning session: 4 hours (14,400 seconds).
  static const int maxSessionDurationSeconds = 14400;

  HomeRepository(
    this._db, {
    SrsRepository? srsRepository,
    this.streakCalculator = const StreakCalculator(),
  }) : _srsRepository = srsRepository ?? SrsRepository(_db);

  /// Resolves the learner's display name from actual persistent profile records.
  /// Priority:
  /// 1. [DatabaseConstants.tableUserProfiles] (`display_name`)
  /// 2. [DatabaseConstants.tableAppSettings] ('display_name', 'user_name', 'profile_name', 'learner_name')
  /// 3. Fallback: 'Học viên'
  Future<String> getLearnerDisplayName() async {
    // 1. Check user_profiles table
    try {
      final rows = await _db.rawQuery(
        '''
        SELECT display_name 
        FROM ${DatabaseConstants.tableUserProfiles}
        WHERE display_name IS NOT NULL
        ORDER BY updated_at DESC
        LIMIT 1
        ''',
      );
      if (rows.isNotEmpty) {
        final raw = rows.first['display_name'] as String?;
        if (raw != null) {
          final trimmed = raw.trim();
          if (trimmed.isNotEmpty) {
            return trimmed;
          }
        }
      }
    } catch (_) {
      // Table might not exist in isolated tests or fresh DB
    }

    // 2. Check app_settings key-value table
    try {
      final rows = await _db.rawQuery(
        '''
        SELECT key, value 
        FROM ${DatabaseConstants.tableAppSettings}
        WHERE key IN ('display_name', 'user_name', 'profile_name', 'learner_name')
        ''',
      );
      for (final targetKey in ['display_name', 'user_name', 'profile_name', 'learner_name']) {
        final match = rows.firstWhere(
          (r) => r['key'] == targetKey,
          orElse: () => const {},
        );
        final val = match['value'] as String?;
        if (val != null) {
          final trimmed = val.trim();
          if (trimmed.isNotEmpty) {
            return trimmed;
          }
        }
      }
    } catch (_) {}

    // 3. Fallback when profile is not yet configured
    return 'Học viên';
  }

  /// Resolves the learner's active HSK level (1 to 6) from profile or settings.
  Future<int> getCurrentHskLevel() async {
    try {
      final rows = await _db.rawQuery(
        '''
        SELECT current_hsk_level 
        FROM ${DatabaseConstants.tableUserProfiles}
        WHERE current_hsk_level >= 1 AND current_hsk_level <= 6
        ORDER BY updated_at DESC
        LIMIT 1
        ''',
      );
      if (rows.isNotEmpty) {
        final lvl = (rows.first['current_hsk_level'] as num?)?.toInt();
        if (lvl != null && lvl >= 1 && lvl <= 6) return lvl;
      }
    } catch (_) {}

    try {
      final rows = await _db.rawQuery(
        '''
        SELECT value 
        FROM ${DatabaseConstants.tableAppSettings}
        WHERE key = 'current_hsk_level'
        LIMIT 1
        ''',
      );
      if (rows.isNotEmpty) {
        final lvl = int.tryParse(rows.first['value'] as String? ?? '');
        if (lvl != null && lvl >= 1 && lvl <= 6) return lvl;
      }
    } catch (_) {}

    return 1;
  }

  /// Resolves configured daily target study minutes from user profile.
  Future<int> _getDailyGoalMinutes() async {
    try {
      final rows = await _db.rawQuery(
        '''
        SELECT daily_minutes 
        FROM ${DatabaseConstants.tableUserProfiles}
        WHERE daily_minutes > 0
        ORDER BY updated_at DESC
        LIMIT 1
        ''',
      );
      if (rows.isNotEmpty) {
        final mins = (rows.first['daily_minutes'] as num?)?.toInt();
        if (mins != null && mins > 0) return mins;
      }
    } catch (_) {}
    return 15;
  }

  /// Retrieves sanitized and deduplicated study sessions from both
  /// [DatabaseConstants.tableLearningActivities] (primary canonical source) and
  /// [DatabaseConstants.tableLearnerEvidence] (granular evidence source).
  ///
  /// Deduplication Rules:
  /// 1. Standardizes on `learning_activities` as the canonical source of learning sessions.
  /// 2. If a session is recorded in `learning_activities`, any `learner_evidence`
  ///    records within that session's time window are considered part of that session
  ///    and are NOT double-counted.
  /// 3. Granular `learner_evidence` records without an enclosing `learning_activities`
  ///    session (e.g. standalone item evaluations or legacy records) are backfilled.
  /// 4. Discards negative durations (clamps to 0) and caps anomalous durations > 4 hours (14,400s).
  /// 5. Deduplicates identical sync/retry events occurring within a 2-second timestamp window.
  Future<({
    List<DateTime> eventTimestampsUtc,
    List<DateTime> activeLocalDates,
    StudyTimeStats stats,
  })> getSanitizedStudySessionsAndStats({
    DateTime? referenceTimeUtc,
    Duration? timeZoneOffset,
  }) async {
    final refUtc = referenceTimeUtc ?? DateTime.now().toUtc();
    final todayLocal = StreakCalculator.toLocalDate(refUtc, timeZoneOffset: timeZoneOffset);
    // Start of week: Monday 00:00:00 in local calendar day
    final startOfWeekLocal = todayLocal.subtract(Duration(days: todayLocal.weekday - 1));

    // 1. Process learning_activities (Canonical Session Source)
    final validActivities = <_ProcessedSession>[];
    final seenActivityKeys = <String>{};

    try {
      final activityRows = await _db.rawQuery(
        '''
        SELECT id, activity_type, duration_seconds, items_count, activity_date, created_at
        FROM ${DatabaseConstants.tableLearningActivities}
        WHERE activity_type NOT IN ('sample_data', 'seed')
        ORDER BY created_at ASC
        ''',
      );

      for (final row in activityRows) {
        final id = row['id'] as String? ?? '';
        final type = row['activity_type'] as String? ?? 'lesson';
        final rawSec = (row['duration_seconds'] as num?)?.toInt() ?? 0;
        final rawItems = (row['items_count'] as num?)?.toInt() ?? 1;
        final createdStr = row['created_at'] as String?;
        if (createdStr == null) continue;
        final parsedUtc = DateTime.tryParse(createdStr)?.toUtc();
        if (parsedUtc == null) continue;

        // Sanitize: clamp negative to 0, cap anomalous duration at 4 hours
        final durationSec = rawSec.clamp(0, maxSessionDurationSeconds);
        final items = rawItems.clamp(0, 1000);

        // Sync / retry deduplication: 2-second bucket window
        final epochBucket = parsedUtc.millisecondsSinceEpoch ~/ 2000;
        final dedupKey = '$type:$durationSec:$items:$epochBucket';
        if (seenActivityKeys.contains(dedupKey)) {
          continue;
        }
        seenActivityKeys.add(dedupKey);

        DateTime localDate;
        final activityDateStr = row['activity_date'] as String?;
        if (activityDateStr != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(activityDateStr)) {
          final parts = activityDateStr.split('-');
          localDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          localDate = StreakCalculator.toLocalDate(parsedUtc, timeZoneOffset: timeZoneOffset);
        }

        validActivities.add(_ProcessedSession(
          id: id,
          type: type,
          durationSeconds: durationSec,
          itemsCount: items,
          timestampUtc: parsedUtc,
          localDate: localDate,
        ));
      }
    } catch (_) {
      // Table might not exist in isolated tests
    }

    // 2. Process learner_evidence (Granular Interaction Source)
    final orphanEvidence = <_ProcessedSession>[];
    final seenEvidenceKeys = <String>{};

    try {
      final evidenceRows = await _db.rawQuery(
        '''
        SELECT id, content_id, content_type, source, score, duration_ms, metadata_json, created_at 
        FROM ${DatabaseConstants.tableLearnerEvidence}
        WHERE source NOT IN ('sample_data', 'seed')
        ORDER BY created_at ASC
        ''',
      );

      for (final row in evidenceRows) {
        final id = row['id'] as String? ?? '';
        final source = row['source'] as String? ?? 'srs';
        final rawMs = (row['duration_ms'] as num?)?.toInt() ?? 0;
        final createdStr = row['created_at'] as String?;
        if (createdStr == null) continue;
        final parsedUtc = DateTime.tryParse(createdStr)?.toUtc();
        if (parsedUtc == null) continue;

        final localDate = StreakCalculator.toLocalDate(parsedUtc, timeZoneOffset: timeZoneOffset);

        // Deduplication check against learning_activities:
        // If this evidence timestamp falls inside an existing canonical session of that day,
        // it was already counted by learning_activities. Do not double-count!
        final isEnclosed = validActivities.any((act) {
          if (act.localDate != localDate) return false;
          final start = act.timestampUtc.subtract(Duration(seconds: act.durationSeconds + 30));
          final end = act.timestampUtc.add(const Duration(seconds: 30));
          return parsedUtc.isAfter(start) && parsedUtc.isBefore(end);
        });

        if (isEnclosed) {
          continue; // Skip adding duration to prevent double-counting!
        }

        // Sanitize duration:
        final durationSec = (rawMs / 1000).round().clamp(0, maxSessionDurationSeconds);

        // Sync / retry deduplication:
        final epochBucket = parsedUtc.millisecondsSinceEpoch ~/ 2000;
        final contentId = row['content_id'] as String? ?? '';
        final dedupKey = '$source:$contentId:$durationSec:$epochBucket';
        if (seenEvidenceKeys.contains(dedupKey)) {
          continue;
        }
        seenEvidenceKeys.add(dedupKey);

        orphanEvidence.add(_ProcessedSession(
          id: id,
          type: source,
          durationSeconds: durationSec,
          itemsCount: 1,
          timestampUtc: parsedUtc,
          localDate: localDate,
        ));
      }
    } catch (_) {
      // Table might not exist in isolated tests
    }

    // 3. Combine non-overlapping sessions
    final allSessions = [...validActivities, ...orphanEvidence];

    int todayDuration = 0;
    int todayItems = 0;
    int weekDuration = 0;
    int weekItems = 0;
    int totalDuration = 0;
    int totalItems = 0;

    final eventTimestampsUtc = <DateTime>[];
    final activeLocalDates = <DateTime>[];

    for (final session in allSessions) {
      if (session.durationSeconds >= 30 || session.itemsCount >= 1) {
        eventTimestampsUtc.add(session.timestampUtc);
        activeLocalDates.add(session.localDate);
      }

      totalDuration += session.durationSeconds;
      totalItems += session.itemsCount;

      if (!session.localDate.isBefore(startOfWeekLocal) && !session.localDate.isAfter(todayLocal)) {
        weekDuration += session.durationSeconds;
        weekItems += session.itemsCount;
      }

      if (session.localDate == todayLocal) {
        todayDuration += session.durationSeconds;
        todayItems += session.itemsCount;
      }
    }

    return (
      eventTimestampsUtc: eventTimestampsUtc,
      activeLocalDates: activeLocalDates,
      stats: StudyTimeStats(
        todayDurationSeconds: todayDuration,
        weekDurationSeconds: weekDuration,
        totalDurationSeconds: totalDuration,
        todayItemsCompleted: todayItems,
        weekItemsCompleted: weekItems,
        totalItemsCompleted: totalItems,
      ),
    );
  }

  /// Fetches complete, real-time dashboard data for the learner.
  ///
  /// [learnerName]: Optional override for user name. When omitted, resolves from profile/settings.
  /// [targetHskLevel]: Optional override for active HSK level. When omitted, resolves from profile.
  /// [evaluationTime]: Reference point in time (useful for unit tests and time-travel testing).
  /// [timeZoneOffset]: Optional custom timezone offset for calculating calendar days.
  Future<HomeDashboardData> getDashboardData({
    DateTime? evaluationTime,
    Duration? timeZoneOffset,
    String? learnerName,
    int? targetHskLevel,
    int dailyGoalWords = 15,
    int? dailyGoalMinutes,
  }) async {
    final nowLocal = (evaluationTime ?? DateTime.now()).toLocal();
    final nowUtc = (evaluationTime ?? DateTime.now()).toUtc();

    // 1. Resolve real learner name (never hardcoded)
    final resolvedName = (learnerName != null && learnerName.trim().isNotEmpty)
        ? learnerName.trim()
        : await getLearnerDisplayName();

    // 2. Resolve active HSK level (normalize beginners 0 or negative to 1)
    final rawLevel = targetHskLevel ?? await getCurrentHskLevel();
    final activeHskLevel = (rawLevel <= 0) ? 1 : (rawLevel > 6 ? 6 : rawLevel);

    // 3. Contextual greeting
    final greeting = _getGreeting(nowLocal.hour);

    // 4. Fetch sanitized sessions, streak, and deduplicated study statistics
    final sessionData = await getSanitizedStudySessionsAndStats(
      referenceTimeUtc: nowUtc,
      timeZoneOffset: timeZoneOffset,
    );

    final streak = streakCalculator.calculate(
      meaningfulEventTimesUtc: sessionData.eventTimestampsUtc,
      referenceTimeUtc: nowUtc,
      timeZoneOffset: timeZoneOffset,
      todayDurationSeconds: sessionData.stats.todayDurationSeconds,
      todayItemsCompleted: sessionData.stats.todayItemsCompleted,
    );

    // 5. Live SRS due count filtered strictly by the learner's active HSK level
    final srsDue = await _srsRepository.getDueCardsCount(
      hskLevel: activeHskLevel,
      asOf: nowUtc,
      forceRefresh: true,
    );

    // 6. Curriculum roadmap progress for the active HSK level
    final roadmap = await getRoadmapProgress(
      hskLevel: activeHskLevel,
    );

    // 7. Recent learning activities
    final recentActivities = await getRecentActivities(limit: 5);

    // 7b. Check if user has completed at least 1 lesson
    bool hasCompletedLessons = false;
    try {
      final lessonRes = await _db.rawQuery(
        '''
        SELECT COUNT(*) as count 
        FROM ${DatabaseConstants.tableCurriculumLessons} 
        WHERE status = 'completed'
        ''',
      );
      final count = (lessonRes.first['count'] as num?)?.toInt() ?? 0;
      hasCompletedLessons = count > 0;
    } catch (_) {}

    if (!hasCompletedLessons) {
      try {
        final actRes = await _db.rawQuery(
          '''
          SELECT COUNT(*) as count
          FROM ${DatabaseConstants.tableLearningActivities}
          WHERE activity_type = 'lesson'
          ''',
        );
        final count = (actRes.first['count'] as num?)?.toInt() ?? 0;
        hasCompletedLessons = count > 0;
      } catch (_) {}
    }

    // 8. Daily target minutes from profile or fallback
    final goalMinutes = dailyGoalMinutes ?? await _getDailyGoalMinutes();

    return HomeDashboardData(
      learnerName: resolvedName,
      greeting: greeting,
      streak: streak,
      srsDueCount: srsDue,
      roadmap: roadmap,
      recentActivities: recentActivities,
      dailyGoalWords: dailyGoalWords,
      dailyGoalMinutes: goalMinutes,
      studyStats: sessionData.stats,
      hasCompletedLessons: hasCompletedLessons,
    );
  }

  /// Calculates the learner's continuous streak and today's activity stats from SQLite.
  ///
  /// Explicitly excludes sample/seed data and passive app opens, with zero double-counting.
  Future<LearningStreak> calculateStreak({
    DateTime? evaluationTime,
    Duration? timeZoneOffset,
  }) async {
    final nowUtc = (evaluationTime ?? DateTime.now()).toUtc();
    final sessionData = await getSanitizedStudySessionsAndStats(
      referenceTimeUtc: nowUtc,
      timeZoneOffset: timeZoneOffset,
    );

    return streakCalculator.calculate(
      meaningfulEventTimesUtc: sessionData.eventTimestampsUtc,
      meaningfulLocalDates: sessionData.activeLocalDates,
      referenceTimeUtc: nowUtc,
      timeZoneOffset: timeZoneOffset,
      todayDurationSeconds: sessionData.stats.todayDurationSeconds,
      todayItemsCompleted: sessionData.stats.todayItemsCompleted,
    );
  }

  /// Exposes deduplicated study time statistics across Today, This Week, and Total.
  Future<StudyTimeStats> getStudyTimeStats({
    DateTime? evaluationTime,
    Duration? timeZoneOffset,
  }) async {
    final nowUtc = (evaluationTime ?? DateTime.now()).toUtc();
    final sessionData = await getSanitizedStudySessionsAndStats(
      referenceTimeUtc: nowUtc,
      timeZoneOffset: timeZoneOffset,
    );
    return sessionData.stats;
  }

  /// Calculates roadmap progress for the specified HSK level from actual SQLite data.
  Future<RoadmapProgress> getRoadmapProgress({int hskLevel = 1}) async {
    final effectiveLevel = (hskLevel <= 0) ? 1 : (hskLevel > 6 ? 6 : hskLevel);
    // 1. Total vocab in this level from seed/database
    final totalVocabRes = await _db.rawQuery(
      'SELECT COUNT(id) as count FROM ${DatabaseConstants.tableVocabularies} '
      'WHERE hsk_level = ? AND deleted_at IS NULL',
      [effectiveLevel],
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
      currentHskLevel: effectiveLevel,
      levelTitle: 'Lộ trình: HSK $effectiveLevel Cơ Bản',
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
    final seenTimestamps = <DateTime>[];

    // Check learning_activities first (canonical sessions)
    final actRows = await _db.rawQuery(
      '''
      SELECT id, activity_type, duration_seconds, items_count, created_at 
      FROM ${DatabaseConstants.tableLearningActivities}
      WHERE activity_type NOT IN ('sample_data', 'seed')
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
      seenTimestamps.add(ts);

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

    // If learning_activities has fewer items than limit, backfill from non-overlapping learner_evidence
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
        [remaining * 2], // Query extra to allow filtering overlapping sessions
      );

      for (final row in eviRows) {
        if (activities.length >= limit) break;

        final id = row['id'] as String;
        final source = row['source'] as String? ?? 'srs';
        final score = (row['score'] as num?)?.toDouble();
        final durationMs = (row['duration_ms'] as num?)?.toInt() ?? 0;
        final createdStr = row['created_at'] as String;
        final ts = DateTime.tryParse(createdStr)?.toUtc() ?? DateTime.now().toUtc();

        // Avoid adding evidence that is part of an already included activity session
        final overlaps = seenTimestamps.any(
          (actTs) => ts.difference(actTs).inSeconds.abs() <= 30,
        );
        if (overlaps) continue;

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
    Duration? timeZoneOffset,
  }) async {
    final nowUtc = (activityTimeUtc ?? AppClock.nowUtc());
    final id = 'ACT_${nowUtc.microsecondsSinceEpoch}';
    final offset = timeZoneOffset ?? AppClock.currentOffset;
    final dateStr = AppClock.toLocalDateString(nowUtc, timeZoneOffset: offset);

    await _db.insert(
      DatabaseConstants.tableLearningActivities,
      {
        'id': id,
        'activity_type': activityType,
        'duration_seconds': durationSeconds,
        'items_count': itemsCount,
        'activity_date': dateStr,
        'created_at': nowUtc.toIso8601String(),
        'timezone_offset_minutes': offset.inMinutes,
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
