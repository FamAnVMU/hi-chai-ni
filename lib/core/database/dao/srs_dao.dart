import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class SrsDao {
  final DatabaseExecutor _db;

  SrsDao(this._db);

  Future<void> _safeUpsert(
    DatabaseExecutor executor,
    String table,
    Map<String, dynamic> item,
  ) async {
    final contentId = item['content_id'];
    final contentType = item['content_type'];
    if (contentId != null && contentType != null) {
      final existing = await executor.query(
        table,
        columns: ['id'],
        where: 'content_id = ? AND content_type = ? AND deleted_at IS NULL',
        whereArgs: [contentId, contentType],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final existingId = existing.first['id'];
        final updatedRow = Map<String, dynamic>.from(item);
        updatedRow['id'] = existingId;
        await executor.update(
          table,
          updatedRow,
          where: 'id = ?',
          whereArgs: [existingId],
        );
        return;
      }
    }
    // Also check primary key 'id'
    final id = item['id'];
    if (id != null) {
      final existingById = await executor.query(
        table,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existingById.isNotEmpty) {
        await executor.update(
          table,
          item,
          where: 'id = ?',
          whereArgs: [id],
        );
        return;
      }
    }
    await executor.insert(table, item, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> upsertSrsItem(Map<String, dynamic> item, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await _safeUpsert(executor, DatabaseConstants.tableSrsItems, item);
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
