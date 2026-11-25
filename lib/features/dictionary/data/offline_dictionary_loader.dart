import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../../../core/database/migrations/migration_v21.dart';

class OfflineDictionaryLoader {
  static const int fullDictionaryMinEntries = 119000;
  static const String seedHistoryBundleName = 'offline_dictionary_entries';

  final Database _db;

  OfflineDictionaryLoader(this._db);

  Future<int> ensureSeedLoaded({
    String assetPath = 'assets/data/offline_dictionary_entries.json',
    AssetBundle? bundle,
    String? filePath,
    String? jsonString,
    int batchSize = 5000,
    bool forceReload = false,
    void Function(int processed, int total)? onProgress,
  }) async {
    final isFullSeed = jsonString == null;
    int currentCount = 0;
    try {
      final countRes = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableDictionaryEntries}',
      );
      currentCount = Sqflite.firstIntValue(countRes) ?? 0;
      if (!forceReload && currentCount > 0) {
        final alreadyComplete = isFullSeed
            ? (currentCount >= fullDictionaryMinEntries || await _isSeedHistoryCompleted())
            : true;
        if (alreadyComplete) {
          await _restoreIndexesAndFtsIfMissing();
          return currentCount;
        }
      }
    } catch (_) {
      return 0;
    }

    List<List<Object?>> compactRows;
    try {
      if (jsonString != null) {
        compactRows = await Isolate.run(() => _decodeCompactEntries(jsonString));
      } else if (filePath != null && File(filePath).existsSync()) {
        compactRows = await Isolate.run(() async {
          final raw = await File(filePath).readAsString();
          return _decodeCompactEntries(raw);
        });
      } else {
        String rawContent;
        try {
          final assetBundle = bundle ?? rootBundle;
          rawContent = await assetBundle.loadString(assetPath);
        } catch (_) {
          final file = File(assetPath);
          if (file.existsSync()) {
            rawContent = await file.readAsString();
          } else {
            rethrow;
          }
        }
        compactRows = await Isolate.run(() => _decodeCompactEntries(rawContent));
      }
    } catch (_) {
      return 0;
    }

    final total = compactRows.length;
    final now = DateTime.now().toUtc().toIso8601String();
    int processed = 0;

    // Bulk seeding optimization: drop FTS triggers and (for large seeds) secondary B-tree
    // indexes before inserting, then rebuild once in finally.
    final hasFts = await _hasDictionaryFts();
    final dropSecondaryIndexes = total >= 10000;
    if (hasFts) {
      await MigrationV21.dropDictionaryFtsTriggers(_db);
    }
    if (dropSecondaryIndexes) {
      await _dropDictionaryIndexes();
    }

    try {
      final useIgnoreForFreshEmpty = currentCount == 0 && !forceReload;
      final insertSql = useIgnoreForFreshEmpty
          ? '''
              INSERT OR IGNORE INTO ${DatabaseConstants.tableDictionaryEntries} (
                id, simplified, traditional, pinyin, pinyin_clean, pinyin_numeric,
                hanviet, hsk_level, meaning_vi, meaning_en, source, created_at
              ) VALUES (?, ?, ?, ?, ?, NULL, NULL, 0, ?, NULL, ?, ?)
            '''
          : '''
              INSERT INTO ${DatabaseConstants.tableDictionaryEntries} (
                id, simplified, traditional, pinyin, pinyin_clean, pinyin_numeric,
                hanviet, hsk_level, meaning_vi, meaning_en, source, created_at
              ) VALUES (?, ?, ?, ?, ?, NULL, NULL, 0, ?, NULL, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                simplified = excluded.simplified,
                traditional = excluded.traditional,
                pinyin = excluded.pinyin,
                pinyin_clean = excluded.pinyin_clean,
                meaning_vi = excluded.meaning_vi,
                source = excluded.source
            ''';

      await _db.transaction((txn) async {
        for (int i = 0; i < total; i += batchSize) {
          final end = (i + batchSize < total) ? i + batchSize : total;
          final batch = txn.batch();
          for (int k = i; k < end; k++) {
            final row = compactRows[k];
            batch.rawInsert(insertSql, [
              'dict_${k + 1}',
              row[0],
              row[1],
              row[2],
              row[3],
              row[4],
              row[5],
              now,
            ]);
          }
          await batch.commit(noResult: true);
          processed += (end - i);
          onProgress?.call(processed, total);
        }
      });

      if (isFullSeed && processed >= fullDictionaryMinEntries) {
        await _recordSeedCompleted(processed, now);
      }
    } finally {
      if (_db.isOpen) {
        await _createDictionaryIndexes();
        if (hasFts) {
          await MigrationV21.createDictionaryFtsTriggers(_db);
          await MigrationV21.rebuildDictionaryFts(_db);
        }
      }
    }

    return processed;
  }

  static List<List<Object?>> _decodeCompactEntries(String rawJson) {
    final decoded = json.decode(rawJson) as Map<String, dynamic>;
    final rawList = decoded['entries'] as List<dynamic>;
    final rows = List<List<Object?>>.filled(rawList.length, const [], growable: false);
    for (int i = 0; i < rawList.length; i++) {
      final item = rawList[i] as Map<dynamic, dynamic>;
      final simplified = item['simplified'];
      rows[i] = [
        simplified,
        item['traditional'] ?? simplified,
        item['pinyin'],
        item['pinyin_clean'],
        item['meaning_vi'],
        item['source'] ?? 'CVDICT',
      ];
    }
    return rows;
  }

  Future<bool> _isSeedHistoryCompleted() async {
    try {
      final rows = await _db.query(
        'seed_history',
        columns: ['status', 'total_items'],
        where: 'bundle_name = ? AND status = ?',
        whereArgs: [seedHistoryBundleName, 'completed'],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final recordedTotal = (rows.first['total_items'] as num?)?.toInt() ?? 0;
      return recordedTotal >= fullDictionaryMinEntries;
    } catch (_) {
      return false;
    }
  }

  Future<void> _recordSeedCompleted(int totalItems, String nowIso) async {
    try {
      await _db.insert(
        'seed_history',
        {
          'bundle_name': seedHistoryBundleName,
          'version': 1,
          'checksum': 'cvdict_cc_cedict_v1',
          'status': 'completed',
          'total_items': totalItems,
          'applied_items': totalItems,
          'applied_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> _dropDictionaryIndexes() async {
    const indexes = [
      'idx_dict_simplified',
      'idx_dict_traditional',
      'idx_dict_pinyin',
      'idx_dict_pinyin_clean',
      'idx_dict_hsk_level',
    ];
    for (final name in indexes) {
      try {
        await _db.execute('DROP INDEX IF EXISTS $name;');
      } catch (_) {}
    }
  }

  Future<void> _createDictionaryIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_dict_simplified ON ${DatabaseConstants.tableDictionaryEntries} (simplified);',
      'CREATE INDEX IF NOT EXISTS idx_dict_traditional ON ${DatabaseConstants.tableDictionaryEntries} (traditional);',
      'CREATE INDEX IF NOT EXISTS idx_dict_pinyin ON ${DatabaseConstants.tableDictionaryEntries} (pinyin);',
      'CREATE INDEX IF NOT EXISTS idx_dict_pinyin_clean ON ${DatabaseConstants.tableDictionaryEntries} (pinyin_clean);',
      'CREATE INDEX IF NOT EXISTS idx_dict_hsk_level ON ${DatabaseConstants.tableDictionaryEntries} (hsk_level);',
    ];
    for (final sql in statements) {
      try {
        await _db.execute(sql);
      } catch (_) {}
    }
  }

  Future<bool> _hasDictionaryFts() async {
    final rows = await _db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [DatabaseConstants.tableDictionaryEntriesFts],
    );
    return rows.isNotEmpty;
  }

  /// Recovers from a seed interrupted (e.g. app killed) after indexes or triggers were dropped.
  Future<void> _restoreIndexesAndFtsIfMissing() async {
    final idxRows = await _db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type = 'index' AND tbl_name = ? AND name LIKE 'idx_dict_%'",
      [DatabaseConstants.tableDictionaryEntries],
    );
    final idxCount = (idxRows.firstOrNull?['cnt'] as num?)?.toInt() ?? 0;
    if (idxCount < 5) {
      await _createDictionaryIndexes();
    }

    if (!await _hasDictionaryFts()) return;
    final trigRows = await _db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'trigger' AND name = ? LIMIT 1",
      [MigrationV21.dictionaryFtsTriggerNames.first],
    );
    if (trigRows.isNotEmpty) return;
    await MigrationV21.createDictionaryFtsTriggers(_db);
    await MigrationV21.rebuildDictionaryFts(_db);
  }
}
