import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class ReadingDao {
  final DatabaseExecutor _db;

  ReadingDao(this._db);

  Future<void> insertPassage(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await executor.insert(
      DatabaseConstants.tableReadingPassages,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  // Reading Progress methods
  Future<void> saveProgress(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await executor.insert(
      DatabaseConstants.tableReadingProgress,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
