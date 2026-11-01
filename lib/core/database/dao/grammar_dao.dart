import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class GrammarDao {
  final DatabaseExecutor _db;

  GrammarDao(this._db);

  Future<void> insertGrammar(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await executor.insert(
      DatabaseConstants.tableGrammarItems,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getGrammarById(String id) async {
    final results = await _db.query(
      DatabaseConstants.tableGrammarItems,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getGrammarByHsk(int hskLevel) async {
    return await _db.query(
      DatabaseConstants.tableGrammarItems,
      where: 'hsk_level = ? AND deleted_at IS NULL',
      whereArgs: [hskLevel],
      orderBy: 'code ASC',
    );
  }
}
