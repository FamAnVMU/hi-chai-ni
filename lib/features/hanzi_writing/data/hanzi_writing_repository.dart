import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../../../core/utils/app_clock.dart';
import '../domain/models/stroke_models.dart';

/// Repository managing persistence of Hanzi handwriting sessions and learner evidence.
class HanziWritingRepository {
  static int _writeSeq = 0;

  final Database _db;

  HanziWritingRepository(this._db);

  /// Records a completed writing attempt atomically into learner_evidence,
  /// learning_activities, and hanzi_writing_progress without bloated raw bitmaps.
  Future<void> recordWritingSession({
    required String character,
    required WritingEvaluationResult evaluation,
    int durationMs = 0,
    DateTime? timestamp,
    Duration? timeZoneOffset,
  }) async {
    final now = timestamp ?? AppClock.now();
    final nowUtc = now.toUtc();
    final offset = timeZoneOffset ?? AppClock.currentOffset;
    final dateStr = AppClock.toLocalDateString(now, timeZoneOffset: offset);
    final seq = ++_writeSeq;

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
      final evidenceId = 'EVI_WRITE_${nowUtc.microsecondsSinceEpoch}_${seq}_$character';
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
      final activityId = 'ACT_WRITE_${nowUtc.microsecondsSinceEpoch}_${seq}_$character';
      await txn.insert(
        DatabaseConstants.tableLearningActivities,
        {
          'id': activityId,
          'activity_type': 'hanzi_writing',
          'duration_seconds': (durationMs / 1000).ceil().clamp(1, 600),
          'items_count': 1,
          'activity_date': dateStr,
          'created_at': nowUtc.toIso8601String(),
          'timezone_offset_minutes': offset.inMinutes,
        },
      );

      // 3. Synchronize mastery progress in hanzi_writing_progress
      try {
        final existingRows = await txn.query(
          DatabaseConstants.tableHanziWritingProgress,
          where: 'character = ?',
          whereArgs: [character],
          limit: 1,
        );
        final existing = existingRows.isNotEmpty ? existingRows.first : null;

        int hskLevel = (existing?['hsk_level'] as num?)?.toInt() ?? 1;
        if (existing == null) {
          final charRows = await txn.query(
            DatabaseConstants.tableHanziCharacters,
            columns: ['hsk_level'],
            where: 'character = ?',
            whereArgs: [character],
            limit: 1,
          );
          if (charRows.isNotEmpty) {
            hskLevel = (charRows.first['hsk_level'] as num?)?.toInt() ?? 1;
          }
        }

        final isTestMode = !evaluation.isTracingMode;
        final prevPractice = (existing?['practice_count'] as num?)?.toInt() ?? 0;
        final prevTest = (existing?['test_count'] as num?)?.toInt() ?? 0;
        final prevBest = (existing?['best_accuracy_score'] as num?)?.toDouble() ?? 0.0;
        final prevMistakes = (existing?['mistakes_count'] as num?)?.toInt() ?? 0;
        final prevOrderErrors = (existing?['stroke_order_errors'] as num?)?.toInt() ?? 0;

        final accuracyPct = (evaluation.strokeOrderAccuracy * 100.0).clamp(0.0, 100.0);
        final mistakes = evaluation.hasStandardStrokeData
            ? (evaluation.totalStandardStrokes - evaluation.correctStrokeCount)
                .clamp(0, 999)
            : 0;
        final newBest = accuracyPct > prevBest ? accuracyPct : prevBest;

        String masteryLevel = existing?['mastery_level'] as String? ?? 'learning';
        DateTime srsDue = nowUtc.add(const Duration(days: 1));
        if (accuracyPct >= 90.0 && mistakes == 0 && evaluation.hasStandardStrokeData) {
          masteryLevel = 'mastered';
          srsDue = nowUtc.add(const Duration(days: 4));
        } else if (accuracyPct >= 75.0) {
          masteryLevel = masteryLevel == 'mastered' ? 'mastered' : 'practiced';
          srsDue = nowUtc.add(const Duration(days: 2));
        } else if (masteryLevel != 'mastered') {
          masteryLevel = 'learning';
          srsDue = nowUtc.add(const Duration(hours: 6));
        }

        await txn.insert(
          DatabaseConstants.tableHanziWritingProgress,
          {
            'id': existing?['id'] as String? ?? 'progress_$character',
            'character': character,
            'hsk_level': hskLevel,
            'practice_count': isTestMode ? prevPractice : prevPractice + 1,
            'test_count': isTestMode ? prevTest + 1 : prevTest,
            'last_accuracy_score': accuracyPct,
            'best_accuracy_score': newBest,
            'mistakes_count': prevMistakes + mistakes,
            'stroke_order_errors': prevOrderErrors + mistakes,
            'last_practiced_at': nowUtc.toIso8601String(),
            'mastery_level': masteryLevel,
            'is_favorite': (existing?['is_favorite'] as num?)?.toInt() ?? 0,
            'srs_due_date': srsDue.toIso8601String(),
            'updated_at': nowUtc.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
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
