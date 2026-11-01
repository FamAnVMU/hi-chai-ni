import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'migration.dart';
import 'migration_v1.dart';

class MigrationException implements Exception {
  final String message;
  final int fromVersion;
  final int toVersion;
  final dynamic originalError;

  MigrationException(this.message, {required this.fromVersion, required this.toVersion, this.originalError});

  @override
  String toString() => 'MigrationException from v$fromVersion to v$toVersion: $message (original: $originalError)';
}

class MigrationEngine {
  final List<Migration> _migrations;

  MigrationEngine({List<Migration>? migrations})
      : _migrations = migrations ?? [MigrationV1()];

  List<Migration> get registeredMigrations => List.unmodifiable(_migrations);

  /// Executes all pending migrations sequentially from oldVersion to newVersion.
  /// Runs inside a transaction.
  /// NEVER drops or resets database upon failure to preserve user data.
  Future<void> executeMigrations(Database db, int oldVersion, int newVersion) async {
    debugPrint('[MigrationEngine] Upgrading database from v$oldVersion to v$newVersion...');

    final pendingMigrations = _migrations
        .where((m) => m.version > oldVersion && m.version <= newVersion)
        .toList()
      ..sort((a, b) => a.version.compareTo(b.version));

    if (pendingMigrations.isEmpty && oldVersion != 0) {
      debugPrint('[MigrationEngine] No pending migrations to execute.');
      return;
    }

    try {
      for (final migration in pendingMigrations) {
        debugPrint('[MigrationEngine] Applying migration v${migration.version}: ${migration.description}');
        await migration.up(db);
      }
      debugPrint('[MigrationEngine] All migrations up to v$newVersion applied successfully.');
    } catch (e, stackTrace) {
      debugPrint('[MigrationEngine] FATAL: Migration failed at v$oldVersion -> v$newVersion: $e\n$stackTrace');
      // Critical safeguard: Re-throw without dropping DB!
      throw MigrationException(
        'Database migration failed. Preserving original data without reset.',
        fromVersion: oldVersion,
        toVersion: newVersion,
        originalError: e,
      );
    }
  }
}
