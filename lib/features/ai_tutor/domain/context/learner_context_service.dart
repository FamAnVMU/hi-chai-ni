import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_constants.dart';
import '../models/learner_context.dart';
import '../models/tutor_correction.dart';

/// Assembles a [LearnerContext] by querying SQLite tables in parallel.
///
/// Design:
/// - Runs queries concurrently where possible (Future.wait).
/// - Applies a token budget: truncates lists before total estimate exceeds [maxContextTokens].
/// - Detects conflicting evidence (word confirmed as learned AND recurring error).
/// - [ConfirmedVocabulary]: only words with evidence source != 'ai_tutor_mention'
///   and score >= [_minConfirmedScore].
/// - [RecurringError]: groups learner_evidence where score < [_errorScoreThreshold],
///   content_type = 'ai_tutor_dialogue', and occurrence count >= [_minErrorOccurrences].
/// - All timestamps in UTC.
class LearnerContextService {
  /// Rough characters-per-token estimate for budget calculation.
  static const int _charsPerToken = 4;

  /// Default token budget (characters / 4) allocated for learner context block.
  static const int defaultMaxContextTokens = 1200;

  /// Words need at least this score in evidence to count as "confirmed learned".
  static const double _minConfirmedScore = 0.5;

  /// Evidence score below this threshold is considered an error signal.
  static const double _errorScoreThreshold = 0.5;

  /// Minimum occurrences of an error pattern to include in context.
  static const int _minErrorOccurrences = 2;

  // In-memory cache for session learner contexts to avoid redundant DB joins during multi-turn chat
  static final Map<String, ({LearnerContext context, DateTime expiresAt})> _cache = {};

  /// Clears in-memory cache for a given session or all sessions.
  static void invalidateCache([String? sessionId]) {
    if (sessionId != null) {
      _cache.remove(sessionId);
    } else {
      _cache.clear();
    }
  }

  const LearnerContextService();

