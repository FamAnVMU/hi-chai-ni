import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../domain/models/stroke_models.dart';

/// Repository managing persistence of Hanzi handwriting sessions and learner evidence.
class HanziWritingRepository {
  final Database _db;

  HanziWritingRepository(this._db);

  /// Records a completed writing attempt atomically into learner_evidence
  /// and learning_activities without polluting SQLite with bloated raw bitmaps.
  Future<void> recordWritingSession({
    required String character,
    required WritingEvaluationResult evaluation,
    int durationMs = 0,
    DateTime? timestamp,
  }) async {
    final nowUtc = (timestamp ?? DateTime.now()).toUtc();
    final dateStr =
        '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}';

    final metadata = {
      'character': character,
      'is_tracing_mode': evaluation.isTracingMode,
      'stroke_accuracy': evaluation.strokeOrderAccuracy,
      'score_percent': evaluation.scorePercent,
      'user_strokes_count': evaluation.userDrawnStrokesCount,
      'correct_strokes_count': evaluation.correctStrokeCount,
      'total_standard_strokes': evaluation.totalStandardStrokes,
      'has_standard_data': evaluation.hasStandardStrokeData,
      'feedback': evaluation.strokeFeedbackList,
    };

    await _db.transaction((txn) async {
      // 1. Immutable audit record in learner_evidence
      final evidenceId = 'EVI_WRITE_${nowUtc.microsecondsSinceEpoch}_$character';
      await txn.insert(
        DatabaseConstants.tableLearnerEvidence,
        {
          'id': evidenceId,
          'srs_item_id': null,
          'content_id': character,
          'content_type': 'hanzi',
          'source': 'hanzi_writing',
          'score': evaluation.strokeOrderAccuracy,
          'duration_ms': durationMs,
          'metadata_json': json.encode(metadata),
          'created_at': nowUtc.toIso8601String(),
        },
      );

      // 2. Activity record for Home Screen streak calculation
      final activityId = 'ACT_WRITE_${nowUtc.microsecondsSinceEpoch}_$character';
      await txn.insert(
        DatabaseConstants.tableLearningActivities,
        {
          'id': activityId,
          'activity_type': 'hanzi_writing',
          'duration_seconds': (durationMs / 1000).ceil().clamp(1, 600),
          'items_count': 1,
          'activity_date': dateStr,
          'created_at': nowUtc.toIso8601String(),
        },
      );
    });
  }

  /// Retrieves recent writing practice sessions for a given character or overall.
  Future<List<Map<String, dynamic>>> getRecentWritingSessions({
    String? character,
    int limit = 20,
  }) async {
    final where = character != null
        ? 'source = ? AND content_id = ?'
        : 'source = ?';
    final args = character != null
        ? ['hanzi_writing', character]
        : ['hanzi_writing'];

    return await _db.query(
      DatabaseConstants.tableLearnerEvidence,
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
}
