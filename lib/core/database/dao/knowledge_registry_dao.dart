import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class KnowledgeRegistryDao {
  final DatabaseExecutor _db;

  const KnowledgeRegistryDao(this._db);

  DatabaseExecutor _getExecutor(DatabaseExecutor? custom) => custom ?? _db;

  Future<void> _safeUpsert(
    DatabaseExecutor executor,
    String table,
    Map<String, dynamic> row, {
    String primaryKey = 'id',
  }) async {
    final pkVal = row[primaryKey];
    if (pkVal != null) {
      final existing = await executor.query(
        table,
        columns: [primaryKey],
        where: '$primaryKey = ?',
        whereArgs: [pkVal],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await executor.update(
          table,
          row,
          where: '$primaryKey = ?',
          whereArgs: [pkVal],
        );
        return;
      }
    }
    await executor.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> upsertKnowledgeItem(
    Map<String, dynamic> row, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    final entityType = row['entity_type'];
    final canonicalId = row['canonical_id'];
    if (entityType != null && canonicalId != null) {
      final existing = await exec.query(
        DatabaseConstants.tableKnowledgeRegistry,
        columns: ['id'],
        where: 'entity_type = ? AND canonical_id = ?',
        whereArgs: [entityType, canonicalId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final existingId = existing.first['id'];
        final updatedRow = Map<String, dynamic>.from(row);
        updatedRow['id'] = existingId;
        await exec.update(
          DatabaseConstants.tableKnowledgeRegistry,
          updatedRow,
          where: 'id = ?',
          whereArgs: [existingId],
        );
        return;
      }
    }
    await _safeUpsert(exec, DatabaseConstants.tableKnowledgeRegistry, row);
  }

  Future<void> upsertKnowledgeItemsBatch(
    List<Map<String, dynamic>> rows, {
    DatabaseExecutor? executor,
  }) async {
    if (rows.isEmpty) return;
    final exec = _getExecutor(executor);
    for (final row in rows) {
      await upsertKnowledgeItem(row, executor: exec);
    }
  }

  Future<Map<String, dynamic>?> getKnowledgeItemById(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    final results = await exec.query(
      DatabaseConstants.tableKnowledgeRegistry,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getKnowledgeItemByCanonical(
    String entityType,
    String canonicalId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    final results = await exec.query(
      DatabaseConstants.tableKnowledgeRegistry,
      where: 'entity_type = ? AND canonical_id = ?',
      whereArgs: [entityType, canonicalId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getKnowledgeItemsByTypeAndLevel(
    String entityType,
    int hskLevel, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    return exec.query(
      DatabaseConstants.tableKnowledgeRegistry,
      where: 'entity_type = ? AND hsk_level = ? AND is_deprecated = 0',
      whereArgs: [entityType, hskLevel],
      orderBy: 'title ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getKnowledgeItemsForLesson(
    String lessonId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    return exec.rawQuery('''
      SELECT kr.*, lki.role, lki.sequence_order, lki.is_mandatory
      FROM ${DatabaseConstants.tableKnowledgeRegistry} kr
      INNER JOIN ${DatabaseConstants.tableLessonKnowledgeItems} lki 
        ON kr.id = lki.knowledge_item_id
      WHERE lki.lesson_id = ?
      ORDER BY lki.sequence_order ASC
    ''', [lessonId]);
  }

  Future<void> insertLessonKnowledgeItem(
    Map<String, dynamic> row, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    await _safeUpsert(exec, DatabaseConstants.tableLessonKnowledgeItems, row);
  }

  Future<void> insertLessonKnowledgeItemsBatch(
    List<Map<String, dynamic>> rows, {
    DatabaseExecutor? executor,
  }) async {
    if (rows.isEmpty) return;
    final exec = _getExecutor(executor);
    for (final row in rows) {
      await _safeUpsert(exec, DatabaseConstants.tableLessonKnowledgeItems, row);
    }
  }

  Future<void> deprecateKnowledgeItem(
    String id, {
    String? replacedById,
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    final now = DateTime.now().toUtc().toIso8601String();
    await exec.update(
      DatabaseConstants.tableKnowledgeRegistry,
      {
        'is_deprecated': 1,
        'replaced_by_id': replacedById,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertContentIdMapping(
    Map<String, dynamic> row, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    await _safeUpsert(exec, DatabaseConstants.tableContentIdMappings, row);
  }

  /// Resolves the latest active target content ID by following any historical mapping hops.
  Future<String> resolveActiveContentId(
    String contentId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    String currentId = contentId;
    int hops = 0;
    while (hops < 10) {
      final rows = await exec.query(
        DatabaseConstants.tableContentIdMappings,
        columns: ['new_id'],
        where: 'old_id = ?',
        whereArgs: [currentId],
        limit: 1,
      );
      if (rows.isEmpty) break;
      final nextId = rows.first['new_id'] as String;
      if (nextId == currentId) break;
      currentId = nextId;
      hops++;
    }
    return currentId;
  }
}
