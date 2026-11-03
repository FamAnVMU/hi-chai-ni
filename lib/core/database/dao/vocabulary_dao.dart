import 'package:sqflite/sqflite.dart';
import '../../../features/dictionary/domain/utils/pinyin_helper.dart';
import '../database_constants.dart';

class VocabularyDao {
  final DatabaseExecutor _db;

  VocabularyDao(this._db);

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
    await executor.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> insertVocabulary(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await _safeUpsert(executor, DatabaseConstants.tableVocabularies, row);
  }

  Future<void> insertSense(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await _safeUpsert(executor, DatabaseConstants.tableVocabularySenses, row);
  }

  Future<void> insertExample(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await _safeUpsert(executor, DatabaseConstants.tableVocabularyExamples, row);
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
    final examples = await getExamplesByVocabularyId(id);
    final result = Map<String, dynamic>.from(vocab);
    result['senses'] = senses;
    result['examples'] = examples;
    return result;
  }

  Future<List<Map<String, dynamic>>> getSensesByVocabularyId(String vocabId) async {
    try {
      return await _db.query(
        DatabaseConstants.tableVocabularySenses,
        where: 'vocabulary_id = ? AND deleted_at IS NULL',
        whereArgs: [vocabId],
        orderBy: 'order_index ASC',
      );
    } catch (_) {
      return await _db.query(
        DatabaseConstants.tableVocabularySenses,
        where: 'vocabulary_id = ? AND deleted_at IS NULL',
        whereArgs: [vocabId],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getExamplesByVocabularyId(String vocabId) async {
    try {
      return await _db.query(
        DatabaseConstants.tableVocabularyExamples,
        where: 'vocabulary_id = ?',
        whereArgs: [vocabId],
        orderBy: 'order_index ASC',
      );
    } catch (_) {
      return [];
    }
  }

  /// Batch fetches senses for multiple vocabulary IDs in a single query.
  /// Eliminates the N+1 query problem during multi-result search operations.
  Future<Map<String, List<Map<String, dynamic>>>> getSensesByVocabularyIds(
    List<String> vocabIds,
  ) async {
    if (vocabIds.isEmpty) return const {};

    final placeholders = List.filled(vocabIds.length, '?').join(',');
    final rows = await _db.query(
      DatabaseConstants.tableVocabularySenses,
      where: 'vocabulary_id IN ($placeholders) AND deleted_at IS NULL',
      whereArgs: vocabIds,
      orderBy: 'order_index ASC',
    );

    final map = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final vid = row['vocabulary_id'] as String;
      map.putIfAbsent(vid, () => []).add(row);
    }
    return map;
  }

  /// Batch fetches verified examples for multiple vocabulary IDs.
  Future<Map<String, List<Map<String, dynamic>>>> getExamplesByVocabularyIds(
    List<String> vocabIds,
  ) async {
    if (vocabIds.isEmpty) return const {};

    try {
      final placeholders = List.filled(vocabIds.length, '?').join(',');
      final rows = await _db.query(
        DatabaseConstants.tableVocabularyExamples,
        where: 'vocabulary_id IN ($placeholders)',
        whereArgs: vocabIds,
        orderBy: 'order_index ASC',
      );

      final map = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final vid = row['vocabulary_id'] as String;
        map.putIfAbsent(vid, () => []).add(row);
      }
      return map;
    } catch (_) {
      return const {};
    }
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
  /// 2. Pinyin (Exact & Prefix match on pinyin or indexed pinyin_clean)
  /// 3. Han-Viet reading match (e.g. "Ai", "Bac Kinh")
  /// 4. Vietnamese meanings in senses
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
      final cleanQuery = PinyinHelper.removeTones(trimmed).toLowerCase().replaceAll(RegExp(r'\s+'), '');
      
      // 1. Exact Pinyin match
      try {
        final exactPinyin = await _db.query(
          DatabaseConstants.tableVocabularies,
          where: '(LOWER(pinyin) = ? OR pinyin_clean = ?) AND deleted_at IS NULL',
          whereArgs: [trimmed.toLowerCase(), cleanQuery],
        );
        for (final row in exactPinyin) {
          resultMap[row['id'] as String] = row;
        }
      } catch (_) {
        final exactPinyin = await _db.query(
          DatabaseConstants.tableVocabularies,
          where: 'LOWER(pinyin) = ? AND deleted_at IS NULL',
          whereArgs: [trimmed.toLowerCase()],
        );
        for (final row in exactPinyin) {
          resultMap[row['id'] as String] = row;
        }
      }

      // 2. Indexed Pinyin Clean Prefix match
      if (resultMap.length < limit && cleanQuery.isNotEmpty) {
        try {
          final prefixClean = await _db.query(
            DatabaseConstants.tableVocabularies,
            where: 'pinyin_clean LIKE ? AND deleted_at IS NULL',
            whereArgs: ['$cleanQuery%'],
            limit: limit - resultMap.length,
          );
          for (final row in prefixClean) {
            resultMap.putIfAbsent(row['id'] as String, () => row);
          }
        } catch (_) {}
      }

      // 3. Compact fallback comparison on raw pinyin for legacy / un-indexed rows
      if (resultMap.length < limit && cleanQuery.isNotEmpty) {
        final candidateRows = await _db.query(
          DatabaseConstants.tableVocabularies,
          where: 'deleted_at IS NULL',
          orderBy: 'frequency_rank ASC',
          limit: 300,
        );
        for (final row in candidateRows) {
          final rowPinyin = row['pinyin'] as String? ?? '';
          final compactRow = PinyinHelper.toCompactPinyin(rowPinyin);
          if (compactRow == cleanQuery || compactRow.startsWith(cleanQuery)) {
            resultMap.putIfAbsent(row['id'] as String, () => row);
            if (resultMap.length >= limit) break;
          }
        }
      }

      // 3. Exact & Prefix Han-Viet match
      if (resultMap.length < limit) {
        try {
          final hvMatches = await _db.query(
            DatabaseConstants.tableVocabularies,
            where: '(LOWER(hanviet) = ? OR LOWER(hanviet) LIKE ?) AND deleted_at IS NULL',
            whereArgs: [trimmed.toLowerCase(), '${trimmed.toLowerCase()}%'],
            limit: limit - resultMap.length,
          );
          for (final row in hvMatches) {
            resultMap.putIfAbsent(row['id'] as String, () => row);
          }
        } catch (_) {}
      }

      // 4. Prefix & Substring Pinyin match
      if (resultMap.length < limit) {
        final prefixPinyin = await _db.query(
          DatabaseConstants.tableVocabularies,
          where: '(LOWER(pinyin) LIKE ? OR LOWER(pinyin) LIKE ?) AND deleted_at IS NULL',
          whereArgs: ['${trimmed.toLowerCase()}%', '%${trimmed.toLowerCase()}%'],
          limit: limit - resultMap.length,
        );
        for (final row in prefixPinyin) {
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

  /// Queries the offline comprehensive dictionary (122k words) for words not found in core HSK list.
  Future<List<Map<String, dynamic>>> searchDictionaryEntries(String query, {int limit = 30}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(trimmed);
      if (isChinese) {
        return await _db.query(
          DatabaseConstants.tableDictionaryEntries,
          where: 'simplified = ? OR traditional = ? OR simplified LIKE ?',
          whereArgs: [trimmed, trimmed, '$trimmed%'],
          limit: limit,
        );
      } else {
        final clean = PinyinHelper.removeTones(trimmed).toLowerCase().replaceAll(RegExp(r'\s+'), '');
        return await _db.query(
          DatabaseConstants.tableDictionaryEntries,
          where: 'pinyin_clean = ? OR pinyin_clean LIKE ? OR LOWER(meaning_vi) LIKE ?',
          whereArgs: [clean, '$clean%', '%${trimmed.toLowerCase()}%'],
          limit: limit,
        );
      }
    } catch (_) {
      return [];
    }
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
