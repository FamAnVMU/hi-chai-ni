import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
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
    this.debounceCooldownMs = 800,
  }) : _engine = engine ?? const Sm2Engine();

  Sm2Engine get engine => _engine;

  /// Retrieves an existing [SrsCardState] from the database or creates an initial new state.
  Future<SrsCardState> getOrCreateCardState({
    required String contentId,
    String contentType = 'vocabulary',
  }) async {
    final rows = await _db.query(
      DatabaseConstants.tableSrsItems,
      where: 'content_id = ? AND content_type = ? AND deleted_at IS NULL',
      whereArgs: [contentId, contentType],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return SrsCardState.fromMap(rows.first);
    }

    final newCard = SrsCardState.newCard(
      id: 'SRS_${contentType.toUpperCase()}_$contentId',
      contentId: contentId,
      contentType: contentType,
      initialEaseFactor: _engine.config.initialEaseFactor,
    );

    await _db.insert(
      DatabaseConstants.tableSrsItems,
      newCard.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
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
    final lockKey = '${contentType}_$contentId';
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
        contentId: contentId,
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
        final evidenceId = 'EVI_${DateTime.now().microsecondsSinceEpoch}_$contentId';
        final metadata = {
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
            'content_id': contentId,
            'content_type': contentType,
            'source': source,
            'score': reviewResult.isSuccessful ? 1.0 : 0.0,
            'duration_ms': durationMs,
            'metadata_json': json.encode(metadata),
            'created_at': nowUtc.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.abort, // Guarantees append-only integrity
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

  /// Retrieves the number of cards due for review, with in-memory TTL caching
  /// to eliminate redundant SQLite queries on repeated UI widget evaluations.
  Future<int> getDueCardsCount({
    String contentType = 'vocabulary',
    DateTime? asOf,
    Duration ttl = const Duration(seconds: 60),
  }) async {
    final now = DateTime.now();
    final cacheKey = contentType;

    // Use cache only when asOf is not explicitly customized
    if (asOf == null) {
      final cached = _dueCountCache[cacheKey];
      if (cached != null && cached.expiresAt.isAfter(now)) {
        return cached.count;
      }
    }

    final asOfUtc = (asOf ?? now).toUtc().toIso8601String();
    final result = await _db.rawQuery(
      'SELECT COUNT(id) as count FROM ${DatabaseConstants.tableSrsItems} '
      'WHERE content_type = ? AND due_at <= ? AND deleted_at IS NULL',
      [contentType, asOfUtc],
    );

    final count = (result.first['count'] as num?)?.toInt() ?? 0;

    if (asOf == null) {
      _dueCountCache[cacheKey] = (
        count: count,
        expiresAt: now.add(ttl),
      );
    }

    return count;
  }

  /// Clears in-memory debounce, in-flight, and due count caches.
  void clearCache() {
    _inFlightContentIds.clear();
    _lastReviewTimes.clear();
    _dueCountCache.clear();
  }
}
