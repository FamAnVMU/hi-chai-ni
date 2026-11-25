import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../../../core/database/migrations/migration_v21.dart';

class OfflineDictionaryLoader {
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
    try {
      final countRes = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableDictionaryEntries}',
      );
      final currentCount = Sqflite.firstIntValue(countRes) ?? 0;
      if (currentCount > 0 && !forceReload) {
        await _restoreFtsTriggersIfMissing();
        return currentCount;
      }
    } catch (_) {
      return 0;
    }

    try {
      await _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dict_simplified ON ${DatabaseConstants.tableDictionaryEntries} (simplified);',
      );
      await _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dict_traditional ON ${DatabaseConstants.tableDictionaryEntries} (traditional);',
      );
      await _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dict_pinyin ON ${DatabaseConstants.tableDictionaryEntries} (pinyin);',
      );
      await _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dict_pinyin_clean ON ${DatabaseConstants.tableDictionaryEntries} (pinyin_clean);',
      );
      await _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dict_hsk_level ON ${DatabaseConstants.tableDictionaryEntries} (hsk_level);',
      );
    } catch (_) {}

    List<Map<String, dynamic>> entries;
    try {
      if (jsonString != null) {
        entries = await Isolate.run(() {
          final decoded = json.decode(jsonString) as Map<String, dynamic>;
          final rawList = decoded['entries'] as List<dynamic>;
          return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      } else if (filePath != null && File(filePath).existsSync()) {
        entries = await Isolate.run(() async {
          final file = File(filePath);
          final raw = await file.readAsString();
          final decoded = json.decode(raw) as Map<String, dynamic>;
          final rawList = decoded['entries'] as List<dynamic>;
          return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      } else {
        String? rawContent;
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

        final raw = rawContent;
        entries = await Isolate.run(() {
          final decoded = json.decode(raw) as Map<String, dynamic>;
          final rawList = decoded['entries'] as List<dynamic>;
          return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {
      return 0;
    }

    final total = entries.length;
    final now = DateTime.now().toUtc().toIso8601String();
    int processed = 0;

    // Bulk seeding: skip per-row FTS trigger writes, rebuild the FTS index once at the end.
    final hasFts = await _hasDictionaryFts();
    if (hasFts) {
      await MigrationV21.dropDictionaryFtsTriggers(_db);
    }

    try {
      for (int i = 0; i < total; i += batchSize) {
        final end = (i + batchSize < total) ? i + batchSize : total;
        final chunk = entries.sublist(i, end);

        await _db.transaction((txn) async {
          final batch = txn.batch();
          for (int j = 0; j < chunk.length; j++) {
            final item = chunk[j];
            final id = 'dict_${i + j + 1}';
            // Upsert keeps the rowid stable (INSERT OR REPLACE deletes + reinserts without
            // firing delete triggers unless recursive_triggers is on).
            batch.rawInsert('''
              INSERT INTO ${DatabaseConstants.tableDictionaryEntries} (
                id, simplified, traditional, pinyin, pinyin_clean, pinyin_numeric,
                hanviet, hsk_level, meaning_vi, meaning_en, source, created_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                simplified = excluded.simplified,
                traditional = excluded.traditional,
                pinyin = excluded.pinyin,
                pinyin_clean = excluded.pinyin_clean,
                meaning_vi = excluded.meaning_vi,
                source = excluded.source
            ''', [
              id,
              item['simplified'],
              item['traditional'] ?? item['simplified'],
              item['pinyin'],
              item['pinyin_clean'],
              null,
              null,
              0,
              item['meaning_vi'],
              null,
              item['source'] ?? 'CVDICT',
              now,
            ]);
          }
          await batch.commit(noResult: true);
        });

        processed += chunk.length;
        onProgress?.call(processed, total);
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      if (hasFts && _db.isOpen) {
        await MigrationV21.createDictionaryFtsTriggers(_db);
        await MigrationV21.rebuildDictionaryFts(_db);
      }
    }

    return processed;
  }

  Future<bool> _hasDictionaryFts() async {
    final rows = await _db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [DatabaseConstants.tableDictionaryEntriesFts],
    );
    return rows.isNotEmpty;
  }

  /// Recovers from a seed interrupted (e.g. app killed) after triggers were dropped.
  Future<void> _restoreFtsTriggersIfMissing() async {
    if (!await _hasDictionaryFts()) return;
    final rows = await _db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'trigger' AND name = ? LIMIT 1",
      [MigrationV21.dictionaryFtsTriggerNames.first],
    );
    if (rows.isNotEmpty) return;
    await MigrationV21.createDictionaryFtsTriggers(_db);
    await MigrationV21.rebuildDictionaryFts(_db);
  }
}
