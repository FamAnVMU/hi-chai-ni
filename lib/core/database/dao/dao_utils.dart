import 'package:sqflite/sqflite.dart';

class DaoUtils {
  DaoUtils._();

  static const int maxInClauseChunkSize = 500;

  static String escapeLikePattern(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  static Iterable<List<T>> chunkList<T>(
    List<T> items, {
    int chunkSize = maxInClauseChunkSize,
  }) sync* {
    if (items.isEmpty) return;
    final effectiveSize = chunkSize > 0 ? chunkSize : maxInClauseChunkSize;
    for (int i = 0; i < items.length; i += effectiveSize) {
      final end = (i + effectiveSize < items.length) ? i + effectiveSize : items.length;
      yield items.sublist(i, end);
    }
  }

  /// Non-destructive upsert that checks existence and runs UPDATE instead of DELETE+INSERT,
  /// preventing accidental ON DELETE CASCADE wipes on child tables.
  static Future<void> safeUpsert(
    DatabaseExecutor executor,
    String table,
    Map<String, dynamic> row, {
    String conflictKey = 'id',
    bool preservePrimaryKey = false,
  }) async {
    final keyVal = row[conflictKey];
    if (keyVal != null) {
      final columnsToFetch = preservePrimaryKey && conflictKey != 'id'
          ? ['id', conflictKey]
          : [conflictKey];
      final existing = await executor.query(
        table,
        columns: columnsToFetch,
        where: '$conflictKey = ?',
        whereArgs: [keyVal],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final updatedRow = Map<String, dynamic>.from(row);
        if (preservePrimaryKey && conflictKey != 'id') {
          updatedRow['id'] = existing.first['id'];
        }
        await executor.update(
          table,
          updatedRow,
          where: '$conflictKey = ?',
          whereArgs: [keyVal],
        );
        return;
      }
    }
    await executor.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
