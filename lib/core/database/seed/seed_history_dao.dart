import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'seed_models.dart';

class SeedHistoryDao {
  final DatabaseExecutor _db;

  const SeedHistoryDao(this._db);

  Future<SeedHistoryEntry?> getEntry(String bundleName) async {
    final rows = await _db.query(
      DatabaseConstants.tableSeedHistory,
      where: 'bundle_name = ?',
      whereArgs: [bundleName],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SeedHistoryEntry.fromMap(rows.first);
  }

  Future<void> recordInProgress({
    required String bundleName,
    required int version,
    required String checksum,
    required int totalItems,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert(
      DatabaseConstants.tableSeedHistory,
      {
        'bundle_name': bundleName,
        'version': version,
        'checksum': checksum,
        'status': 'in_progress',
        'total_items': totalItems,
        'applied_items': 0,
        'applied_at': now,
        'error_message': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> recordCompleted({
    required String bundleName,
    required int appliedItems,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      DatabaseConstants.tableSeedHistory,
      {
        'status': 'completed',
        'applied_items': appliedItems,
        'applied_at': now,
        'error_message': null,
      },
      where: 'bundle_name = ?',
      whereArgs: [bundleName],
    );
  }

  Future<void> recordFailed({
    required String bundleName,
    required String errorMessage,
    int appliedItems = 0,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      DatabaseConstants.tableSeedHistory,
      {
        'status': 'failed',
        'applied_items': appliedItems,
        'applied_at': now,
        'error_message': errorMessage,
      },
      where: 'bundle_name = ?',
      whereArgs: [bundleName],
    );
  }
}
