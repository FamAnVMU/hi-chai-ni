import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/core/database/migrations/migration_v21.dart';
import 'package:hi_chinese/features/dictionary/data/offline_dictionary_loader.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String _json(String simplified, String meaning) => '''
{"entries": [
  {"simplified": "$simplified", "traditional": "$simplified", "pinyin": "mao1", "pinyin_clean": "mao", "meaning_vi": "$meaning", "source": "CVDICT"}
]}''';

void main() {
  late Database db;
  late Directory tempDir;
  final fts = DatabaseConstants.tableDictionaryEntriesFts;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dict_fts_seed_');
    db = await databaseFactory.openDatabase('${tempDir.path}/fts.db');
    await MigrationEngine().executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<List<String>> match(String q) async => (await db.rawQuery(
        'SELECT id FROM $fts WHERE $fts MATCH ?',
        [q],
      ))
          .map((r) => r['id'] as String)
          .toList();

  Future<int> triggerCount() async => (await db.rawQuery(
        "SELECT COUNT(*) AS c FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'trg_dict_entries_%'",
      )).first['c'] as int;

  test('bulk seed rebuilds FTS once, restores triggers, and forceReload leaves no stale FTS rows', () async {
    final loader = OfflineDictionaryLoader(db);

    expect(await loader.ensureSeedLoaded(jsonString: _json('猫', 'conmeo')), 1);
    expect(await triggerCount(), 3);
    expect(await match('conmeo'), ['dict_1']);

    // Same id, new content: the old FTS term must disappear.
    expect(await loader.ensureSeedLoaded(jsonString: _json('猫', 'meocon'), forceReload: true), 1);
    expect(await match('conmeo'), isEmpty);
    expect(await match('meocon'), ['dict_1']);
    expect(await triggerCount(), 3);

    // Triggers still keep FTS in sync for normal single-row writes after seeding.
    await db.update(DatabaseConstants.tableDictionaryEntries, {'meaning_vi': 'hoamieu'},
        where: 'id = ?', whereArgs: ['dict_1']);
    expect(await match('hoamieu'), ['dict_1']);
    expect(await match('meocon'), isEmpty);
  });

  test('interrupted seed (triggers missing) is repaired on next call', () async {
    final loader = OfflineDictionaryLoader(db);
    await loader.ensureSeedLoaded(jsonString: _json('狗', 'concho'));

    await MigrationV21.dropDictionaryFtsTriggers(db);
    await db.execute("INSERT INTO $fts($fts) VALUES('delete-all')");
    expect(await triggerCount(), 0);

    expect(await loader.ensureSeedLoaded(jsonString: _json('狗', 'concho')), 1);
    expect(await triggerCount(), 3);
    expect(await match('concho'), ['dict_1']);
  });
}
