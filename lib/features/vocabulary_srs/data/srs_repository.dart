import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../../../core/knowledge/domain/services/knowledge_identity_registry.dart';
import '../../learning_pipeline/data/learning_pipeline_coordinator.dart';
import '../../learning_pipeline/domain/models/learning_evidence.dart';
import '../domain/sm2_engine.dart';
import '../domain/srs_models.dart';

class DuplicateReviewException implements Exception {
  final String message;
  DuplicateReviewException(this.message);

  @override
  String toString() => 'DuplicateReviewException: $message';
}

/// Repository managing persistence of SRS states, review execution,
/// append-only audit logging in `learner_evidence`, and double-tap prevention.
class SrsRepository {
  final Database _db;
  final Sm2Engine _engine;
  final LearningPipelineCoordinator _pipelineCoordinator;
  final KnowledgeIdentityRegistry _identityRegistry;

  // In-memory concurrency guards for double-tap and duplicate request prevention
  final Set<String> _inFlightContentIds = {};
  final Map<String, DateTime> _lastReviewTimes = {};

  // In-memory TTL cache for due counts to minimize disk reads
  final Map<String, ({int count, DateTime expiresAt})> _dueCountCache = {};

  /// Minimum cooldown window between two reviews for the same item (milliseconds)
  final int debounceCooldownMs;

  SrsRepository(
    this._db, {
    Sm2Engine? engine,
    LearningPipelineCoordinator? pipelineCoordinator,
    KnowledgeIdentityRegistry? identityRegistry,
    this.debounceCooldownMs = 800,
  })  : _engine = engine ?? const Sm2Engine(),
        _pipelineCoordinator = pipelineCoordinator ?? LearningPipelineCoordinator(_db),
        _identityRegistry = identityRegistry ?? KnowledgeIdentityRegistry(_db);

  Sm2Engine get engine => _engine;
  KnowledgeIdentityRegistry get identityRegistry => _identityRegistry;