  /// Builds a [LearnerContext] for the given [sessionId].
  ///
  /// Parameters:
  /// - [db]: active [DatabaseExecutor].
  /// - [sessionId]: current session (used for recent chat summary query).
  /// - [maxVocab]: max confirmed vocabulary items to include (by relevance).
  /// - [maxErrors]: max recurring error patterns to include.
  /// - [maxEvidence]: max recent evidence entries to include.
  /// - [maxContextTokens]: estimated token budget for the entire context block.
  Future<LearnerContext> buildContext(
    DatabaseExecutor db, {
    required String sessionId,
    int hskLevel = 1,
    String learnerName = 'Học viên',
    String? customGoal,
    String? learningPathType,
    String? focusSkill,
    bool? hasCompletedLessons,
    int maxVocab = 20,
    int maxErrors = 5,
    int maxEvidence = 10,
    int maxContextTokens = defaultMaxContextTokens,
    Duration cacheTtl = const Duration(seconds: 30),
    bool bypassCache = false,
  }) async {
    final now = DateTime.now();
    if (!bypassCache) {
      final cached = _cache[sessionId];
      if (cached != null && cached.expiresAt.isAfter(now)) {
        return cached.context;
      }
    }

    // Run independent queries in parallel
    final results = await Future.wait([
      _loadConfirmedVocabulary(db, maxVocab * 2), // fetch extra, prune by budget
      _loadRecurringErrors(db, maxErrors * 2),
      _loadMasterySnapshots(db),
      _loadRecentEvidence(db, maxEvidence),
      _loadRecentChatSummary(db, sessionId),
      learningPathType == null || (learningPathType == 'focused' && focusSkill == null)
          ? _loadLearningPathSettings(db)
          : Future.value((learningPathType: learningPathType, focusSkill: focusSkill)),
      hasCompletedLessons == null
          ? _loadHasCompletedLessons(db)
          : Future.value(hasCompletedLessons),
    ]);

    final rawVocab = results[0] as List<ConfirmedVocabulary>;
    final rawErrors = results[1] as List<RecurringError>;
    final masteryBySkill = results[2] as Map<String, double>;
    final recentEvidence = results[3] as List<RecentEvidenceEntry>;
    final recentChatSummary = results[4] as String?;
    final pathSettings = results[5] as ({String learningPathType, String? focusSkill});
    final completedLessons = results[6] as bool;

    final resolvedLearningPathType = learningPathType ?? pathSettings.learningPathType;
    final resolvedFocusSkill = focusSkill ?? pathSettings.focusSkill;
    final resolvedHasCompletedLessons = hasCompletedLessons ?? completedLessons;

    // Detect conflicting evidence: word appears in both confirmed and error lists
    final errorExamples = {
      for (final e in rawErrors)
        for (final ex in e.examples) ex,
    };

    final warningFlags = <String>[];
    for (final vocab in rawVocab) {
      if (errorExamples.contains(vocab.simplified)) {
        warningFlags.add(
          "Từ '${vocab.simplified}' vừa có trong danh sách đã học "
          'vừa có trong lỗi lặp — cần kiểm tra lại bằng chứng.',
        );
      }
    }

    // Apply token budget: estimate tokens consumed and prune lists
    var budgetRemaining = maxContextTokens;

    // Deduct mastery section estimate (small, always include)
    final masteryText = masteryBySkill.entries
        .map((e) => '${e.key}: ${(e.value * 100).round()}%')
        .join(', ');
    budgetRemaining -= _estimateTokens(masteryText);

    // Deduct recent evidence estimate
    final evidenceText = recentEvidence.map((e) => e.contentId).join(' ');
    budgetRemaining -= _estimateTokens(evidenceText);

    // Deduct summary estimate
    if (recentChatSummary != null) {
      budgetRemaining -= _estimateTokens(recentChatSummary);
    }

    // Fit vocabulary into remaining budget
    final fittedVocab = <ConfirmedVocabulary>[];
    for (final v in rawVocab) {
      final entry = '${v.simplified} (${v.pinyin ?? ''}) - ${v.meaningVi ?? ''}';
      final cost = _estimateTokens(entry);
      if (budgetRemaining - cost < 0) break;
      budgetRemaining -= cost;
      fittedVocab.add(v);
      if (fittedVocab.length >= maxVocab) break;
    }

    // Fit errors into remaining budget
    final fittedErrors = <RecurringError>[];
    for (final e in rawErrors) {
      final entry = '${e.errorCategory.name}: ${e.examples.join(', ')}';
      final cost = _estimateTokens(entry);
      if (budgetRemaining - cost < 0) break;
      budgetRemaining -= cost;
      fittedErrors.add(e);
      if (fittedErrors.length >= maxErrors) break;
    }

    final budgetUsed = (maxContextTokens - budgetRemaining).clamp(0, maxContextTokens);

    final assembledContext = LearnerContext(
      profile: LearnerProfile(
        hskLevel: hskLevel,
        learnerName: learnerName,
        customGoal: customGoal,
        learningPathType: resolvedLearningPathType,
        focusSkill: resolvedFocusSkill,
        hasCompletedLessons: resolvedHasCompletedLessons,
      ),
      confirmedVocabulary: fittedVocab,
      recurringErrors: fittedErrors,
      masteryBySkill: masteryBySkill,
      recentEvidenceSummary: recentEvidence,
      recentChatSummary: recentChatSummary,
      contextBudgetUsed: budgetUsed,
      warningFlags: warningFlags,
    );

    _cache[sessionId] = (
      context: assembledContext,
      expiresAt: now.add(cacheTtl),
    );

    return assembledContext;
  }

  // ---------------------------------------------------------------------------
  // Internal loaders
  // ---------------------------------------------------------------------------

