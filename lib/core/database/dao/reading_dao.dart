import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'dao_utils.dart';

class ReadingDao {
  final DatabaseExecutor _db;

  ReadingDao(this._db);

  Future<void> insertPassage(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await DaoUtils.safeUpsert(executor, DatabaseConstants.tableReadingPassages, row);
  }

  Future<Map<String, dynamic>?> getPassageById(String id) async {
    final results = await _db.query(
      DatabaseConstants.tableReadingPassages,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllPassages() async {
    return await _db.query(
      DatabaseConstants.tableReadingPassages,
      where: 'deleted_at IS NULL',
      orderBy: 'hsk_level ASC, id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getPassagesByHsk(int hskLevel) async {
    return await _db.query(
      DatabaseConstants.tableReadingPassages,
      where: 'hsk_level = ? AND deleted_at IS NULL',
      whereArgs: [hskLevel],
      orderBy: 'id ASC',
    );
  }

  Future<int> countPassages() async {
    final res = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableReadingPassages} WHERE deleted_at IS NULL',
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // Reading Progress methods
  Future<void> saveProgress(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    if (row['passage_id'] != null) {
      await DaoUtils.safeUpsert(
        executor,
        DatabaseConstants.tableReadingProgress,
        row,
        conflictKey: 'passage_id',
        preservePrimaryKey: true,
      );
      return;
    }
    await DaoUtils.safeUpsert(executor, DatabaseConstants.tableReadingProgress, row);
  }

  Future<Map<String, dynamic>?> getProgressByPassageId(String passageId) async {
    final results = await _db.query(
      DatabaseConstants.tableReadingProgress,
      where: 'passage_id = ?',
      whereArgs: [passageId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllProgress() async {
    return await _db.query(
      DatabaseConstants.tableReadingProgress,
      orderBy: 'updated_at DESC',
    );
  }

  Future<int> deleteProgress(String passageId, {Transaction? txn}) async {
    final executor = txn ?? _db;
    return await executor.delete(
      DatabaseConstants.tableReadingProgress,
      where: 'passage_id = ?',
      whereArgs: [passageId],
    );
  }
}
