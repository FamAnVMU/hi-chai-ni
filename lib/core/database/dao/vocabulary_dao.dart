import 'package:sqflite/sqflite.dart';
import '../../../features/dictionary/domain/utils/pinyin_helper.dart';
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
    return searchVocabulariesAdvanced(keyword, limit: limit);
  }

  /// Advanced multi-mode search:
  /// 1. Chinese characters (Exact & Prefix match on simplified / traditional)
  /// 2. Pinyin (Exact & Prefix match with or without tones, numbers)
  /// 3. Vietnamese meanings in senses
  /// Returns deduplicated results ranked by relevance.
  Future<List<Map<String, dynamic>>> searchVocabulariesAdvanced(
    String query, {
    int limit = 30,
    String? normalizedPinyin,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final Map<String, Map<String, dynamic>> resultMap = {};
    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(trimmed);

    if (isChinese) {
      // 1. Exact match Hanzi
      final exact = await _db.query(
        DatabaseConstants.tableVocabularies,
        where: '(simplified = ? OR traditional = ?) AND deleted_at IS NULL',
        whereArgs: [trimmed, trimmed],
      );
      for (final row in exact) {
        resultMap[row['id'] as String] = row;
      }

      // 2. Prefix match Hanzi
      if (resultMap.length < limit) {
        final prefix = await _db.query(
          DatabaseConstants.tableVocabularies,
          where: '(simplified LIKE ? OR traditional LIKE ?) AND deleted_at IS NULL',
          whereArgs: ['$trimmed%', '$trimmed%'],
          limit: limit - resultMap.length,
        );
        for (final row in prefix) {
          resultMap.putIfAbsent(row['id'] as String, () => row);
        }
      }

      // 3. Substring match Hanzi
      if (resultMap.length < limit) {
        final sub = await _db.query(
          DatabaseConstants.tableVocabularies,
          where: '(simplified LIKE ? OR traditional LIKE ?) AND deleted_at IS NULL',
          whereArgs: ['%$trimmed%', '%$trimmed%'],
          limit: limit - resultMap.length,
        );
        for (final row in sub) {
          resultMap.putIfAbsent(row['id'] as String, () => row);
        }
      }
    } else {
      // Input is Pinyin or Vietnamese text
      // 1. Exact Pinyin match
      final exactPinyin = await _db.query(
        DatabaseConstants.tableVocabularies,
        where: 'LOWER(pinyin) = ? AND deleted_at IS NULL',
        whereArgs: [trimmed.toLowerCase()],
      );
      for (final row in exactPinyin) {
        resultMap[row['id'] as String] = row;
      }

      // 2. Prefix Pinyin match
      if (resultMap.length < limit) {
        final prefixPinyin = await _db.query(
          DatabaseConstants.tableVocabularies,
          where: 'LOWER(pinyin) LIKE ? AND deleted_at IS NULL',
          whereArgs: ['${trimmed.toLowerCase()}%'],
          limit: limit - resultMap.length,
        );
        for (final row in prefixPinyin) {
          resultMap.putIfAbsent(row['id'] as String, () => row);
        }
      }

      // 3. Compact normalized tone-free Pinyin match
      if (resultMap.length < limit) {
        final compactQuery = PinyinHelper.toCompactPinyin(trimmed);
        if (compactQuery.isNotEmpty) {
          final candidateRows = await _db.query(
            DatabaseConstants.tableVocabularies,
            where: 'deleted_at IS NULL',
            orderBy: 'frequency_rank ASC',
            limit: 300,
          );
          for (final row in candidateRows) {
            final rowPinyin = row['pinyin'] as String? ?? '';
            final compactRow = PinyinHelper.toCompactPinyin(rowPinyin);
            if (compactRow == compactQuery || compactRow.startsWith(compactQuery)) {
              resultMap.putIfAbsent(row['id'] as String, () => row);
              if (resultMap.length >= limit) break;
            }
          }
        }
      }

      // 4. Substring Pinyin match
      if (resultMap.length < limit) {
        final subPinyin = await _db.query(
          DatabaseConstants.tableVocabularies,
          where: 'LOWER(pinyin) LIKE ? AND deleted_at IS NULL',
          whereArgs: ['%${trimmed.toLowerCase()}%'],
          limit: limit - resultMap.length,
        );
        for (final row in subPinyin) {
          resultMap.putIfAbsent(row['id'] as String, () => row);
        }
      }

      // 5. Vietnamese meaning match from senses
      if (resultMap.length < limit) {
        final senses = await _db.query(
          DatabaseConstants.tableVocabularySenses,
          columns: ['vocabulary_id'],
          where: 'LOWER(meaning_vi) LIKE ? AND deleted_at IS NULL',
          whereArgs: ['%${trimmed.toLowerCase()}%'],
          limit: (limit - resultMap.length) * 2,
        );

        final vocabIds = senses.map((s) => s['vocabulary_id'] as String).toSet();
        for (final id in vocabIds) {
          if (!resultMap.containsKey(id) && resultMap.length < limit) {
            final vocab = await getVocabularyById(id);
            if (vocab != null) {
              resultMap[id] = vocab;
            }
          }
        }
      }
    }

    return resultMap.values.toList();
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
