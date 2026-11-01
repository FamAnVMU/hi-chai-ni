import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class DictionaryHistoryDao {
  final DatabaseExecutor _db;

  DictionaryHistoryDao(this._db);

  Future<void> insertHistory({
    required String id,
    required String query,
    String searchType = 'text',
    Transaction? txn,
  }) async {
    final executor = txn ?? _db;
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    // Remove older duplicate queries to keep history tidy
    await executor.delete(
      DatabaseConstants.tableDictionaryHistory,
      where: 'query = ?',
      whereArgs: [query.trim()],
    );

    await executor.insert(
      DatabaseConstants.tableDictionaryHistory,
      {
        'id': id,
        'query': query.trim(),
        'search_type': searchType,
        'created_at': nowUtc,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getRecentSearches({int limit = 20}) async {
    return await _db.query(
      DatabaseConstants.tableDictionaryHistory,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<int> deleteHistoryItem(String id) async {
    return await _db.delete(
      DatabaseConstants.tableDictionaryHistory,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAllHistory() async {
    return await _db.delete(DatabaseConstants.tableDictionaryHistory);
  }
}
