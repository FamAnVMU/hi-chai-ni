import 'package:sqflite/sqflite.dart';

abstract class Migration {
  int get version;
  String get description;

  Future<void> up(DatabaseExecutor db);
}
