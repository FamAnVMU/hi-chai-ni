import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class HistoricalActivityAuditReport {
  final int totalRecords;
  final int recordsWithExplicitTimezone;
  final int unaffectedRecords;
  final int potentiallyShiftedRecords;
  final int indeterminateRecords;
  final List<String> shiftedActivityIds;

  const HistoricalActivityAuditReport({
    required this.totalRecords,
    required this.recordsWithExplicitTimezone,
    required this.unaffectedRecords,
    required this.potentiallyShiftedRecords,
    required this.indeterminateRecords,
    this.shiftedActivityIds = const [],
  });
}

class TimezoneDataMigrator {
  const TimezoneDataMigrator();

  Future<HistoricalActivityAuditReport> auditHistoricalActivities(
    DatabaseExecutor db, {
    Duration assumedOffset = const Duration(hours: 7),
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT id, activity_date, created_at
      FROM ${DatabaseConstants.tableLearningActivities}
      ORDER BY created_at ASC
      ''',
    );

    int total = rows.length;
    int explicit = 0;
    int unaffected = 0;
    int potentiallyShifted = 0;
    int indeterminate = 0;
    final shiftedIds = <String>[];

    final tableInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableLearningActivities});');
    final hasTzCol = tableInfo.any((c) => c['name'] == 'timezone_offset_minutes');

    for (final row in rows) {
      final id = row['id'] as String? ?? '';
      final recordedDate = row['activity_date'] as String? ?? '';
      final createdAtStr = row['created_at'] as String?;
      if (createdAtStr == null) {
        indeterminate++;
        continue;
      }

      final parsedUtc = DateTime.tryParse(createdAtStr)?.toUtc();
      if (parsedUtc == null) {
        indeterminate++;
        continue;
      }

      if (hasTzCol && row['timezone_offset_minutes'] != null) {
        explicit++;
        unaffected++;
        continue;
      }

      final utcDateStr = '${parsedUtc.year.toString().padLeft(4, '0')}-${parsedUtc.month.toString().padLeft(2, '0')}-${parsedUtc.day.toString().padLeft(2, '0')}';
      final localTime = parsedUtc.add(assumedOffset);
      final expectedLocalDateStr = '${localTime.year.toString().padLeft(4, '0')}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}';

      if (expectedLocalDateStr != utcDateStr && recordedDate == utcDateStr) {
        potentiallyShifted++;
        shiftedIds.add(id);
      } else {
        unaffected++;
      }
    }

    return HistoricalActivityAuditReport(
      totalRecords: total,
      recordsWithExplicitTimezone: explicit,
      unaffectedRecords: unaffected,
      potentiallyShiftedRecords: potentiallyShifted,
      indeterminateRecords: indeterminate,
      shiftedActivityIds: shiftedIds,
    );
  }

  Future<int> backfillWithVerifiedTimezone(
    DatabaseExecutor db, {
    required Duration verifiedOffset,
  }) async {
    final audit = await auditHistoricalActivities(db, assumedOffset: verifiedOffset);
    if (audit.shiftedActivityIds.isEmpty) return 0;

    int updatedCount = 0;
    for (final id in audit.shiftedActivityIds) {
      final row = (await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      )).firstOrNull;

      if (row == null) continue;
      final createdAtStr = row['created_at'] as String?;
      if (createdAtStr == null) continue;
      final parsedUtc = DateTime.tryParse(createdAtStr)?.toUtc();
      if (parsedUtc == null) continue;

      final localTime = parsedUtc.add(verifiedOffset);
      final newLocalDateStr = '${localTime.year.toString().padLeft(4, '0')}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}';

      await db.update(
        DatabaseConstants.tableLearningActivities,
        {
          'activity_date': newLocalDateStr,
          'timezone_offset_minutes': verifiedOffset.inMinutes,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      updatedCount++;
    }

    return updatedCount;
  }
}
