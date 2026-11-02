import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class KnowledgeRegistryDao {
  final DatabaseExecutor _db;

  const KnowledgeRegistryDao(this._db);

  DatabaseExecutor _getExecutor(DatabaseExecutor? custom) => custom ?? _db;

  Future<void> upsertKnowledgeItem(
    Map<String, dynamic> row, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    await exec.insert(
      DatabaseConstants.tableKnowledgeRegistry,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertKnowledgeItemsBatch(
    List<Map<String, dynamic>> rows, {
    DatabaseExecutor? executor,
  }) async {
    if (rows.isEmpty) return;
    final exec = _getExecutor(executor);
    final batch = exec.batch();
    for (final row in rows) {
      batch.insert(
        DatabaseConstants.tableKnowledgeRegistry,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
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

  Future<Map<String, dynamic>?> getKnowledgeItemByTypeAndCanonical(
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

  Future<List<Map<String, dynamic>>> getKnowledgeItemsByLevel(
    int hskLevel, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    return exec.query(
      DatabaseConstants.tableKnowledgeRegistry,
      where: 'hsk_level = ? AND is_deprecated = 0',
      whereArgs: [hskLevel],
      orderBy: 'canonical_id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getKnowledgeItemsForLesson(
    String lessonId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    return exec.rawQuery('''
      SELECT kr.*, lki.role, lki.sequence_order, lki.is_mandatory
      FROM ${DatabaseConstants.tableLessonKnowledgeItems} lki
      INNER JOIN ${DatabaseConstants.tableKnowledgeRegistry} kr 
        ON lki.knowledge_item_id = kr.id
      WHERE lki.lesson_id = ?
      ORDER BY lki.sequence_order ASC
    ''', [lessonId]);
  }

  Future<void> insertLessonKnowledgeItem(
    Map<String, dynamic> row, {
    DatabaseExecutor? executor,
  }) async {
    final exec = _getExecutor(executor);
    await exec.insert(
      DatabaseConstants.tableLessonKnowledgeItems,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertLessonKnowledgeItemsBatch(
    List<Map<String, dynamic>> rows, {
    DatabaseExecutor? executor,
  }) async {
    if (rows.isEmpty) return;
    final exec = _getExecutor(executor);
    final batch = exec.batch();
    for (final row in rows) {
      batch.insert(
        DatabaseConstants.tableLessonKnowledgeItems,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
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
    await exec.insert(
      DatabaseConstants.tableContentIdMappings,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      final nextId = rows.first['new_id'] as String?;
      if (nextId == null || nextId == currentId) break;
      currentId = nextId;
      hops++;
    }
    return currentId;
  }
}
