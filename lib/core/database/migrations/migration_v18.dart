import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

class MigrationV18 implements Migration {
  const MigrationV18();

  @override
  int get version => 18;

  @override
  String get description => 'Add source column to lesson_progress table to track lesson completion source';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableLessonProgress});');
    final hasSource = tableInfo.any((col) => col['name'] == 'source');
    if (!hasSource) {
      await db.execute(
        'ALTER TABLE ${DatabaseConstants.tableLessonProgress} ADD COLUMN source TEXT;',
      );
    }
  }
}
