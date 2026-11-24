import 'package:sqflite/sqflite.dart';
import '../../../features/dictionary/domain/models/dictionary_models.dart';
import '../../../features/dictionary/domain/utils/pinyin_helper.dart';
import '../database_constants.dart';
import 'dao_utils.dart';

class VocabularyDao {
  final DatabaseExecutor _db;

  VocabularyDao(this._db);

  Future<void> insertVocabulary(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await DaoUtils.safeUpsert(executor, DatabaseConstants.tableVocabularies, row);
  }

  Future<void> insertSense(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await DaoUtils.safeUpsert(executor, DatabaseConstants.tableVocabularySenses, row);
  }

  Future<void> insertExample(Map<String, dynamic> row, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await DaoUtils.safeUpsert(executor, DatabaseConstants.tableVocabularyExamples, row);
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

  /// Batch fetches senses for multiple vocabulary IDs in chunked queries (<= 500 args).
  Future<Map<String, List<Map<String, dynamic>>>> getSensesByVocabularyIds(
    List<String> vocabIds,
  ) async {
    if (vocabIds.isEmpty) return const {};

    final map = <String, List<Map<String, dynamic>>>{};
    for (final chunk in DaoUtils.chunkList(vocabIds)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db.query(
        DatabaseConstants.tableVocabularySenses,
        where: 'vocabulary_id IN ($placeholders) AND deleted_at IS NULL',
        whereArgs: chunk,
        orderBy: 'order_index ASC',
      );
      for (final row in rows) {
        final vid = row['vocabulary_id'] as String;
        map.putIfAbsent(vid, () => []).add(row);
      }
    }
    return map;
  }

  /// Batch fetches verified examples for multiple vocabulary IDs in chunked queries (<= 500 args).
  Future<Map<String, List<Map<String, dynamic>>>> getExamplesByVocabularyIds(
    List<String> vocabIds,
  ) async {
    if (vocabIds.isEmpty) return const {};

    try {
      final map = <String, List<Map<String, dynamic>>>{};
      for (final chunk in DaoUtils.chunkList(vocabIds)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await _db.query(
          DatabaseConstants.tableVocabularyExamples,
          where: 'vocabulary_id IN ($placeholders)',
          whereArgs: chunk,
          orderBy: 'order_index ASC',
        );
        for (final row in rows) {
          final vid = row['vocabulary_id'] as String;
          map.putIfAbsent(vid, () => []).add(row);
        }
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  Future<List<Map<String, dynamic>>> getVocabulariesByHsk(
    int hskLevel, {
    int limit = 50,
    int offset = 0,
  }) async {
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
      final escaped = DaoUtils.escapeLikePattern(trimmed);

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
          where: r"(simplified LIKE ? ESCAPE '\' OR traditional LIKE ? ESCAPE '\') AND deleted_at IS NULL",
          whereArgs: ['$escaped%', '$escaped%'],
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
          where: r"(simplified LIKE ? ESCAPE '\' OR traditional LIKE ? ESCAPE '\') AND deleted_at IS NULL",
          whereArgs: ['%$escaped%', '%$escaped%'],
          limit: limit - resultMap.length,
        );
        for (final row in sub) {
          resultMap.putIfAbsent(row['id'] as String, () => row);
        }
      }
    } else {
      final lowerTrimmed = trimmed.toLowerCase();
      final escapedLower = DaoUtils.escapeLikePattern(lowerTrimmed);
      final cleanQuery = PinyinHelper.removeTones(trimmed).toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final escapedClean = DaoUtils.escapeLikePattern(cleanQuery);

      // 1. Exact Pinyin match
      try {
        final exactPinyin = await _db.query(
          DatabaseConstants.tableVocabularies,
          where: '(LOWER(pinyin) = ? OR pinyin_clean = ?) AND deleted_at IS NULL',
          whereArgs: [lowerTrimmed, cleanQuery],
        );
        for (final row in exactPinyin) {
          resultMap[row['id'] as String] = row;
        }
      } catch (_) {
        final exactPinyin = await _db.query(
          DatabaseConstants.tableVocabularies,
          where: 'LOWER(pinyin) = ? AND deleted_at IS NULL',
          whereArgs: [lowerTrimmed],
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
            where: r"pinyin_clean LIKE ? ESCAPE '\' AND deleted_at IS NULL",
            whereArgs: ['$escapedClean%'],
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

      // 3b. Exact & Prefix Han-Viet match
      if (resultMap.length < limit) {
        try {
          final hvMatches = await _db.query(
            DatabaseConstants.tableVocabularies,
            where: r"(LOWER(hanviet) = ? OR LOWER(hanviet) LIKE ? ESCAPE '\') AND deleted_at IS NULL",
            whereArgs: [lowerTrimmed, '$escapedLower%'],
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
          where: r"(LOWER(pinyin) LIKE ? ESCAPE '\' OR LOWER(pinyin) LIKE ? ESCAPE '\') AND deleted_at IS NULL",
          whereArgs: ['$escapedLower%', '%$escapedLower%'],
          limit: limit - resultMap.length,
        );
        for (final row in prefixPinyin) {
          resultMap.putIfAbsent(row['id'] as String, () => row);
        }
      }

      // 5. Vietnamese meaning match from senses (single batched WHERE id IN instead of N+1)
      if (resultMap.length < limit) {
        final senses = await _db.query(
          DatabaseConstants.tableVocabularySenses,
          columns: ['vocabulary_id'],
          where: r"LOWER(meaning_vi) LIKE ? ESCAPE '\' AND deleted_at IS NULL",
          whereArgs: ['%$escapedLower%'],
          limit: (limit - resultMap.length) * 2,
        );

        final missingIds = senses
            .map((s) => s['vocabulary_id'] as String)
            .where((id) => !resultMap.containsKey(id))
            .toSet()
            .toList();

        if (missingIds.isNotEmpty) {
          for (final chunk in DaoUtils.chunkList(missingIds)) {
            final placeholders = List.filled(chunk.length, '?').join(',');
            final vocabRows = await _db.query(
              DatabaseConstants.tableVocabularies,
              where: 'id IN ($placeholders) AND deleted_at IS NULL',
              whereArgs: chunk,
            );
            for (final vocab in vocabRows) {
              if (resultMap.length >= limit) break;
              resultMap.putIfAbsent(vocab['id'] as String, () => vocab);
            }
            if (resultMap.length >= limit) break;
          }
        }
      }
    }

    return resultMap.values.toList();
  }

  /// Queries the offline comprehensive dictionary via SQLite FTS5 prefix matching + BM25 ranking,
  /// falling back safely to [searchDictionaryEntries] on non-FTS schemas or empty CJK substrings.
  Future<List<Map<String, dynamic>>> searchDictionaryFts(
    String query, {
    int limit = 30,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final sanitized = trimmed.replaceAll(RegExp(r'["*^():+\-\\]'), ' ').trim();
    final tokens = sanitized
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .where((t) {
          final up = t.toUpperCase();
          return up != 'AND' && up != 'OR' && up != 'NOT' && up != 'NEAR';
        })
        .map((t) => '"$t"*')
        .toList();

    if (tokens.isEmpty) {
      return searchDictionaryEntries(trimmed, limit: limit);
    }

    final matchQuery = tokens.join(' ');
    try {
      final rows = await _db.rawQuery('''
        SELECT d.*
        FROM ${DatabaseConstants.tableDictionaryEntriesFts} f
        JOIN ${DatabaseConstants.tableDictionaryEntries} d ON d.rowid = f.rowid
        WHERE ${DatabaseConstants.tableDictionaryEntriesFts} MATCH ?
        ORDER BY bm25(${DatabaseConstants.tableDictionaryEntriesFts})
        LIMIT ?
      ''', [matchQuery, limit]);
      if (rows.isNotEmpty) {
        return rows;
      }
    } catch (_) {
      // Fallback to indexed LIKE search if FTS5 table is unavailable
    }
    return searchDictionaryEntries(trimmed, limit: limit);
  }

  /// Queries the offline comprehensive dictionary (122k words) for words not found in core HSK list.
  Future<List<Map<String, dynamic>>> searchDictionaryEntries(String query, {int limit = 30}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(trimmed);
      if (isChinese) {
        final escaped = DaoUtils.escapeLikePattern(trimmed);
        return await _db.query(
          DatabaseConstants.tableDictionaryEntries,
          where: r"simplified = ? OR traditional = ? OR simplified LIKE ? ESCAPE '\'",
          whereArgs: [trimmed, trimmed, '$escaped%'],
          limit: limit,
        );
      } else {
        final clean = PinyinHelper.removeTones(trimmed).toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final escapedClean = DaoUtils.escapeLikePattern(clean);
        final escapedLower = DaoUtils.escapeLikePattern(trimmed.toLowerCase());
        final Map<String, Map<String, dynamic>> dictResults = {};

        // Step 1: Fast indexed lookup on pinyin_clean (avoids OR full-table scan)
        if (clean.isNotEmpty) {
          final pinyinMatches = await _db.query(
            DatabaseConstants.tableDictionaryEntries,
            where: r"pinyin_clean = ? OR pinyin_clean LIKE ? ESCAPE '\'",
            whereArgs: [clean, '$escapedClean%'],
            limit: limit,
          );
          for (final row in pinyinMatches) {
            final key = (row['id'] ?? row['simplified']).toString();
            dictResults[key] = row;
          }
        }

        // Step 2: Only query meaning_vi if additional slots remain
        if (dictResults.length < limit) {
          final meaningMatches = await _db.query(
            DatabaseConstants.tableDictionaryEntries,
            where: r"LOWER(meaning_vi) LIKE ? ESCAPE '\'",
            whereArgs: ['%$escapedLower%'],
            limit: limit - dictResults.length,
          );
          for (final row in meaningMatches) {
            final key = (row['id'] ?? row['simplified']).toString();
            dictResults.putIfAbsent(key, () => row);
          }
        }

        return dictResults.values.toList();
      }
    } catch (_) {
      return [];
    }
  }

  Future<int> countDictionaryEntries() async {
    try {
      final res = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableDictionaryEntries}',
      );
      return Sqflite.firstIntValue(res) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getDictionaryEntryById(String id) async {
    try {
      final cleanId = id.startsWith('dict_') ? id.substring(5) : id;
      final results = await _db.query(
        DatabaseConstants.tableDictionaryEntries,
        where: 'id = ? OR id = ? OR simplified = ?',
        whereArgs: [id, cleanId, cleanId],
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDictionaryEntryByHanzi(String hanzi) async {
    final trimmed = hanzi.trim();
    if (trimmed.isEmpty) return null;
    try {
      final results = await _db.query(
        DatabaseConstants.tableDictionaryEntries,
        where: 'simplified = ? OR traditional = ?',
        whereArgs: [trimmed, trimmed],
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> insertMinimalVocabularyFromDictionary(
    dynamic item, {
    Transaction? txn,
  }) async {
    final executor = txn ?? _db;
    final now = DateTime.now().toUtc().toIso8601String();

    String id;
    String simplified;
    String traditional;
    String pinyin;
    String cleanPinyin;
    int hskLevel;
    String? source;
    String? meaningVi;
    List<DictionarySense>? senses;

    if (item is VocabularyMinimal) {
      id = item.id;
      simplified = item.hanzi;
      traditional = item.hanzi;
      pinyin = item.pinyin;
      cleanPinyin = item.pinyinClean ??
          PinyinHelper.removeTones(item.pinyin).toLowerCase().replaceAll(RegExp(r'\s+'), '');
      hskLevel = item.hskLevel;
      source = item.source ?? 'CVDICT';
      meaningVi = item.meaningVi;
    } else if (item is DictionaryEntry) {
      id = item.id;
      simplified = item.simplified;
      traditional = item.traditional ?? item.simplified;
      pinyin = item.pinyin;
      cleanPinyin = item.pinyinClean ??
          PinyinHelper.removeTones(item.pinyin).toLowerCase().replaceAll(RegExp(r'\s+'), '');
      hskLevel = item.hskLevel;
      source = item.source ?? 'CVDICT';
      meaningVi = item.senses.isNotEmpty ? item.senses.first.meaningVi : null;
      senses = item.senses;
    } else if (item is Map<String, dynamic>) {
      id = item['id'] as String;
      simplified = (item['hanzi'] ?? item['simplified']) as String;
      traditional = (item['traditional'] ?? simplified) as String;
      pinyin = (item['pinyin'] ?? '') as String;
      cleanPinyin = (item['pinyin_clean'] ??
          PinyinHelper.removeTones(pinyin).toLowerCase().replaceAll(RegExp(r'\s+'), '')) as String;
      hskLevel = (item['hsk_level'] as num?)?.toInt() ?? 0;
      source = (item['source'] ?? 'CVDICT') as String?;
      meaningVi = item['meaning_vi'] as String?;
    } else {
      throw ArgumentError('Unsupported item type: ${item.runtimeType}');
    }

    await executor.rawInsert('''
      INSERT INTO ${DatabaseConstants.tableVocabularies} (
        id, simplified, traditional, pinyin, pinyin_clean, hanviet, hsk_level,
        stroke_count, radicals, frequency_rank, source, license,
        verification_status, is_polyphone, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        simplified = COALESCE(NULLIF(excluded.simplified, ''), ${DatabaseConstants.tableVocabularies}.simplified),
        traditional = COALESCE(NULLIF(excluded.traditional, ''), ${DatabaseConstants.tableVocabularies}.traditional),
        pinyin = COALESCE(NULLIF(excluded.pinyin, ''), ${DatabaseConstants.tableVocabularies}.pinyin),
        pinyin_clean = COALESCE(NULLIF(excluded.pinyin_clean, ''), ${DatabaseConstants.tableVocabularies}.pinyin_clean),
        hanviet = COALESCE(${DatabaseConstants.tableVocabularies}.hanviet, excluded.hanviet),
        hsk_level = CASE
          WHEN ${DatabaseConstants.tableVocabularies}.hsk_level > 0 THEN ${DatabaseConstants.tableVocabularies}.hsk_level
          ELSE excluded.hsk_level
        END,
        stroke_count = COALESCE(${DatabaseConstants.tableVocabularies}.stroke_count, excluded.stroke_count),
        radicals = COALESCE(${DatabaseConstants.tableVocabularies}.radicals, excluded.radicals),
        frequency_rank = COALESCE(${DatabaseConstants.tableVocabularies}.frequency_rank, excluded.frequency_rank),
        updated_at = excluded.updated_at
    ''', [
      id,
      simplified,
      traditional,
      pinyin,
      cleanPinyin,
      null,
      hskLevel,
      null,
      null,
      null,
      source ?? 'CVDICT',
      'CC BY-SA 4.0',
      'verified',
      0,
      now,
      now,
    ]);

    if (senses != null && senses.isNotEmpty) {
      for (final s in senses) {
        await executor.rawInsert('''
          INSERT INTO ${DatabaseConstants.tableVocabularySenses} (
            id, vocabulary_id, part_of_speech, meaning_vi, meaning_en,
            example_cn, example_pinyin, example_vi, source, order_index, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            part_of_speech = COALESCE(excluded.part_of_speech, ${DatabaseConstants.tableVocabularySenses}.part_of_speech),
            meaning_vi = COALESCE(excluded.meaning_vi, ${DatabaseConstants.tableVocabularySenses}.meaning_vi),
            meaning_en = COALESCE(excluded.meaning_en, ${DatabaseConstants.tableVocabularySenses}.meaning_en),
            example_cn = COALESCE(excluded.example_cn, ${DatabaseConstants.tableVocabularySenses}.example_cn),
            example_pinyin = COALESCE(excluded.example_pinyin, ${DatabaseConstants.tableVocabularySenses}.example_pinyin),
            example_vi = COALESCE(excluded.example_vi, ${DatabaseConstants.tableVocabularySenses}.example_vi),
            updated_at = excluded.updated_at
        ''', [
          s.id,
          id,
          s.partOfSpeech,
          s.meaningVi,
          s.meaningEn,
          s.exampleCn,
          s.examplePinyin,
          s.exampleVi,
          s.source ?? 'CVDICT',
          s.orderIndex,
          now,
          now,
        ]);
      }
    } else if (meaningVi != null && meaningVi.isNotEmpty) {
      await executor.rawInsert('''
        INSERT INTO ${DatabaseConstants.tableVocabularySenses} (
          id, vocabulary_id, part_of_speech, meaning_vi, meaning_en,
          example_cn, example_pinyin, example_vi, source, order_index, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          meaning_vi = COALESCE(excluded.meaning_vi, ${DatabaseConstants.tableVocabularySenses}.meaning_vi),
          updated_at = excluded.updated_at
      ''', [
        'sns_$id',
        id,
        'từ vựng',
        meaningVi,
        null,
        null,
        null,
        null,
        source ?? 'CVDICT',
        1,
        now,
        now,
      ]);
    }
  }

  Future<int> clearDictionaryEntries() async {
    try {
      return await _db.delete(DatabaseConstants.tableDictionaryEntries);
    } catch (_) {
      return 0;
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
