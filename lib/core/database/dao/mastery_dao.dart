import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class MasteryDao {
  final DatabaseExecutor _db;

  const MasteryDao(this._db);

  Future<void> _safeUpsert(
    DatabaseExecutor executor,
    String table,
    Map<String, dynamic> row, {
    String uniqueKey = 'item_id',
  }) async {
    final keyVal = row[uniqueKey];
    if (keyVal != null) {
      final existing = await executor.query(
        table,
        columns: ['id', uniqueKey],
        where: '$uniqueKey = ?',
        whereArgs: [keyVal],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final existingId = existing.first['id'];
        final updatedRow = Map<String, dynamic>.from(row);
        updatedRow['id'] = existingId;
        await executor.update(
          table,
          updatedRow,
          where: '$uniqueKey = ?',
          whereArgs: [keyVal],
        );
        return;
      }
    }
    await executor.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> upsertMastery(Map<String, dynamic> row) async {
    await _safeUpsert(_db, DatabaseConstants.tableCurriculumMastery, row);
  }

  Future<Map<String, dynamic>?> getMastery(String itemId) async {
    final results = await _db.query(
      DatabaseConstants.tableCurriculumMastery,
      where: 'item_id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getMasteryRecordsByType(String itemType) async {
    return _db.query(
      DatabaseConstants.tableCurriculumMastery,
      where: 'item_type = ?',
      whereArgs: [itemType],
    );
  }

  Future<List<Map<String, dynamic>>> getItemsNeedingReview(DateTime nowUtc) async {
    return _db.query(
      DatabaseConstants.tableCurriculumMastery,
      where: 'due_review_at IS NOT NULL AND due_review_at <= ?',
      whereArgs: [nowUtc.toIso8601String()],
      orderBy: 'due_review_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getWeakKnowledgeItems({double scoreThreshold = 0.7}) async {
    return _db.query(
      DatabaseConstants.tableCurriculumMastery,
      where: 'score < ? AND mastery_state != ?',
      whereArgs: [scoreThreshold, 'not_started'],
      orderBy: 'score ASC',
    );
  }
}
