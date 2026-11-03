import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class GrammarDao {
  final DatabaseExecutor _db;

  GrammarDao(this._db);

  Future<void> _safeUpsert(
    DatabaseExecutor executor,
    String table,
    Map<String, dynamic> row, {
    String primaryKey = 'id',
  }) async {
    final pkVal = row[primaryKey];
    if (pkVal != null) {
      final existing = await executor.query(
        table,
        columns: [primaryKey],
        where: '$primaryKey = ?',
        whereArgs: [pkVal],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await executor.update(
          table,
          row,
          where: '$primaryKey = ?',
          whereArgs: [pkVal],
        );
        return;
      }
    }
    // Also check code unique constraint
    final codeVal = row['code'];
    if (codeVal != null) {
      final existingByCode = await executor.query(
        table,
        columns: [primaryKey],
        where: 'code = ?',
        whereArgs: [codeVal],
        limit: 1,
      );
      if (existingByCode.isNotEmpty) {
        final existingId = existingByCode.first[primaryKey];
        final updatedRow = Map<String, dynamic>.from(row);
        updatedRow[primaryKey] = existingId;
        await executor.update(
          table,
          updatedRow,
          where: '$primaryKey = ?',
          whereArgs: [existingId],
        );
        return;
      }
    }
    await executor.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> insertGrammar(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await _safeUpsert(executor, DatabaseConstants.tableGrammarItems, row);
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
