import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class SrsDao {
  final DatabaseExecutor _db;

  SrsDao(this._db);

  Future<void> upsertSrsItem(Map<String, dynamic> item, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await executor.insert(
      DatabaseConstants.tableSrsItems,
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getSrsItemByContent(String contentId, String contentType) async {
    final results = await _db.query(
      DatabaseConstants.tableSrsItems,
      where: 'content_id = ? AND content_type = ? AND deleted_at IS NULL',
      whereArgs: [contentId, contentType],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getDueItems({required String beforeUtcTime, int limit = 50}) async {
    return await _db.query(
      DatabaseConstants.tableSrsItems,
      where: 'due_at <= ? AND deleted_at IS NULL',
      whereArgs: [beforeUtcTime],
      orderBy: 'due_at ASC',
      limit: limit,
    );
  }

  Future<int> updateReviewResult({
    required String id,
    required String state,
    required int intervalDays,
    required double easeFactor,
    required int repetitions,
    required int lapses,
    required String dueAt,
    required String lastReviewedAt,
    Transaction? txn,
  }) async {
    final executor = txn ?? _db;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    return await executor.update(
      DatabaseConstants.tableSrsItems,
      {
        'state': state,
        'interval_days': intervalDays,
        'ease_factor': easeFactor,
        'repetitions': repetitions,
        'lapses': lapses,
        'due_at': dueAt,
        'last_reviewed_at': lastReviewedAt,
        'updated_at': nowUtc,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
