import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class ContentItemDao {
  final DatabaseExecutor _db;

  const ContentItemDao(this._db);

  Future<void> insertContentItem(Map<String, dynamic> row) async {
    await _db.insert(
      DatabaseConstants.tableContentItems,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertContentItemsBatch(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final batch = _db.batch();
    for (final row in rows) {
      batch.insert(
        DatabaseConstants.tableContentItems,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>?> getContentItemByContentId(String contentId) async {
    final results = await _db.query(
      DatabaseConstants.tableContentItems,
      where: 'content_id = ?',
      whereArgs: [contentId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getContentItemsByLevelAndType(int hskLevel, String knowledgeType) async {
    return _db.query(
      DatabaseConstants.tableContentItems,
      where: 'hsk_level = ? AND knowledge_type = ?',
      whereArgs: [hskLevel, knowledgeType],
      orderBy: 'title ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getContentItemsByIds(List<String> contentIds) async {
    if (contentIds.isEmpty) return [];
    final placeholders = List.filled(contentIds.length, '?').join(',');
    return _db.query(
      DatabaseConstants.tableContentItems,
      where: 'content_id IN ($placeholders)',
      whereArgs: contentIds,
    );
  }
}
