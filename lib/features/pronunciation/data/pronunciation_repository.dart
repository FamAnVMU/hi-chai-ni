import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../../../core/utils/app_clock.dart';
import '../domain/models/pronunciation_models.dart';

/// Repository managing persistence of Pronunciation Lab attempts and audio lifecycle.
class PronunciationRepository {
  final Database _db;

  PronunciationRepository(this._db);

  /// Atomically records a pronunciation attempt to learner_evidence and learning_activities.
  Future<String> recordPronunciationSession({
    required PronunciationAssessmentResult assessment,
    DateTime? timestamp,
    Duration? timeZoneOffset,
  }) async {
    final now = timestamp ?? AppClock.now();
    final nowUtc = now.toUtc();
    final offset = timeZoneOffset ?? AppClock.currentOffset;
    final dateStr = AppClock.toLocalDateString(now, timeZoneOffset: offset);

    final evidenceId = 'EVI_PRON_${nowUtc.microsecondsSinceEpoch}_${assessment.targetId}';

    await _db.transaction((txn) async {
      // 1. Immutable audit record in learner_evidence
      // Only insert into learner_evidence if the attempt was actually evaluated/scored,
      // avoiding recording 0.0 scores when ASR is unsupported/offline (T6-F07).
      if (assessment.overallScore != null &&
          assessment.status != PronunciationEvaluationStatus.unsupported) {
        await txn.insert(
          DatabaseConstants.tableLearnerEvidence,
          {
            'id': evidenceId,
            'srs_item_id': null,
            'content_id': assessment.targetId,
            'content_type': 'pronunciation',
            'source': 'pronunciation_lab',
            'score': assessment.overallScore!,
            'duration_ms': assessment.recordedDurationMs,
            'metadata_json': json.encode(assessment.toMap()),
            'created_at': nowUtc.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 2. Aggregate activity log to feed daily streak
      final durationSec = (assessment.recordedDurationMs / 1000).ceil();
      await txn.insert(
        DatabaseConstants.tableLearningActivities,
        {
          'id': 'ACT_PRON_${nowUtc.microsecondsSinceEpoch}',
          'activity_type': 'pronunciation',
          'duration_seconds': durationSec > 0 ? durationSec : 1,
          'items_count': 1,
          'activity_date': dateStr,
          'created_at': nowUtc.toIso8601String(),
          'timezone_offset_minutes': offset.inMinutes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return evidenceId;
  }

  /// Deletes user recording file from local storage.
  /// If [retainEvidence] is true, the aggregated score & feedback in learner_evidence
  /// remain preserved with the audio path marked null/deleted.
  Future<void> deleteRecordingAudio({
    required String audioPath,
    required String? evidenceId,
    bool retainEvidence = true,
  }) async {
    // 1. Delete physical file from filesystem
    try {
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Non-fatal if already deleted
    }

    // 2. Handle database evidence
    if (evidenceId != null) {
      if (retainEvidence) {
        // Read existing metadata and update
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
          metadata['audio_local_path'] = null;

          await _db.update(
            DatabaseConstants.tableLearnerEvidence,
            {'metadata_json': json.encode(metadata)},
            where: 'id = ?',
            whereArgs: [evidenceId],
          );
        }
      } else {
        // Purge evidence entirely
        await _db.delete(
          DatabaseConstants.tableLearnerEvidence,
          where: 'id = ?',
          whereArgs: [evidenceId],
        );
      }
    }
  }

  /// Fetches recent pronunciation practice attempts.
  Future<List<Map<String, dynamic>>> getRecentPronunciationSessions({
    String? targetId,
    int limit = 10,
  }) async {
    final where = targetId != null ? 'source = ? AND content_id = ?' : 'source = ?';
    final args = targetId != null ? ['pronunciation_lab', targetId] : ['pronunciation_lab'];

    return await _db.query(
      DatabaseConstants.tableLearnerEvidence,
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
}
