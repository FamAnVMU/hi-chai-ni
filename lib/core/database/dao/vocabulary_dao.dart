import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class VocabularyDao {
  final DatabaseExecutor _db;

  VocabularyDao(this._db);

  Future<void> insertVocabulary(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await executor.insert(
      DatabaseConstants.tableVocabularies,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertSense(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await executor.insert(
      DatabaseConstants.tableVocabularySenses,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getVocabularyById(String id) async {
    final results = await _db.query(
      DatabaseConstants.tableVocabularies,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getVocabularyWithSenses(String id) async {
    final vocab = await getVocabularyById(id);
    if (vocab == null) return null;
    final senses = await getSensesByVocabularyId(id);
    final result = Map<String, dynamic>.from(vocab);
    result['senses'] = senses;
    return result;
  }

  Future<List<Map<String, dynamic>>> getSensesByVocabularyId(String vocabId) async {
    return await _db.query(
      DatabaseConstants.tableVocabularySenses,
      where: 'vocabulary_id = ? AND deleted_at IS NULL',
      whereArgs: [vocabId],
    );
  }

  Future<List<Map<String, dynamic>>> getVocabulariesByHsk(int hskLevel, {int limit = 50, int offset = 0}) async {
    return await _db.query(
      DatabaseConstants.tableVocabularies,
      where: 'hsk_level = ? AND deleted_at IS NULL',
      whereArgs: [hskLevel],
      orderBy: 'frequency_rank ASC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> searchVocabularies(String keyword, {int limit = 20}) async {
    final pattern = '%$keyword%';
    return await _db.query(
      DatabaseConstants.tableVocabularies,
      where: '(simplified LIKE ? OR pinyin LIKE ?) AND deleted_at IS NULL',
      whereArgs: [pattern, pattern],
      limit: limit,
    );
  }

  Future<int> softDeleteVocabulary(String id, {Transaction? txn}) async {
    final executor = txn ?? _db;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    return await executor.update(
      DatabaseConstants.tableVocabularies,
      {'deleted_at': nowUtc, 'updated_at': nowUtc},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
