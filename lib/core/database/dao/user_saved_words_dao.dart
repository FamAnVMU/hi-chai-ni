import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class UserSavedWordsDao {
  final DatabaseExecutor _db;

  UserSavedWordsDao(this._db);

  Future<void> saveWord({
    required String id,
    required String vocabularyId,
    required String simplified,
    required String pinyin,
    String? customNote,
    bool isFavorite = true,
    Transaction? txn,
  }) async {
    final executor = txn ?? _db;
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    await executor.insert(
      DatabaseConstants.tableUserSavedWords,
      {
        'id': id,
        'vocabulary_id': vocabularyId,
        'simplified': simplified,
        'pinyin': pinyin,
        'custom_note': customNote,
        'is_favorite': isFavorite ? 1 : 0,
        'created_at': nowUtc,
        'updated_at': nowUtc,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> removeSavedWord(String vocabularyId, {Transaction? txn}) async {
    final executor = txn ?? _db;
    return await executor.delete(
      DatabaseConstants.tableUserSavedWords,
      where: 'vocabulary_id = ?',
      whereArgs: [vocabularyId],
    );
  }

  Future<int> updateCustomNote(String vocabularyId, String? note, {Transaction? txn}) async {
    final executor = txn ?? _db;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    return await executor.update(
      DatabaseConstants.tableUserSavedWords,
      {
        'custom_note': note,
        'updated_at': nowUtc,
      },
      where: 'vocabulary_id = ?',
      whereArgs: [vocabularyId],
    );
  }

  Future<bool> isWordSaved(String vocabularyId) async {
    final result = await _db.query(
      DatabaseConstants.tableUserSavedWords,
      columns: ['id'],
      where: 'vocabulary_id = ? AND is_favorite = 1',
      whereArgs: [vocabularyId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getSavedWord(String vocabularyId) async {
    final result = await _db.query(
      DatabaseConstants.tableUserSavedWords,
      where: 'vocabulary_id = ?',
      whereArgs: [vocabularyId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getSavedWords({bool? onlyFavorites = true}) async {
    String? whereClause;
    List<dynamic>? whereArgs;

    if (onlyFavorites == true) {
      whereClause = 'is_favorite = 1';
    }

    return await _db.query(
      DatabaseConstants.tableUserSavedWords,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );
  }
}
