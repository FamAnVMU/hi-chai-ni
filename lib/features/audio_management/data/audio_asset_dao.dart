import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';

class AudioAssetDao {
  final DatabaseExecutor _db;

  const AudioAssetDao(this._db);

  DatabaseExecutor _getExecutor(DatabaseExecutor? custom) => custom ?? _db;

  Future<void> insertAsset(Map<String, dynamic> row, {DatabaseExecutor? executor}) async {
    final exec = _getExecutor(executor);
    await exec.insert(
      DatabaseConstants.tableAudioAssets,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertAssetsBatch(List<Map<String, dynamic>> rows, {DatabaseExecutor? executor}) async {
    if (rows.isEmpty) return;
    final exec = _getExecutor(executor);
    final batch = exec.batch();
    for (final row in rows) {
      batch.insert(
        DatabaseConstants.tableAudioAssets,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>?> getAssetById(String id, {DatabaseExecutor? executor}) async {
    final exec = _getExecutor(executor);
    final results = await exec.query(
      DatabaseConstants.tableAudioAssets,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getAssetByContentId(String contentId, {DatabaseExecutor? executor}) async {
    final exec = _getExecutor(executor);
    final results = await exec.query(
      DatabaseConstants.tableAudioAssets,
      where: 'content_id = ?',
      whereArgs: [contentId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAssetsByPackage(String packageId, {DatabaseExecutor? executor}) async {
    final exec = _getExecutor(executor);
    return exec.query(
      DatabaseConstants.tableAudioAssets,
      where: 'package_id = ?',
      whereArgs: [packageId],
      orderBy: 'relative_path ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAssetsByLevelAndType(
    int hskLevel,
    String audioType, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    return exec.query(
      DatabaseConstants.tableAudioAssets,
      where: 'hsk_level = ? AND audio_type = ?',
      whereArgs: [hskLevel, audioType],
      orderBy: 'content_id ASC',
    );
  }

  Future<void> updateAssetStatus(
    String id,
    String status, {
    String? localPath,
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    final updateData = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (localPath != null) {
      updateData['local_path'] = localPath;
    }
    await exec.update(
      DatabaseConstants.tableAudioAssets,
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAssetsByPackage(String packageId, {DatabaseExecutor? executor}) async {
    final exec = _getExecutor(executor);
    await exec.delete(
      DatabaseConstants.tableAudioAssets,
      where: 'package_id = ?',
      whereArgs: [packageId],
    );
  }

  Future<int> getReadyCountByPackage(String packageId, {DatabaseExecutor? executor}) async {
    final exec = _getExecutor(executor);
    final res = await exec.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableAudioAssets} WHERE package_id = ? AND status = ?',
      [packageId, 'ready'],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }
}
