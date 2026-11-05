import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

class MigrationV17 implements Migration {
  const MigrationV17();

  @override
  int get version => 17;

  @override
  String get description => 'Add index on learning_activities created_at for dashboard timeline query optimization';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_learning_activities_created_at ON ${DatabaseConstants.tableLearningActivities} (created_at);',
    );
  }
}
