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
}
