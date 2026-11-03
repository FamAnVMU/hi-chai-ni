import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_backup_helper.dart';
import '../../../../core/database/database_constants.dart';
import '../../domain/models/app_settings.dart';
import '../../../profile/domain/models/user_profile.dart';

class DestructiveActionException implements Exception {
  final String message;
  DestructiveActionException(this.message);
  @override
  String toString() => 'DestructiveActionException: $message';
}

class DataManagementService {
  final Database _db;
  final String _dbPath;

  DataManagementService(this._db, this._dbPath);

  /// Calculates real file sizes on disk for SQLite DB, WAL, and temp directories.
  Future<StorageBreakdown> getStorageBreakdown() async {
    int dbSize = 0;
    int walSize = 0;
    int shmSize = 0;
    int cacheSize = 0;

    try {
      final dbFile = File(_dbPath);
      if (await dbFile.exists()) {
        dbSize = await dbFile.length();
      }

      final walFile = File('$_dbPath-wal');
      if (await walFile.exists()) {
        walSize = await walFile.length();
      }

      final shmFile = File('$_dbPath-shm');
      if (await shmFile.exists()) {
        shmSize = await shmFile.length();
      }

      // Check cache directory if available
      final cacheDir = Directory(p.join(p.dirname(_dbPath), 'cache'));
      if (await cacheDir.exists()) {
        await for (final file in cacheDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            cacheSize += await file.length();
          }
        }
      }
    } catch (e) {
      debugPrint('[DataManagement] Error calculating storage: $e');
    }