  /// Loads vocabulary items with real learner evidence of being taught/practiced.
  ///
  /// Criteria:
  /// - Joined learner_evidence ON vocabularies.id = learner_evidence.content_id
  /// - source != 'ai_tutor_mention' (words AI just mentioned don't count)
  /// - score >= [_minConfirmedScore]
  /// - At least 1 qualifying evidence row
  ///
  /// Sorted by evidence count DESC (most practiced first).
  Future<List<ConfirmedVocabulary>> _loadConfirmedVocabulary(
    DatabaseExecutor db,
    int limit,
  ) async {
    try {
      final rows = await db.rawQuery('''
        SELECT
          v.id            AS vocab_id,
          v.simplified,
          v.pinyin,
          vs.meaning_vi,
          v.hsk_level,
          COUNT(le.id)    AS evidence_count,
          MAX(le.created_at) AS last_evidence_at
        FROM ${DatabaseConstants.tableVocabularies} v
        LEFT JOIN ${DatabaseConstants.tableVocabularySenses} vs
          ON vs.vocabulary_id = v.id
        INNER JOIN ${DatabaseConstants.tableLearnerEvidence} le
          ON le.content_id = v.id
          AND le.content_type = 'vocabulary'
          AND le.source != 'ai_tutor_mention'
          AND le.score >= ?
        GROUP BY v.id
        ORDER BY evidence_count DESC, last_evidence_at DESC
        LIMIT ?
      ''', [_minConfirmedScore, limit]);

      return rows.map((row) {
        return ConfirmedVocabulary(
          vocabId: row['vocab_id'] as String? ?? '',
          simplified: row['simplified'] as String? ?? '',
          pinyin: row['pinyin'] as String?,
          meaningVi: row['meaning_vi'] as String?,
          hskLevel: (row['hsk_level'] as num?)?.toInt() ?? 1,
          evidenceCount: (row['evidence_count'] as num?)?.toInt() ?? 1,
          lastEvidenceAt: DateTime.tryParse(
            row['last_evidence_at'] as String? ?? '',
          )?.toUtc(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[LearnerContextService] _loadConfirmedVocabulary error: $e');
      return [];
    }
  }

  /// Loads recurring error patterns from [learner_evidence].
  ///
  /// Criteria:
  /// - content_type = 'ai_tutor_dialogue'
  /// - score < [_errorScoreThreshold]  (i.e. the AI flagged an error)
  /// - metadata_json contains 'error_category' key
  /// - Grouped by error_category
  /// - occurrenceCount >= [_minErrorOccurrences]
  Future<List<RecurringError>> _loadRecurringErrors(
    DatabaseExecutor db,
    int limit,
  ) async {
    try {
      // Fetch raw error evidence rows
      final rows = await db.rawQuery('''
        SELECT
          metadata_json,
          created_at
        FROM ${DatabaseConstants.tableLearnerEvidence}
        WHERE content_type = 'ai_tutor_dialogue'
          AND score < ?
          AND metadata_json IS NOT NULL
        ORDER BY created_at DESC
        LIMIT 200
      ''', [_errorScoreThreshold]);

      // Group by error_category extracted from metadata_json
      final Map<String, ({List<String> examples, int count, DateTime? lastAt})> groups = {};

      for (final row in rows) {
        final metaRaw = row['metadata_json'] as String?;
        if (metaRaw == null) continue;

        try {
          final meta = jsonDecode(metaRaw) as Map<String, dynamic>?;
          if (meta == null) continue;

          final category = meta['error_category'] as String?;
          final original = meta['original_text'] as String?;
          if (category == null || category == 'none') continue;

          final entry = groups[category];
          final examples = entry?.examples ?? [];
          if (original != null && examples.length < 3) {
            examples.add(original);
          }
          final lastAt = DateTime.tryParse(row['created_at'] as String? ?? '');
          groups[category] = (
            examples: examples,
            count: (entry?.count ?? 0) + 1,
            lastAt: entry?.lastAt ?? lastAt,
          );
        } catch (_) {
          continue;
        }
      }

      // Filter to patterns with enough occurrences and map to model
      final errors = groups.entries
          .where((e) => e.value.count >= _minErrorOccurrences)
          .map((e) {
            final category = TutorErrorCategory.values.firstWhere(
              (c) => c.name == e.key || c.name == _snakeToCamel(e.key),
              orElse: () => TutorErrorCategory.none,
            );
            return RecurringError(
              errorCategory: category,
              examples: e.value.examples,
              occurrenceCount: e.value.count,
              lastOccurredAt: e.value.lastAt,
            );
          })
          .where((e) => e.errorCategory != TutorErrorCategory.none)
          .toList();

      errors.sort((a, b) => b.occurrenceCount.compareTo(a.occurrenceCount));
      return errors.take(limit).toList();
    } catch (e) {
      debugPrint('[LearnerContextService] _loadRecurringErrors error: $e');
      return [];
    }
  }

  /// Loads the latest mastery snapshot per HSK level from [mastery_snapshots].
  Future<Map<String, double>> _loadMasterySnapshots(DatabaseExecutor db) async {
    try {
      final rows = await db.rawQuery('''
        SELECT hsk_level, accuracy_rate
        FROM ${DatabaseConstants.tableMasterySnapshots}
        ORDER BY snapshot_date DESC, created_at DESC
      ''');

      final Map<String, double> result = {};
      for (final row in rows) {
        final level = row['hsk_level'] as int?;
        final score = (row['accuracy_rate'] as num?)?.toDouble();
        if (level != null && score != null) {
          final key = 'HSK $level';
          if (!result.containsKey(key)) {
            result[key] = score.clamp(0.0, 1.0);
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('[LearnerContextService] _loadMasterySnapshots error: $e');
      return {};
    }
  }

  /// Loads the most recent learner evidence entries (any type).
  Future<List<RecentEvidenceEntry>> _loadRecentEvidence(
    DatabaseExecutor db,
    int limit,
  ) async {
    try {
      final rows = await db.rawQuery('''
        SELECT content_id, content_type, source, score, metadata_json, created_at
        FROM ${DatabaseConstants.tableLearnerEvidence}
        ORDER BY created_at DESC
        LIMIT ?
      ''', [limit]);

      return rows.map((row) {
        String? eventType;
        try {
          final meta = jsonDecode(row['metadata_json'] as String? ?? '{}');
          if (meta is Map) {
            eventType = meta['event_type'] as String?;
          }
        } catch (_) {}

        return RecentEvidenceEntry(
          contentId: row['content_id'] as String? ?? '',
          contentType: row['content_type'] as String? ?? '',
          source: row['source'] as String? ?? '',
          score: (row['score'] as num?)?.toDouble() ?? 0.0,
          eventType: eventType,
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[LearnerContextService] _loadRecentEvidence error: $e');
      return [];
    }
  }

  /// Loads a short summary of the most recent session prior to [currentSessionId].
  /// Returns the last assistant message from the previous session (if any).
  Future<String?> _loadRecentChatSummary(
    DatabaseExecutor db,
    String currentSessionId,
  ) async {
    try {
      final rows = await db.rawQuery('''
        SELECT cm.content
        FROM ${DatabaseConstants.tableChatMessages} cm
        INNER JOIN ${DatabaseConstants.tableChatSessions} cs
          ON cs.id = cm.session_id
        WHERE cm.session_id != ?
          AND cm.role = 'assistant'
          AND cm.content IS NOT NULL
        ORDER BY cm.created_at DESC
        LIMIT 1
      ''', [currentSessionId]);

      if (rows.isEmpty) return null;
      final text = rows.first['content'] as String?;
      if (text == null || text.trim().isEmpty) return null;

      // Return at most 300 chars to keep token cost low
      return text.length > 300 ? '${text.substring(0, 297)}...' : text;
    } catch (e) {
      debugPrint('[LearnerContextService] _loadRecentChatSummary error: $e');
      return null;
    }
  }

  /// Loads learning path type and focus skill from [DatabaseConstants.tableAppSettings].
  Future<({String learningPathType, String? focusSkill})> _loadLearningPathSettings(
    DatabaseExecutor db,
  ) async {
    try {
      final rows = await db.query(
        DatabaseConstants.tableAppSettings,
        where: 'key IN (?, ?)',
        whereArgs: ['priority_focus_skill', 'learning_path_type'],
      );
      String? rawType;
      String? rawSkill;
      for (final r in rows) {
        final k = r['key'] as String?;
        final v = r['value'] as String?;
        if (k == 'learning_path_type') rawType = v;
        if (k == 'priority_focus_skill') rawSkill = v;
      }

      if (rawType != null && rawType.isNotEmpty) {
        if (rawType.toLowerCase() == 'focused') {
          return (learningPathType: 'focused', focusSkill: rawSkill ?? 'reading');
        } else {
          return (learningPathType: 'comprehensive', focusSkill: null);
        }
      }

      if (rawSkill != null && rawSkill.isNotEmpty) {
        final lower = rawSkill.toLowerCase();
        if (lower == 'comprehensive' || lower == 'all' || lower == 'toandien') {
          return (learningPathType: 'comprehensive', focusSkill: null);
        } else {
          return (learningPathType: 'focused', focusSkill: rawSkill);
        }
      }

      return (learningPathType: 'comprehensive', focusSkill: null);
    } catch (e) {
      debugPrint('[LearnerContextService] _loadLearningPathSettings error: $e');
      return (learningPathType: 'comprehensive', focusSkill: null);
    }
  }

  /// Checks whether the user has completed at least one lesson in [DatabaseConstants.tableLessonProgress].
  Future<bool> _loadHasCompletedLessons(DatabaseExecutor db) async {
    try {
      final rows = await db.rawQuery('''
        SELECT COUNT(id) AS completed_count
        FROM ${DatabaseConstants.tableLessonProgress}
        WHERE status = 'completed' OR completed_at IS NOT NULL
      ''');
      if (rows.isNotEmpty) {
        final count = (rows.first['completed_count'] as int?) ?? 0;
        return count > 0;
      }
      return false;
    } catch (e) {
      debugPrint('[LearnerContextService] _loadHasCompletedLessons error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _estimateTokens(String text) => (text.length / _charsPerToken).ceil();

  /// Converts 'word_choice' → 'wordChoice' for enum matching.
  String _snakeToCamel(String snake) {
    final parts = snake.split('_');
    if (parts.length == 1) return snake;
    return parts.first +
        parts
            .skip(1)
            .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
            .join();
  }
}
