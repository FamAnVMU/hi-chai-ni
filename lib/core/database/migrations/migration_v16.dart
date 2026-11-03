import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

class MigrationV16 implements Migration {
  const MigrationV16();

  @override
  int get version => 16;

  @override
  String get description => 'Add timezone_offset_minutes to learning_activities and compound activity index';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableLearningActivities});');
    final hasCol = tableInfo.any((col) => col['name'] == 'timezone_offset_minutes');
    if (!hasCol) {
      await db.execute(
        'ALTER TABLE ${DatabaseConstants.tableLearningActivities} ADD COLUMN timezone_offset_minutes INTEGER;',
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_learning_activities_date_created ON ${DatabaseConstants.tableLearningActivities} (activity_date, created_at);',
    );
  }
}