    final totalSize = dbSize + walSize + shmSize + cacheSize;
    return StorageBreakdown(
      dbSizeBytes: dbSize,
      walSizeBytes: walSize,
      shmSizeBytes: shmSize,
      audioCacheSizeBytes: cacheSize,
      totalSizeBytes: totalSize,
    );
  }

  /// Runs PRAGMA integrity_check on the current SQLite database.
  Future<List<String>> checkIntegrity() async {
    return await DatabaseBackupHelper.checkIntegrity(_db);
  }

  /// Creates a safe backup file in the backups folder.
  Future<File> createBackup({String? customName}) async {
    final now = DateTime.now().toUtc();
    final timestampStr = '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}_${_twoDigits(now.hour)}${_twoDigits(now.minute)}${_twoDigits(now.second)}';
    final backupFileName = customName ?? 'hi_chinese_backup_$timestampStr.hibak';

    final backupDir = Directory(p.join(p.dirname(_dbPath), 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final destPath = p.join(backupDir.path, backupFileName);
    return await DatabaseBackupHelper.createBackup(
      db: _db,
      dbPath: _dbPath,
      destinationBackupPath: destPath,
    );
  }

  /// Lists all created `.hibak` backup files sorted by creation date descending.
  Future<List<File>> listBackups() async {
    final backupDir = Directory(p.join(p.dirname(_dbPath), 'backups'));
    if (!await backupDir.exists()) {
      return [];
    }

    final files = <File>[];
    await for (final entity in backupDir.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.hibak')) {
        files.add(entity);
      }
    }

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Safely restores database from a backup file with pre-destruction safety snapshot.
  Future<void> restoreBackup(File backupFile) async {
    if (!await backupFile.exists()) {
      throw StateError('File sao lưu không tồn tại: ${backupFile.path}');
    }

    // 1. Pre-destruction safety backup of current database
    try {
      await createBackup(customName: 'pre_restore_safety_snapshot_${DateTime.now().millisecondsSinceEpoch}.hibak');
    } catch (e) {
      debugPrint('[DataManagement] Warning: Could not create pre-restore snapshot: $e');
    }

    // 2. Perform safe WAL checkpoint on active DB and close connection safely
    try {
      await _db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {}

    await AppDatabase.instance.close();

    // 3. Copy backup file directly over the database file
    await backupFile.copy(_dbPath);

    // 4. Remove lingering -wal and -shm files to avoid inconsistencies
    final walFile = File('$_dbPath-wal');
    if (await walFile.exists()) await walFile.delete();
    final shmFile = File('$_dbPath-shm');
    if (await shmFile.exists()) await shmFile.delete();

    // 5. Safely re-open database connection
    await AppDatabase.instance.open();

    debugPrint('[DataManagement] Restore completed from ${backupFile.path}');
  }

  /// Exports personal learner data to portable JSON format.
  Future<String> exportUserDataJson() async {
    final profileRows = await _db.query(DatabaseConstants.tableUserProfiles);
    final goalHistoryRows = await _db.query(DatabaseConstants.tableGoalHistory);
    final savedWordsRows = await _db.query(DatabaseConstants.tableUserSavedWords);
    final dictHistoryRows = await _db.query(DatabaseConstants.tableDictionaryHistory);
    final readingProgressRows = await _db.query(DatabaseConstants.tableReadingProgress);
    final srsRows = await _db.query(DatabaseConstants.tableSrsItems);
    final appSettingsRows = await _db.query(DatabaseConstants.tableAppSettings);

    // Sanitize sensitive credentials (%api_key%, %token%, %secret%, %password%)
    final safeAppSettingsRows = appSettingsRows.where((row) {
      final key = (row['key'] as String? ?? '').toLowerCase();
      return !key.contains('api_key') &&
          !key.contains('token') &&
          !key.contains('secret') &&
          !key.contains('password');
    }).toList();

    final exportMap = {
      'metadata': {
        'app_name': 'HI Chinese',
        'export_version': '1.0',
        'app_version': '1.0.0+1',
        'schema_version': DatabaseConstants.currentDatabaseVersion,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'platform': 'local_standalone',
      },
      'user_profiles': profileRows,
      'goal_history': goalHistoryRows,
      'user_saved_words': savedWordsRows,
      'dictionary_history': dictHistoryRows,
      'reading_progress': readingProgressRows,
      'srs_items': srsRows,
      'app_settings': safeAppSettingsRows,
    };

    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }

  /// Imports personal learner data from JSON string.
  Future<bool> importUserDataJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final metadata = decoded['metadata'] as Map<String, dynamic>?;
      if (metadata == null || metadata['app_name'] != 'HI Chinese') {
        throw FormatException('File JSON không phải dữ liệu xuất từ HI Chinese');
      }

      // Create pre-import snapshot
      await createBackup(customName: 'pre_json_import_snapshot_${DateTime.now().millisecondsSinceEpoch}.hibak');

      await _db.transaction((txn) async {
        if (decoded['user_profiles'] is List) {
          for (final row in decoded['user_profiles'] as List) {
            if (row is Map<String, dynamic>) {
              await txn.insert(
                DatabaseConstants.tableUserProfiles,
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }

        if (decoded['goal_history'] is List) {
          for (final row in decoded['goal_history'] as List) {
            if (row is Map<String, dynamic>) {
              await txn.insert(
                DatabaseConstants.tableGoalHistory,
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }

        if (decoded['user_saved_words'] is List) {
          for (final row in decoded['user_saved_words'] as List) {
            if (row is Map<String, dynamic>) {
              await txn.insert(
                DatabaseConstants.tableUserSavedWords,
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      });

      return true;
    } catch (e) {
      debugPrint('[DataManagement] Import JSON failed: $e');
      return false;
    }
  }

  /// Destructive reset with mandatory confirmation code and automated pre-destruction backup.
  /// IMPORTANT: Only clears local user progress/history. Seeded curriculum & Cloud data are untouched.
  Future<void> clearAllUserData({required String confirmationCode}) async {
    final sanitizedCode = confirmationCode.trim().toUpperCase();
    if (sanitizedCode != 'XOA' && sanitizedCode != 'RESET') {
      throw DestructiveActionException(
        'Mã xác nhận không đúng. Bạn phải nhập "XOA" hoặc "RESET" để thực hiện thao tác này.',
      );
    }

    // 1. Mandatory automated pre-destruction safety snapshot
    try {
      await createBackup(
        customName: 'pre_destruction_safety_snapshot_${DateTime.now().millisecondsSinceEpoch}.hibak',
      );
      debugPrint('[DataManagement] Safety backup created before data clear.');
    } catch (e) {
      debugPrint('[DataManagement] Warning: Pre-destruction backup failed ($e), proceeding cautiously.');
    }

    // 2. Clear user-generated and progress tables in transaction
    await _db.transaction((txn) async {
      await txn.delete(DatabaseConstants.tableChatMessages);
      await txn.delete(DatabaseConstants.tableChatSessions);
      await txn.delete(DatabaseConstants.tablePracticeAttempts);
      await txn.delete(DatabaseConstants.tablePracticeSessions);
      await txn.delete(DatabaseConstants.tableReadingProgress);
      await txn.delete(DatabaseConstants.tableUserSavedWords);
      await txn.delete(DatabaseConstants.tableDictionaryHistory);
      await txn.delete(DatabaseConstants.tableSrsItems);
      await txn.delete(DatabaseConstants.tableLearnerEvidence);
      await txn.delete(DatabaseConstants.tableLearningActivities);
      await txn.delete(DatabaseConstants.tablePlacementTestResponses);
      await txn.delete(DatabaseConstants.tablePlacementTestSessions);
      await txn.delete(DatabaseConstants.tableGrammarProgress);
      await txn.delete(DatabaseConstants.tableLessonProgress);
      await txn.delete(DatabaseConstants.tableRoadmapSnapshots);
      await txn.delete(DatabaseConstants.tableGoalHistory);
      await txn.delete(DatabaseConstants.tableUserProfiles);

      // Re-seed clean fresh default profile
      final cleanProfile = UserProfile.defaultProfile();
      await txn.insert(
        DatabaseConstants.tableUserProfiles,
        cleanProfile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    debugPrint('[DataManagement] All local user progress data cleared successfully. Seeded content & cloud data unaffected.');
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
