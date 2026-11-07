import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Test migration v2 adding a new audio cache table
class MockMigrationV2 implements Migration {
  @override
  int get version => 2;

  @override
  String get description => 'Add audio cache table for offline pronunciation';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE audio_cache (
        id TEXT PRIMARY KEY,
        word_id TEXT NOT NULL,
        cached_file_path TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_audio_cache_word ON audio_cache (word_id);');
  }
}

// Intentional failing migration for safety testing
class MockFailingMigrationV3 implements Migration {
  @override
  int get version => 3;

  @override
  String get description => 'Intentional syntax failure to test safeguard';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // Deliberate SQL syntax error
    await db.execute('MALFORMED SQL STATEMENT TABLE FAIL;');
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationEngine Tests', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_migration_test_');
      dbPath = '${tempDir.path}/migration_test.db';
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {
        // Ignore transient Windows file handle release delay on FFI failure tests
      }
    });

    test('Migrates from v1 to v2 while preserving existing data', () async {
      final engine = MigrationEngine(
        migrations: [
          MigrationV1(),
          MockMigrationV2(),
        ],
      );

      // Step 1: Initialize database at v1
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, ver) async {
            await MigrationV1().up(db);
          },
        ),
      );

      // Insert pre-existing v1 data
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert('vocabularies', {
        'id': 'v_mig_001',
        'simplified': '老师',
        'pinyin': 'lǎoshī',
        'hsk_level': 1,
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      await db.close();

      // Step 2: Open and migrate to v2 using MigrationEngine
      db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onUpgrade: (db, oldVer, newVer) async {
            await engine.executeMigrations(db, oldVer, newVer);
          },
        ),
      );

      // Verify v1 data is still completely intact
      final rows = await db.query('vocabularies', where: 'id = ?', whereArgs: ['v_mig_001']);
      expect(rows.length, equals(1));
      expect(rows.first['simplified'], equals('老师'));

      // Verify v2 table was created and is usable
      await db.insert('audio_cache', {
        'id': 'audio_001',
        'word_id': 'v_mig_001',
        'cached_file_path': '/data/cache/laoshi.mp3',
        'file_size': 18400,
        'created_at': nowUtc,
      });

      final cacheRows = await db.query('audio_cache', where: 'id = ?', whereArgs: ['audio_001']);
      expect(cacheRows.length, equals(1));
      expect(cacheRows.first['word_id'], equals('v_mig_001'));

      await db.close();
    });

    test('Migration failure preserves original database without drop or data loss', () async {
      final engine = MigrationEngine(
        migrations: [
          MigrationV1(),
          MockMigrationV2(),
          MockFailingMigrationV3(),
        ],
      );

      // Open database at v2
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, ver) async {
            await MigrationV1().up(db);
            await MockMigrationV2().up(db);
          },
        ),
      );

      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert('vocabularies', {
        'id': 'v_safe_001',
        'simplified': '北京',
        'pinyin': 'Běijīng',
        'hsk_level': 1,
        'created_at': nowUtc,
        'updated_at': nowUtc,
      });

      await db.close();

      // Attempt migration to v3 which will throw MigrationException
      expect(
        () async => await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 3,
            onUpgrade: (db, oldVer, newVer) async {
              await engine.executeMigrations(db, oldVer, newVer);
            },
          ),
        ),
        throwsA(isA<MigrationException>()),
      );

      // Reopen at v2 to assert that database was NOT dropped or wiped!
      db = await databaseFactoryFfi.openDatabase(dbPath);
      final safeRows = await db.query('vocabularies', where: 'id = ?', whereArgs: ['v_safe_001']);
      expect(safeRows.length, equals(1));
      expect(safeRows.first['simplified'], equals('北京'));

      await db.close();
    });

    test('Schema v20 Symmetry: onCreate(0 -> v20) produces identical 48 tables and indexes as incremental onUpgrade(v1 -> v20)', () async {
      final freshDbPath = '${tempDir.path}/fresh_v20.db';
      final upgradedDbPath = '${tempDir.path}/upgraded_v20.db';
      final prodEngine = MigrationEngine();
      const targetVer = DatabaseConstants.currentDatabaseVersion;

      // 1. Fresh install at v20 (onCreate: 0 -> v20)
      final freshDb = await databaseFactoryFfi.openDatabase(
        freshDbPath,
        options: OpenDatabaseOptions(
          version: targetVer,
          onCreate: (db, ver) async {
            await prodEngine.executeMigrations(db, 0, ver);
          },
        ),
      );

      // 2. Legacy v1 install upgraded step-by-step to v20 (onUpgrade: 1 -> v20)
      var upgradedDb = await databaseFactoryFfi.openDatabase(
        upgradedDbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, ver) async {
            await prodEngine.executeMigrations(db, 0, 1);
          },
        ),
      );
      await upgradedDb.close();

      upgradedDb = await databaseFactoryFfi.openDatabase(
        upgradedDbPath,
        options: OpenDatabaseOptions(
          version: targetVer,
          onUpgrade: (db, oldVer, newVer) async {
            await prodEngine.executeMigrations(db, oldVer, newVer);
          },
        ),
      );

      // Compare user-defined tables (excluding sqlite_sequence internal table)
      final freshTables = (await freshDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name ASC",
      ))
          .map((r) => r['name'] as String)
          .toList();

      final upgradedTables = (await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name ASC",
      ))
          .map((r) => r['name'] as String)
          .toList();

      expect(freshTables, equals(upgradedTables));
      expect(freshTables.length, equals(48));

      // Compare indexes
      final freshIndexes = (await freshDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_autoindex_%' ORDER BY name ASC",
      ))
          .map((r) => r['name'] as String)
          .toList();

      final upgradedIndexes = (await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_autoindex_%' ORDER BY name ASC",
      ))
          .map((r) => r['name'] as String)
          .toList();

      expect(freshIndexes, equals(upgradedIndexes));

      await freshDb.close();
      await upgradedDb.close();
    });
  });
}
