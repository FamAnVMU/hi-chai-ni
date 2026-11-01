import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

/// Append-only DAO for recording immutable learning events and assessment history.
class LearnerEvidenceDao {
  final DatabaseExecutor _db;

  LearnerEvidenceDao(this._db);

  /// Appends a new learning evidence entry. Never updates or overwrites existing records.
  Future<void> appendEvidence(Map<String, dynamic> evidence, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await executor.insert(
      DatabaseConstants.tableLearnerEvidence,
      evidence,
      conflictAlgorithm: ConflictAlgorithm.abort, // Guarantees append-only integrity
    );
  }

  Future<List<Map<String, dynamic>>> getEvidenceByContent(
    String contentId,
    String contentType, {
    int limit = 20,
  }) async {
    return await _db.query(
      DatabaseConstants.tableLearnerEvidence,
      where: 'content_id = ? AND content_type = ?',
      whereArgs: [contentId, contentType],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getRecentEvidence({int limit = 50}) async {
    return await _db.query(
      DatabaseConstants.tableLearnerEvidence,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<int> countEvidenceByDateRange(String startUtc, String endUtc) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableLearnerEvidence} WHERE created_at >= ? AND created_at <= ?',
      [startUtc, endUtc],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
