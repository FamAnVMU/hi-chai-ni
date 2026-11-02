import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class AppSettingsDao {
  final Database _db;

  AppSettingsDao(this._db);

  Future<String?> getSetting(String key) async {
    final rows = await _db.query(
      DatabaseConstants.tableAppSettings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert(
      DatabaseConstants.tableAppSettings,
      {
        'key': key,
        'value': value,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAllSettings() async {
    final rows = await _db.query(DatabaseConstants.tableAppSettings);
    final map = <String, String>{};
    for (final row in rows) {
      final k = row['key'] as String?;
      final v = row['value'] as String?;
      if (k != null && v != null) {
        map[k] = v;
      }
    }
    return map;
  }
}
