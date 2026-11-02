import 'package:sqflite/sqflite.dart';
import '../../content_packs/data/content_pack_manager.dart';
import '../domain/models/content_pack_models.dart';

/// Legacy-compatible loader for content packs that delegates all operations
/// to the normalized, transaction-safe ContentPackManager.
class ContentPackLoader {
  final ContentPackManager _manager;

  ContentPackLoader(DatabaseExecutor db) : _manager = ContentPackManager(db);

  static String computeChecksum(String rawJson) {
    return ContentPackManager.computeChecksum(rawJson);
  }

  Future<ContentPackInstallResult> loadPackFromJson(String rawJson) async {
    return _manager.installOrUpdatePack(rawJson, isBundled: true);
  }
}
