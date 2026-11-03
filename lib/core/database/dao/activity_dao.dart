import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class ActivityDao {
  final DatabaseExecutor _db;

  ActivityDao(this._db);

  Future<void> logActivity(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await executor.insert(
      DatabaseConstants.tableLearningActivities,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getActivitiesForDate(String yyyyMmDd) async {
    return await _db.query(
      DatabaseConstants.tableLearningActivities,
      where: 'activity_date = ?',
      whereArgs: [yyyyMmDd],
      orderBy: 'created_at ASC',
    );
  }

  Future<int> getTotalStudyDurationSeconds(String yyyyMmDd) async {
    final result = await _db.rawQuery(
      'SELECT SUM(duration_seconds) as total FROM ${DatabaseConstants.tableLearningActivities} WHERE activity_date = ?',
      [yyyyMmDd],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<String>> getDistinctActiveDates() async {
    final result = await _db.rawQuery(
      'SELECT DISTINCT activity_date FROM ${DatabaseConstants.tableLearningActivities} '
      'WHERE activity_type NOT IN (\'sample_data\', \'seed\') '
      'AND (duration_seconds >= 30 OR items_count >= 1) '
      'ORDER BY activity_date ASC',
    );
    return result
        .map((r) => r['activity_date'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> getActivitiesForDateRange(String startYyyyMmDd, String endYyyyMmDd) async {
    return await _db.query(
      DatabaseConstants.tableLearningActivities,
      where: 'activity_date >= ? AND activity_date <= ?',
      whereArgs: [startYyyyMmDd, endYyyyMmDd],
      orderBy: 'activity_date ASC, created_at ASC',
    );
  }
}
