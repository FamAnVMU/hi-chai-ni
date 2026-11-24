import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'dao_utils.dart';

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

    await executor.rawInsert('''
      INSERT INTO ${DatabaseConstants.tableUserSavedWords} (
        id, vocabulary_id, simplified, pinyin, custom_note,
        is_favorite, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(vocabulary_id) DO UPDATE SET
        simplified = excluded.simplified,
        pinyin = excluded.pinyin,
        custom_note = COALESCE(excluded.custom_note, ${DatabaseConstants.tableUserSavedWords}.custom_note),
        is_favorite = excluded.is_favorite,
        updated_at = excluded.updated_at
    ''', [
      id,
      vocabularyId,
      simplified,
      pinyin,
      customNote,
      isFavorite ? 1 : 0,
      nowUtc,
      nowUtc,
    ]);
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

  /// Batch fetches saved status for multiple vocabulary IDs in chunked queries (<= 500 args).
  Future<Map<String, Map<String, dynamic>>> getSavedWordsByIds(
    List<String> vocabIds,
  ) async {
    if (vocabIds.isEmpty) return const {};

    final map = <String, Map<String, dynamic>>{};
    for (final chunk in DaoUtils.chunkList(vocabIds)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db.query(
        DatabaseConstants.tableUserSavedWords,
        where: 'vocabulary_id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in rows) {
        map[row['vocabulary_id'] as String] = row;
      }
    }
    return map;
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
