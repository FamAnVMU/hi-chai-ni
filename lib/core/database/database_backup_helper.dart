import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseIntegrityException implements Exception {
  final String message;
  final List<String> issues;

  DatabaseIntegrityException(this.message, {this.issues = const []});

  @override
  String toString() => 'DatabaseIntegrityException: $message (Issues: ${issues.join(', ')})';
}

class DatabaseBackupHelper {
  DatabaseBackupHelper._();

  /// Runs PRAGMA integrity_check on the active SQLite connection.
  /// Returns a list of reported issues. Empty list means the database is 100% healthy ('ok').
  static Future<List<String>> checkIntegrity(Database db) async {
    final result = await db.rawQuery('PRAGMA integrity_check;');
    final issues = <String>[];

    for (final row in result) {
      final value = row.values.first?.toString() ?? '';
      if (value.toLowerCase() != 'ok') {
        issues.add(value);
      }
    }

    return issues;
  }

  /// Creates a safe, consistent backup of the database, handling WAL mode cleanly.
  /// 1. Verifies integrity of the source database.
  /// 2. Executes a WAL checkpoint (TRUNCATE) to flush all WAL pages to the main DB file.
  /// 3. Employs VACUUM INTO when available for an atomic copy, or safe file copy.
  /// 4. Scrubs credential keys ONLY from the destination backup copy (never live DB).
  /// 5. Verifies the integrity of the created backup file in read-only mode.
  static Future<File> createBackup({
    required Database db,
    required String dbPath,
    required String destinationBackupPath,
  }) async {
    // 1. Verify health before backup
    final initialIssues = await checkIntegrity(db);
    if (initialIssues.isNotEmpty) {
      throw DatabaseIntegrityException(
        'Cannot backup corrupted database.',
        issues: initialIssues,
      );
    }

    // 2. Perform safe WAL checkpoint to flush pending transactions
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
      debugPrint('[DatabaseBackup] WAL checkpoint completed successfully.');
    } catch (e) {
      debugPrint('[DatabaseBackup] Warning: wal_checkpoint failed: $e');
    }

    final backupFile = File(destinationBackupPath);
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
    await backupFile.parent.create(recursive: true);

    // 3. Attempt atomic VACUUM INTO
    bool vacuumSucceeded = false;
    try {
      final escapedPath = destinationBackupPath.replaceAll("'", "''");
      await db.execute("VACUUM INTO '$escapedPath';");
      vacuumSucceeded = true;
      debugPrint('[DatabaseBackup] Atomic VACUUM INTO completed successfully.');
    } catch (e) {
      debugPrint('[DatabaseBackup] VACUUM INTO not supported or failed ($e), falling back to file copy.');
    }

    if (!vacuumSucceeded) {
      final sourceFile = File(dbPath);
      if (!await sourceFile.exists()) {
        throw StateError('Source database file does not exist at: $dbPath');
      }
      await sourceFile.copy(destinationBackupPath);
    }

    // 4. Scrub sensitive credential keys on the destination backup file only
    Database? scrubDb;
    try {
      scrubDb = await databaseFactory.openDatabase(destinationBackupPath);
      await scrubDb.execute(
        "DELETE FROM app_settings WHERE "
        "LOWER(key) LIKE '%api_key%' OR "
        "LOWER(key) LIKE '%auth_token%' OR "
        "LOWER(key) LIKE '%access_token%' OR "
        "LOWER(key) LIKE '%refresh_token%' OR "
        "LOWER(key) LIKE '%secret_key%' OR "
        "LOWER(key) LIKE '%password%';",
      );
    } catch (_) {
      // app_settings table may not exist in minimal test schemas
    } finally {
      if (scrubDb != null && scrubDb.isOpen) {
        await scrubDb.close();
      }
    }

    // 5. Verify integrity of the created backup file in read-only safe mode
    Database? verifyDb;
    try {
      verifyDb = await databaseFactory.openDatabase(
        destinationBackupPath,
        options: OpenDatabaseOptions(
          readOnly: true,
          onConfigure: (conn) async {
            await conn.execute('PRAGMA trusted_schema = OFF;');
            await conn.execute('PRAGMA query_only = ON;');
          },
        ),
      );
      final backupIssues = await checkIntegrity(verifyDb);
      if (backupIssues.isNotEmpty) {
        throw DatabaseIntegrityException(
          'Created backup failed integrity verification.',
          issues: backupIssues,
        );
      }
    } catch (e) {
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      if (e is DatabaseIntegrityException) rethrow;
      throw DatabaseIntegrityException(
        'Failed to verify created backup integrity: $e',
      );
    } finally {
      if (verifyDb != null && verifyDb.isOpen) {
        await verifyDb.close();
      }
    }

    return backupFile;
  }
}
