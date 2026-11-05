import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

class MigrationV19 implements Migration {
  const MigrationV19();

  @override
  int get version => 19;

  @override
  String get description => 'Add search indexes on dictionary_entries for pinyin and traditional hanzi';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dict_pinyin ON ${DatabaseConstants.tableDictionaryEntries} (pinyin);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dict_traditional ON ${DatabaseConstants.tableDictionaryEntries} (traditional);',
    );
  }
}
