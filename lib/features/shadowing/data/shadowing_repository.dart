import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../domain/models/shadowing_models.dart';

/// Repository managing persistence of Shadowing practice sessions and audio cleanup.
class ShadowingRepository {
  final Database _db;

  ShadowingRepository(this._db);

  /// Atomically records a Shadowing attempt to learner_evidence and learning_activities.
  Future<String> recordShadowingSession({
    required ShadowingAssessmentResult assessment,
    DateTime? timestamp,
  }) async {
    final nowUtc = (timestamp ?? DateTime.now()).toUtc();
    final dateStr =
        '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}';

    final evidenceId = 'EVI_SHADOW_${nowUtc.microsecondsSinceEpoch}_${assessment.segmentId}';

    await _db.transaction((txn) async {
      // 1. Immutable audit record in learner_evidence
      await txn.insert(
        DatabaseConstants.tableLearnerEvidence,
        {
          'id': evidenceId,
          'srs_item_id': null,
          'content_id': assessment.segmentId,
          'content_type': 'shadowing',
          'source': 'shadowing',
          'score': assessment.fluencyIndex,
          'duration_ms': assessment.userDurationMs,
          'metadata_json': json.encode(assessment.toMap()),
          'created_at': nowUtc.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Aggregate activity log to feed daily streak
      final durationSec = (assessment.userDurationMs / 1000).ceil();
      await txn.insert(
        DatabaseConstants.tableLearningActivities,
        {
          'id': 'ACT_SHADOW_${nowUtc.microsecondsSinceEpoch}',
          'activity_type': 'shadowing',
          'duration_seconds': durationSec > 0 ? durationSec : 1,
          'items_count': 1,
          'activity_date': dateStr,
          'created_at': nowUtc.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return evidenceId;
  }

  /// Deletes user recording file from local storage.
  /// If [retainEvidence] is true, aggregated stats in learner_evidence are preserved.
  Future<void> deleteRecordingAudio({
    required String audioPath,
    required String? evidenceId,
    bool retainEvidence = true,
  }) async {
    // 1. Physical file deletion
    try {
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    // 2. Evidence row handling
    if (evidenceId != null) {
      if (retainEvidence) {
        final rows = await _db.query(
          DatabaseConstants.tableLearnerEvidence,
          where: 'id = ?',
          whereArgs: [evidenceId],
        );

        if (rows.isNotEmpty) {
          final existing = rows.first;
          Map<String, dynamic> metadata = {};
          if (existing['metadata_json'] != null) {
            try {
              metadata = json.decode(existing['metadata_json'] as String) as Map<String, dynamic>;
            } catch (_) {}
          }

          metadata['audio_deleted'] = true;
          metadata['user_audio_path'] = null;

          await _db.update(
            DatabaseConstants.tableLearnerEvidence,
            {'metadata_json': json.encode(metadata)},
            where: 'id = ?',
            whereArgs: [evidenceId],
          );
        }
      } else {
        await _db.delete(
          DatabaseConstants.tableLearnerEvidence,
          where: 'id = ?',
          whereArgs: [evidenceId],
        );
      }
    }
  }

  /// Fetches recent Shadowing sessions.
  Future<List<Map<String, dynamic>>> getRecentShadowingSessions({
    String? segmentId,
    int limit = 10,
  }) async {
    final where = segmentId != null ? 'source = ? AND content_id = ?' : 'source = ?';
    final args = segmentId != null ? ['shadowing', segmentId] : ['shadowing'];

    return await _db.query(
      DatabaseConstants.tableLearnerEvidence,
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
}
