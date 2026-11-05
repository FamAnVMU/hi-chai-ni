import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

class MigrationV20 implements Migration {
  const MigrationV20();

  @override
  int get version => 20;

  @override
  String get description => 'Add compound index on reading_passages for graded reading queries';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reading_hsk_composite ON ${DatabaseConstants.tableReadingPassages} (hsk_level, deleted_at, id);',
    );
  }
}
