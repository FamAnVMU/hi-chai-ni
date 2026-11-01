import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'database_backup_helper.dart';
import 'database_constants.dart';
import 'migrations/migration_engine.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

class AppDatabase {
  AppDatabase._({MigrationEngine? migrationEngine})
      : _migrationEngine = migrationEngine ?? MigrationEngine();

  static final AppDatabase instance = AppDatabase._();

  final MigrationEngine _migrationEngine;
  Database? _db;
  String? _databasePath;

  bool get isOpen => _db != null && _db!.isOpen;
  String? get path => _databasePath;

  /// Returns the active Database instance. Throws StateError if not initialized.
  Database get database {
    final db = _db;
    if (db == null || !db.isOpen) {
      throw StateError('Database is not open. Call AppDatabase.instance.open() first.');
    }
    return db;
  }

  /// Initializes and opens the SQLite database.
  /// Guarantees:
  /// - Path is in application documents / databases directory, never in build or apk dir.
  /// - Foreign keys enforced: PRAGMA foreign_keys = ON;
  /// - WAL journal mode safely configured: PRAGMA journal_mode = WAL;
  /// - Migrations executed incrementally via MigrationEngine.
  Future<Database> open({
    String? customPath,
    DatabaseFactory? customFactory,
    int version = DatabaseConstants.currentDatabaseVersion,
  }) async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }

    final factory = customFactory ?? databaseFactory;

    if (customPath != null) {
      _databasePath = customPath;
    } else {
      final databasesDir = await factory.getDatabasesPath();
      _databasePath = p.join(databasesDir, DatabaseConstants.databaseName);
    }

    debugPrint('[AppDatabase] Opening SQLite database at: $_databasePath (v$version)');

    _db = await factory.openDatabase(
      _databasePath!,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) async {
          // 1. Enable SQLite Foreign Keys constraint enforcement
          await db.execute('PRAGMA foreign_keys = ON;');

          // 2. Enable Write-Ahead Logging (WAL) for concurrency & performance
          final journalModeResult = await db.rawQuery('PRAGMA journal_mode = WAL;');
          final actualMode = journalModeResult.first.values.first?.toString().toUpperCase();
          debugPrint('[AppDatabase] SQLite Journal Mode configured: $actualMode');

          // Normal synchronous mode provides durability with low disk I/O latency in WAL mode
          await db.execute('PRAGMA synchronous = NORMAL;');

          // 3. Cache size: 8MB in-memory page cache (-8000 pages of 1KB each)
          await db.execute('PRAGMA cache_size = -8000;');

          // 4. In-memory temporary store for sorting and indexing operations
          await db.execute('PRAGMA temp_store = MEMORY;');
        },
        onCreate: (db, ver) async {
          debugPrint('[AppDatabase] Creating initial database schema (v$ver)...');
          await _migrationEngine.executeMigrations(db, 0, ver);
        },
        onUpgrade: (db, oldVer, newVer) async {
          debugPrint('[AppDatabase] Upgrading database from v$oldVer to v$newVer...');
          await _migrationEngine.executeMigrations(db, oldVer, newVer);
        },
        onDowngrade: (db, oldVer, newVer) async {
          // Safeguard: Refuse destructive rollback that could wipe user data
          throw StateError(
            'Downgrading database from v$oldVer to v$newVer is forbidden to prevent data loss.',
          );
        },
      ),
    );

    return _db!;
  }

  /// Executes an operation inside a database transaction.
  /// Automatically rolls back all changes if any error occurs.
  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    return await database.transaction<T>(action);
  }

  /// Verifies database integrity via PRAGMA integrity_check.
  Future<List<String>> checkIntegrity() async {
    return await DatabaseBackupHelper.checkIntegrity(database);
  }

  /// Creates a safe WAL-checkpointed backup to destinationPath.
  Future<File> backup(String destinationPath) async {
    final currentPath = _databasePath;
    if (currentPath == null) {
      throw StateError('Cannot backup: database path is undefined.');
    }
    return await DatabaseBackupHelper.createBackup(
      db: database,
      dbPath: currentPath,
      destinationBackupPath: destinationPath,
    );
  }

  /// Manually executes a WAL checkpoint to flush transaction logs into the main database file.
  Future<void> checkpoint({bool truncate = false}) async {
    final mode = truncate ? 'TRUNCATE' : 'PASSIVE';
    try {
      await database.rawQuery('PRAGMA wal_checkpoint($mode);');
    } catch (e) {
      debugPrint('[AppDatabase] Warning: wal_checkpoint($mode) failed: $e');
    }
  }

  /// Runs SQLite cost-based query planner optimization.
  /// Recommended by SQLite documentation prior to closing or during idle periods.
  Future<void> optimize() async {
    try {
      await database.execute('PRAGMA optimize;');
    } catch (e) {
      debugPrint('[AppDatabase] Warning: PRAGMA optimize failed: $e');
    }
  }

  /// Flushes pending WAL checkpoints and closes the database connection.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      try {
        await _db!.execute('PRAGMA optimize;');
        await _db!.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
      } catch (e) {
        debugPrint('[AppDatabase] Warning on close: $e');
      }
      await _db!.close();
      _db = null;
      debugPrint('[AppDatabase] Database connection closed.');
    }
  }
}
