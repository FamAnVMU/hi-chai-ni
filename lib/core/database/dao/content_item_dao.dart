import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'dao_utils.dart';

class ContentItemDao {
  final DatabaseExecutor _db;

  const ContentItemDao(this._db);

  Map<String, dynamic> _normalizedRow(Map<String, dynamic> row) {
    final rawCid = row['content_id'];
    if (rawCid is String && rawCid != rawCid.trim()) {
      final copy = Map<String, dynamic>.from(row);
      copy['content_id'] = rawCid.trim();
      return copy;
    }
    return row;
  }

  Future<void> insertContentItem(Map<String, dynamic> row) async {
    await DaoUtils.safeUpsert(
      _db,
      DatabaseConstants.tableContentItems,
      _normalizedRow(row),
      conflictKey: 'content_id',
      preservePrimaryKey: true,
    );
  }

  Future<void> insertContentItemsBatch(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;

    Future<void> executeBatch(DatabaseExecutor executor) async {
      final batch = executor.batch();
      for (final rawRow in rows) {
        final row = _normalizedRow(rawRow);
        if (row.isEmpty) continue;
        final cols = row.keys.toList();
        final colNames = cols.join(', ');
        final placeholders = List.filled(cols.length, '?').join(', ');
        final args = cols.map((k) => row[k]).toList();
        final updatableCols = cols
            .where((k) => k != 'id' && k != 'content_id' && k != 'created_at')
            .toList();
        final conflictClause = updatableCols.isEmpty
            ? 'ON CONFLICT(content_id) DO NOTHING'
            : 'ON CONFLICT(content_id) DO UPDATE SET ${updatableCols.map((k) => '$k = excluded.$k').join(', ')}';
        batch.rawInsert(
          'INSERT INTO ${DatabaseConstants.tableContentItems} ($colNames) VALUES ($placeholders) $conflictClause',
          args,
        );
      }
      await batch.commit(noResult: true);
    }

    final db = _db;
    if (db is Database) {
      await db.transaction((txn) => executeBatch(txn));
    } else {
      await executeBatch(db);
    }
  }

  Future<Map<String, dynamic>?> getContentItemByContentId(String contentId) async {
    final results = await _db.query(
      DatabaseConstants.tableContentItems,
      where: 'content_id = ?',
      whereArgs: [contentId.trim()],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getContentItemsByLevelAndType(
    int hskLevel,
    String knowledgeType,
  ) async {
    return _db.query(
      DatabaseConstants.tableContentItems,
      where: 'hsk_level = ? AND knowledge_type = ?',
      whereArgs: [hskLevel, knowledgeType],
      orderBy: 'title ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getContentItemsByIds(List<String> contentIds) async {
    if (contentIds.isEmpty) return [];
    final results = <Map<String, dynamic>>[];
    for (final chunk in DaoUtils.chunkList(contentIds)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db.query(
        DatabaseConstants.tableContentItems,
        where: 'content_id IN ($placeholders)',
        whereArgs: chunk,
      );
      results.addAll(rows);
    }
    return results;
  }
}