  /// Retrieves an existing [SrsCardState] from the database or creates an initial new state.
  /// Resolves any vocabulary reference (alias, raw Hanzi, knowledge ID) to canonical vocabulary PK.
  Future<SrsCardState> getOrCreateCardState({
    required String contentId,
    String contentType = 'vocabulary',
  }) async {
    final effectiveContentId = (contentType == 'vocabulary')
        ? (await _identityRegistry.toCanonicalVocabularyId(contentId) ?? contentId)
        : contentId;

    final rows = await _db.query(
      DatabaseConstants.tableSrsItems,
      where: 'content_id = ? AND content_type = ? AND deleted_at IS NULL',
      whereArgs: [effectiveContentId, contentType],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return SrsCardState.fromMap(rows.first);
    }

    final newCard = SrsCardState.newCard(
      id: 'SRS_${contentType.toUpperCase()}_$effectiveContentId',
      contentId: effectiveContentId,
      contentType: contentType,
      initialEaseFactor: _engine.config.initialEaseFactor,
    );

    await _db.insert(
      DatabaseConstants.tableSrsItems,
      newCard.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    return newCard;
  }

  /// Executes an SRS review turn with strict double-tap protection,
  /// atomic state persistence, and append-only evidence recording.
  Future<SrsReviewResult> processReview({
    required String contentId,
    required SrsRating rating,
    String contentType = 'vocabulary',
    DateTime? reviewTime,
    int durationMs = 0,
    String source = 'srs_flashcard',
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final effectiveContentId = (contentType == 'vocabulary')
        ? (await _identityRegistry.toCanonicalVocabularyId(contentId) ?? contentId)
        : contentId;

    final lockKey = '${contentType}_$effectiveContentId';
    final nowUtc = (reviewTime ?? DateTime.now()).toUtc();

    // 1. Double-tap and rapid replay guard
    if (_inFlightContentIds.contains(lockKey)) {
      throw DuplicateReviewException(
        'Concurrent review already in-flight for item: $lockKey',
      );
    }

    final lastReview = _lastReviewTimes[lockKey];
    if (lastReview != null) {
      final elapsed = nowUtc.difference(lastReview).inMilliseconds;
      if (elapsed < debounceCooldownMs) {
        throw DuplicateReviewException(
          'Duplicate review rejected: $elapsed ms < $debounceCooldownMs ms debounce threshold.',
        );
      }
    }

    _inFlightContentIds.add(lockKey);

    try {
      // 2. Fetch current state
      final currentState = await getOrCreateCardState(
        contentId: effectiveContentId,
        contentType: contentType,
      );

      // 3. Compute pure next state via SM-2
      final reviewResult = _engine.calculateNextState(
        currentState: currentState,
        rating: rating,
        reviewTime: nowUtc,
      );

      final nextState = reviewResult.nextState;

      // 4. Atomic transaction: Update SRS state + Append to immutable Learner Evidence
      await _db.transaction((txn) async {
        // Update SRS item state
        await txn.update(
          DatabaseConstants.tableSrsItems,
          nextState.toMap(),
          where: 'id = ?',
          whereArgs: [nextState.id],
        );

        // Append to immutable learner_evidence (never overwriting prior evidence)
        final evidenceId = 'EVI_${DateTime.now().microsecondsSinceEpoch}_$effectiveContentId';
        final metadata = {
          'activity_type': ActivityType.retention.value,
          'is_success': reviewResult.isSuccessful,
          'rating': rating.label,
          'quality': rating.quality,
          'prev_interval': reviewResult.previousIntervalDays,
          'new_interval': reviewResult.newIntervalDays,
          'prev_ef': reviewResult.previousEaseFactor,
          'new_ef': reviewResult.newEaseFactor,
          'source': source,
          ...?additionalMetadata,
        };

        await txn.insert(
          DatabaseConstants.tableLearnerEvidence,
          {
            'id': evidenceId,
            'srs_item_id': nextState.id,
            'content_id': effectiveContentId,
            'content_type': contentType,
            'source': source,
            'score': reviewResult.isSuccessful ? 1.0 : 0.0,
            'duration_ms': durationMs,
            'metadata_json': json.encode(metadata),
            'created_at': nowUtc.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.abort, // Guarantees append-only integrity
        );

        // Synchronize with unified Learning Pipeline to update curriculum_mastery
        await _pipelineCoordinator.recordSrsReview(
          reviewResult: reviewResult,
          contentId: effectiveContentId,
          contentType: contentType,
          txn: txn,
        );
      });

      // Update cooldown timestamp & invalidate due count cache
      _lastReviewTimes[lockKey] = nowUtc;
      _dueCountCache.clear();

      return reviewResult;
    } finally {
      _inFlightContentIds.remove(lockKey);
    }
  }

  /// Retrieves list of cards due for review as of [asOf] time (defaults to now).
  Future<List<SrsCardState>> getDueCards({
    String contentType = 'vocabulary',
    DateTime? asOf,
    int limit = 50,
  }) async {
    final asOfUtc = (asOf ?? DateTime.now()).toUtc().toIso8601String();
    final rows = await _db.query(
      DatabaseConstants.tableSrsItems,
      where: 'content_type = ? AND due_at <= ? AND deleted_at IS NULL',
      whereArgs: [contentType, asOfUtc],
      orderBy: 'due_at ASC',
      limit: limit,
    );
    return rows.map((r) => SrsCardState.fromMap(r)).toList();
  }

  /// Retrieves complete append-only review history for an item.
  Future<List<Map<String, dynamic>>> getReviewHistory(
    String contentId, {
    String contentType = 'vocabulary',
    int limit = 50,
  }) async {
    return await _db.query(
      DatabaseConstants.tableLearnerEvidence,
      where: 'content_id = ? AND content_type = ?',
      whereArgs: [contentId, contentType],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// Retrieves rich flashcard items due for study, seamlessly pulling from
  /// unlearned vocabularies when due cards in SRS items are fewer than [limit].
  Future<List<SrsFlashcardItem>> getDueFlashcards({
    int limit = 30,
    int? hskLevel,
    DateTime? asOf,
  }) async {
    final asOfUtc = (asOf ?? DateTime.now()).toUtc().toIso8601String();

    String whereClause =
        's.content_type = ? AND s.due_at <= ? AND s.deleted_at IS NULL AND v.deleted_at IS NULL';
    final List<dynamic> whereArgs = ['vocabulary', asOfUtc];

    if (hskLevel != null) {
      whereClause += ' AND v.hsk_level = ?';
      whereArgs.add(hskLevel);
    }

    final query = '''
      SELECT s.*, 
             v.id AS vocab_id, v.simplified, v.traditional, v.pinyin, v.hsk_level, v.stroke_count, v.radicals, v.audio_uri,
             vs.part_of_speech, vs.meaning_vi, vs.example_cn, vs.example_pinyin, vs.example_vi
      FROM ${DatabaseConstants.tableSrsItems} s
      INNER JOIN ${DatabaseConstants.tableVocabularies} v ON s.content_id = v.id
      LEFT JOIN ${DatabaseConstants.tableVocabularySenses} vs ON vs.id = (
        SELECT vs2.id
        FROM ${DatabaseConstants.tableVocabularySenses} vs2
        WHERE vs2.vocabulary_id = v.id AND vs2.deleted_at IS NULL
        ORDER BY COALESCE(vs2.order_index, 999999) ASC, vs2.id ASC
        LIMIT 1
      )
      WHERE $whereClause
      ORDER BY s.due_at ASC
      LIMIT $limit
    ''';

    final rows = await _db.rawQuery(query, whereArgs);
    final results = <SrsFlashcardItem>[];

    for (final row in rows) {
      final srsState = SrsCardState.fromMap(row);
      final intervals = _engine.previewIntervals(srsState);
      final vocabId = (row['vocab_id'] ?? row['content_id'] ?? row['id']) as String;
      results.add(SrsFlashcardItem.fromDatabaseRow(
        row: {...row, 'id': vocabId},
        srsState: srsState,
        estimatedIntervalDays: intervals,
      ));
    }

    // 2. If fewer than limit, pull unlearned words from vocabularies
    if (results.length < limit) {
      final remaining = limit - results.length;
      final newWhere = hskLevel != null ? 'AND v.hsk_level = ?' : '';
      final newVocabsQuery = '''
        SELECT v.*, v.id AS vocab_id,
               vs.part_of_speech, vs.meaning_vi, vs.example_cn, vs.example_pinyin, vs.example_vi
        FROM ${DatabaseConstants.tableVocabularies} v
        LEFT JOIN ${DatabaseConstants.tableVocabularySenses} vs ON vs.id = (
          SELECT vs2.id
          FROM ${DatabaseConstants.tableVocabularySenses} vs2
          WHERE vs2.vocabulary_id = v.id AND vs2.deleted_at IS NULL
          ORDER BY COALESCE(vs2.order_index, 999999) ASC, vs2.id ASC
          LIMIT 1
        )
        WHERE v.deleted_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM ${DatabaseConstants.tableSrsItems} s 
            WHERE s.content_id = v.id AND s.deleted_at IS NULL
          )
        $newWhere
        ORDER BY v.frequency_rank ASC
        LIMIT $remaining
      ''';

      final newRows = await _db.rawQuery(
        newVocabsQuery,
        hskLevel != null ? [hskLevel] : [],
      );

      for (final row in newRows) {
        final vocabId = (row['vocab_id'] ?? row['id']) as String;
        final srsState = await getOrCreateCardState(contentId: vocabId);
        final intervals = _engine.previewIntervals(srsState);
        results.add(SrsFlashcardItem.fromDatabaseRow(
          row: {...row, 'id': vocabId},
          srsState: srsState,
          estimatedIntervalDays: intervals,
        ));
      }
    }

    return results;
  }

  /// Records an interactive flashcard review turn, updating SRS state atomically,
  /// logging learner evidence, and logging a learning activity for the home streak engine.
  Future<SrsReviewResult> recordReviewAndProgress({
    required SrsFlashcardItem item,
    required SrsRating rating,
    int durationMs = 0,
    DateTime? reviewTime,
  }) async {
    final result = await processReview(
      contentId: item.id,
      rating: rating,
      durationMs: durationMs,
      reviewTime: reviewTime,
      source: 'srs_flashcard',
      additionalMetadata: {
        'simplified': item.simplified,
        'pinyin': item.pinyin,
        'meaning_vi': item.meaningVi,
        'hsk_level': item.hskLevel,
      },
    );

    try {
      final now = reviewTime?.toUtc() ?? DateTime.now().toUtc();
      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await _db.insert(
        DatabaseConstants.tableLearningActivities,
        {
          'id': 'ACT_${now.microsecondsSinceEpoch}_${item.id}',
          'activity_type': 'srs_review',
          'duration_seconds': (durationMs / 1000).ceil().clamp(1, 300),
          'items_count': 1,
          'activity_date': dateStr,
          'created_at': now.toIso8601String(),
        },
      );
    } catch (_) {
      // Non-critical if table has constraint, review state is already committed atomically
    }

    return result;
  }

  /// Retrieves the number of cards due for review, with in-memory TTL caching
  /// to eliminate redundant SQLite queries on repeated UI widget evaluations.
  /// When [hskLevel] is specified for 'vocabulary', joins with vocabularies table
  /// to count only cards belonging to that specific HSK proficiency level.
  Future<int> getDueCardsCount({
    String contentType = 'vocabulary',
    int? hskLevel,
    DateTime? asOf,
    Duration ttl = const Duration(seconds: 60),
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cacheKey = '$contentType:${hskLevel ?? "all"}';

    // Use cache only when asOf is not explicitly customized and not forceRefresh
    if (asOf == null && !forceRefresh) {
      final cached = _dueCountCache[cacheKey];
      if (cached != null && cached.expiresAt.isAfter(now)) {
        return cached.count;
      }
    }

    final asOfUtc = (asOf ?? now).toUtc().toIso8601String();
    int count = 0;

    if (hskLevel != null && contentType == 'vocabulary') {
      final result = await _db.rawQuery(
        '''
        SELECT COUNT(DISTINCT s.id) as count 
        FROM ${DatabaseConstants.tableSrsItems} s
        INNER JOIN ${DatabaseConstants.tableVocabularies} v ON (s.content_id = v.id OR s.content_id = v.simplified)
        WHERE s.content_type = ? 
          AND s.due_at <= ? 
          AND s.deleted_at IS NULL 
          AND v.deleted_at IS NULL 
          AND v.hsk_level = ?
        ''',
        [contentType, asOfUtc, hskLevel],
      );
      count = (result.first['count'] as num?)?.toInt() ?? 0;
    } else {
      final result = await _db.rawQuery(
        'SELECT COUNT(id) as count FROM ${DatabaseConstants.tableSrsItems} '
        'WHERE content_type = ? AND due_at <= ? AND deleted_at IS NULL',
        [contentType, asOfUtc],
      );
      count = (result.first['count'] as num?)?.toInt() ?? 0;
    }

    if (asOf == null) {
      _dueCountCache[cacheKey] = (
        count: count,
        expiresAt: now.add(ttl),
      );
    }

    return count;
  }

  /// Migrates legacy or alias vocabulary IDs in [srs_items] into canonical vocabulary PKs (Nhiệm vụ C).
  /// Resolves the 4 conventions:
  /// - `voc_hsk1_001` (canonical PK)
  /// - `KNOW_VOCAB_...` (knowledge registry ID)
  /// - Raw Hanzi (e.g. '你好')
  /// - Legacy curriculum format (e.g. 'VOCAB_001_NIHAO')
  ///
  /// If duplicate cards exist for the same word, merges review metrics
  /// (max repetitions, max interval, max ease factor, latest due date),
  /// re-links `learner_evidence` audit logs, and soft-deletes the duplicate card.
  Future<({int migratedCount, int mergedCount})> migrateSrsItemsToCanonical() async {
    int migratedCount = 0;
    int mergedCount = 0;

    final rows = await _db.query(
      DatabaseConstants.tableSrsItems,
      where: "content_type = 'vocabulary' AND deleted_at IS NULL",
    );

    final nowUtc = DateTime.now().toUtc().toIso8601String();

    for (final row in rows) {
      final oldSrsId = row['id'] as String;
      final oldContentId = row['content_id'] as String;

      final canonicalId = await _identityRegistry.toCanonicalVocabularyId(oldContentId);
      if (canonicalId == null || canonicalId == oldContentId) {
        continue;
      }

      await _db.transaction((txn) async {
        // Check if a card already exists with content_id = canonicalId
        final existingCanonicalRows = await txn.query(
          DatabaseConstants.tableSrsItems,
          where: "content_id = ? AND content_type = 'vocabulary' AND deleted_at IS NULL",
          whereArgs: [canonicalId],
          limit: 1,
        );

        if (existingCanonicalRows.isEmpty) {
          // No duplicate card exists: promote current card to canonical ID
          final newSrsId = 'SRS_VOCABULARY_$canonicalId';
          await txn.update(
            DatabaseConstants.tableSrsItems,
            {
              'id': newSrsId,
              'content_id': canonicalId,
              'updated_at': nowUtc,
            },
            where: 'id = ?',
            whereArgs: [oldSrsId],
          );

          // Update learner_evidence references
          await txn.update(
            DatabaseConstants.tableLearnerEvidence,
            {
              'srs_item_id': newSrsId,
              'content_id': canonicalId,
            },
            where: 'srs_item_id = ? OR content_id = ?',
            whereArgs: [oldSrsId, oldContentId],
          );

          migratedCount++;
        } else {
          // A canonical card ALREADY exists! Merge progress to preserve user's learning state.
          final canonicalRow = existingCanonicalRows.first;
          final canonicalSrsId = canonicalRow['id'] as String;

          final oldReps = (row['repetitions'] as num?)?.toInt() ?? 0;
          final canonReps = (canonicalRow['repetitions'] as num?)?.toInt() ?? 0;
          final mergedReps = oldReps > canonReps ? oldReps : canonReps;

          final oldInterval = (row['interval_days'] as num?)?.toInt() ?? 0;
          final canonInterval = (canonicalRow['interval_days'] as num?)?.toInt() ?? 0;
          final mergedInterval = oldInterval > canonInterval ? oldInterval : canonInterval;

          final oldEase = (row['ease_factor'] as num?)?.toDouble() ?? 2.5;
          final canonEase = (canonicalRow['ease_factor'] as num?)?.toDouble() ?? 2.5;
          final mergedEase = oldEase > canonEase ? oldEase : canonEase;

          final oldDue = DateTime.parse(row['due_at'] as String);
          final canonDue = DateTime.parse(canonicalRow['due_at'] as String);
          final mergedDue = oldDue.isAfter(canonDue) ? oldDue : canonDue;

          // Update canonical card with merged metrics
          await txn.update(
            DatabaseConstants.tableSrsItems,
            {
              'repetitions': mergedReps,
              'interval_days': mergedInterval,
              'ease_factor': mergedEase,
              'due_at': mergedDue.toUtc().toIso8601String(),
              'updated_at': nowUtc,
            },
            where: 'id = ?',
            whereArgs: [canonicalSrsId],
          );

          // Re-link evidence from duplicate card to canonical card
          await txn.update(
            DatabaseConstants.tableLearnerEvidence,
            {
              'srs_item_id': canonicalSrsId,
              'content_id': canonicalId,
            },
            where: 'srs_item_id = ? OR content_id = ?',
            whereArgs: [oldSrsId, oldContentId],
          );

          // Soft-delete duplicate card
          await txn.update(
            DatabaseConstants.tableSrsItems,
            {
              'deleted_at': nowUtc,
              'updated_at': nowUtc,
            },
            where: 'id = ?',
            whereArgs: [oldSrsId],
          );

          mergedCount++;
        }
      });
    }

    return (migratedCount: migratedCount, mergedCount: mergedCount);
  }

  /// Clears in-memory debounce, in-flight, and due count caches.
  void clearCache() {
    _inFlightContentIds.clear();
    _lastReviewTimes.clear();
    _dueCountCache.clear();
  }
}
