import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class ContentItemDao {
  final DatabaseExecutor _db;

  const ContentItemDao(this._db);

  Future<void> _safeUpsert(
    DatabaseExecutor executor,
    String table,
    Map<String, dynamic> row, {
    String conflictKey = 'content_id',
  }) async {
    final conflictVal = row[conflictKey];
    if (conflictVal != null) {
      final existing = await executor.query(
        table,
        columns: ['id', conflictKey],
        where: '$conflictKey = ?',
        whereArgs: [conflictVal],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        // Keep existing internal ID to preserve any foreign key links
        final updatedRow = Map<String, dynamic>.from(row);
        updatedRow['id'] = existing.first['id'];
        await executor.update(
          table,
          updatedRow,
          where: '$conflictKey = ?',
          whereArgs: [conflictVal],
        );
        return;
      }
    }
    await executor.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> insertContentItem(Map<String, dynamic> row) async {
    await _safeUpsert(_db, DatabaseConstants.tableContentItems, row);
  }

  Future<void> insertContentItemsBatch(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    for (final row in rows) {
      await _safeUpsert(_db, DatabaseConstants.tableContentItems, row);
    }
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
