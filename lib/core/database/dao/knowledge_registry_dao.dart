import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'dao_utils.dart';

class KnowledgeRegistryDao {
  final DatabaseExecutor _db;

  const KnowledgeRegistryDao(this._db);

  DatabaseExecutor _getExecutor(DatabaseExecutor? custom) => custom ?? _db;

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
    await DaoUtils.safeUpsert(exec, DatabaseConstants.tableKnowledgeRegistry, row);
  }

  Future<void> upsertKnowledgeItemsBatch(
    List<Map<String, dynamic>> rows, {
    DatabaseExecutor? executor,
  }) async {
    if (rows.isEmpty) return;
    final exec = _getExecutor(executor);

    Future<void> executeBatch(DatabaseExecutor target) async {
      final batch = target.batch();
      for (final row in rows) {
        if (row.isEmpty) continue;
        final cols = row.keys.toList();
        final colNames = cols.join(', ');
        final placeholders = List.filled(cols.length, '?').join(', ');
        final args = cols.map((k) => row[k]).toList();
        final updatableCols = cols
            .where((k) =>
                k != 'id' &&
                k != 'entity_type' &&
                k != 'canonical_id' &&
                k != 'created_at')
            .toList();
        final conflictClause = updatableCols.isEmpty
            ? 'ON CONFLICT(entity_type, canonical_id) DO NOTHING'
            : 'ON CONFLICT(entity_type, canonical_id) DO UPDATE SET ${updatableCols.map((k) => '$k = excluded.$k').join(', ')}';
        batch.rawInsert(
          'INSERT INTO ${DatabaseConstants.tableKnowledgeRegistry} ($colNames) VALUES ($placeholders) $conflictClause',
          args,
        );
      }
      await batch.commit(noResult: true);
    }

    if (exec is Database) {
      await exec.transaction((txn) => executeBatch(txn));
    } else {
      await executeBatch(exec);
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
    await DaoUtils.safeUpsert(exec, DatabaseConstants.tableLessonKnowledgeItems, row);
  }

  Future<void> insertLessonKnowledgeItemsBatch(
    List<Map<String, dynamic>> rows, {
    DatabaseExecutor? executor,
  }) async {
    if (rows.isEmpty) return;
    final exec = _getExecutor(executor);

    Future<void> executeBatch(DatabaseExecutor target) async {
      final batch = target.batch();
      for (final row in rows) {
        if (row.isEmpty) continue;
        final cols = row.keys.toList();
        final colNames = cols.join(', ');
        final placeholders = List.filled(cols.length, '?').join(', ');
        final args = cols.map((k) => row[k]).toList();
        final updatableCols = cols.where((k) => k != 'id' && k != 'created_at').toList();
        final conflictClause = updatableCols.isEmpty
            ? 'ON CONFLICT(id) DO NOTHING'
            : 'ON CONFLICT(id) DO UPDATE SET ${updatableCols.map((k) => '$k = excluded.$k').join(', ')}';
        batch.rawInsert(
          'INSERT INTO ${DatabaseConstants.tableLessonKnowledgeItems} ($colNames) VALUES ($placeholders) $conflictClause',
          args,
        );
      }
      await batch.commit(noResult: true);
    }

    if (exec is Database) {
      await exec.transaction((txn) => executeBatch(txn));
    } else {
      await executeBatch(exec);
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
    await DaoUtils.safeUpsert(exec, DatabaseConstants.tableContentIdMappings, row);
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
