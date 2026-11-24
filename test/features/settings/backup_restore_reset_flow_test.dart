import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database.dart';
import 'package:hi_chinese/features/profile/domain/models/user_profile.dart';
import 'package:hi_chinese/features/profile/presentation/providers/profile_providers.dart';
import 'package:hi_chinese/features/settings/data/services/data_management_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Backup Security, Restore Validation, Reset & Profile Consolidation Tests', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;
    late DataManagementService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_restore_test_');
      dbPath = '${tempDir.path}/main.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
      service = DataManagementService(db, dbPath);
    });

    tearDown(() async {
      if (AppDatabase.instance.isOpen) {
        await AppDatabase.instance.close();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. createBackup preserves non-secret token settings in live DB and integrity-checks backup copy', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableAppSettings, {
        'key': 'max_tokens_pref',
        'value': '2048',
        'updated_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableAppSettings, {
        'key': 'legacy_api_key',
        'value': 'secret-123',
        'updated_at': nowIso,
      });

      final backupFile = await service.createBackup(customName: 'safe_backup.hibak');
      expect(await backupFile.exists(), isTrue);

      // Live DB must remain untouched
      final liveMaxTokens = await db.query(
        DatabaseConstants.tableAppSettings,
        where: 'key = ?',
        whereArgs: ['max_tokens_pref'],
      );
      expect(liveMaxTokens.first['value'], equals('2048'));

      // Backup copy scrubbed credential keys while preserving max_tokens_pref
      final inspectDb = await databaseFactoryFfi.openDatabase(
        backupFile.path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      final backupSecret = await inspectDb.query(
        DatabaseConstants.tableAppSettings,
        where: 'key = ?',
        whereArgs: ['legacy_api_key'],
      );
      final backupPref = await inspectDb.query(
        DatabaseConstants.tableAppSettings,
        where: 'key = ?',
        whereArgs: ['max_tokens_pref'],
      );
      expect(backupSecret, isEmpty);
      expect(backupPref.first['value'], equals('2048'));
      await inspectDb.close();
    });

    test('2. restoreBackup rejects corrupt header, user_version = 0, and FK violations while preserving live DB', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableUserProfiles, {
        'id': DatabaseConstants.defaultProfileId,
        'display_name': 'Original Learner',
        'start_date': nowIso,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // Case A: Non-SQLite file
      final invalidHeaderFile = File('${tempDir.path}/bad_header.hibak');
      await invalidHeaderFile.writeAsString('NOT_A_SQLITE_FILE');
      await expectLater(service.restoreBackup(invalidHeaderFile), throwsA(isA<StateError>()));

      // Case B: user_version == 0
      final zeroVerPath = '${tempDir.path}/zero_ver.hibak';
      final zeroVerDb = await databaseFactoryFfi.openDatabase(zeroVerPath);
      await zeroVerDb.close();
      await expectLater(service.restoreBackup(File(zeroVerPath)), throwsA(isA<StateError>()));

      // Case C: Foreign key violation inside valid-schema backup
      final fkBadPath = '${tempDir.path}/fk_bad.hibak';
      final engine = MigrationEngine();
      final fkBadDb = await databaseFactoryFfi.openDatabase(
        fkBadPath,
        options: OpenDatabaseOptions(
          version: DatabaseConstants.currentDatabaseVersion,
          onCreate: (d, ver) async => engine.executeMigrations(d, 0, ver),
        ),
      );
      await fkBadDb.execute('PRAGMA foreign_keys = OFF;');
      await fkBadDb.insert(DatabaseConstants.tableUserSavedWords, {
        'id': 'orphan_saved',
        'vocabulary_id': 'NON_EXISTENT_VOCAB',
        'simplified': '爱',
        'pinyin': 'ài',
        'is_favorite': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      await fkBadDb.close();
      await expectLater(service.restoreBackup(File(fkBadPath)), throwsA(isA<StateError>()));

      // Original DB stays open & intact
      final liveProfiles = await service.db.query(DatabaseConstants.tableUserProfiles);
      expect(liveProfiles.first['display_name'], equals('Original Learner'));
    });

    test('3. Valid restoreBackup refreshes reactive appDatabaseProvider so userProfileProvider works immediately', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await db.insert(DatabaseConstants.tableUserProfiles, {
        'id': DatabaseConstants.defaultProfileId,
        'display_name': 'Backup Milestone',
        'start_date': nowIso,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      final profileBefore = await container.read(userProfileProvider.future);
      expect(profileBefore.displayName, equals('Backup Milestone'));

      final backupFile = await service.createBackup(customName: 'reactive_restore.hibak');

      await db.update(
        DatabaseConstants.tableUserProfiles,
        {'display_name': 'Modified After Backup'},
        where: 'id = ?',
        whereArgs: [DatabaseConstants.defaultProfileId],
      );

      await service.restoreBackup(backupFile);

      // Reactive generation bump rebuilds appDatabaseProvider & userProfileProvider without database_closed!
      final profileAfterRestore = await container.read(userProfileProvider.future);
      expect(profileAfterRestore.displayName, equals('Backup Milestone'));
    });

    test('4. clearAllUserData clears mastery_snapshots, progress settings & resets profile to default_learner; importUserDataJson deduplicates profiles', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableMasterySnapshots, {
        'id': 'snap_1',
        'hsk_level': 1,
        'total_items': 10,
        'mastered_items': 5,
        'review_items': 2,
        'accuracy_rate': 0.9,
        'snapshot_date': '2026-11-24',
        'created_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableAppSettings, {
        'key': 'onboarding_completed',
        'value': 'true',
        'updated_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableAppSettings, {
        'key': 'theme_mode',
        'value': 'dark',
        'updated_at': nowIso,
      });

      await service.clearAllUserData(confirmationCode: 'RESET');

      expect(await db.query(DatabaseConstants.tableMasterySnapshots), isEmpty);
      expect(
        await db.query(DatabaseConstants.tableAppSettings, where: 'key = ?', whereArgs: ['onboarding_completed']),
        isEmpty,
      );
      final preservedTheme = await db.query(
        DatabaseConstants.tableAppSettings,
        where: 'key = ?',
        whereArgs: ['theme_mode'],
      );
      expect(preservedTheme.first['value'], equals('dark'));

      final resetProfiles = await db.query(DatabaseConstants.tableUserProfiles);
      expect(resetProfiles.length, equals(1));
      expect(resetProfiles.first['id'], equals(DatabaseConstants.defaultProfileId));

      // importUserDataJson consolidates legacy user_default profile cleanly without duplicates
      final importPayload = jsonEncode({
        'metadata': {'app_name': 'HI Chinese', 'export_version': '1.0'},
        'user_profiles': [
          UserProfile.defaultProfile()
              .copyWith(id: 'user_default', displayName: 'Imported Learner')
              .toMap(),
        ],
      });
      final imported = await service.importUserDataJson(importPayload);
      expect(imported, isTrue);

      final profilesAfterImport = await db.query(DatabaseConstants.tableUserProfiles);
      expect(profilesAfterImport.length, equals(1));
      expect(profilesAfterImport.first['id'], equals(DatabaseConstants.defaultProfileId));
      expect(profilesAfterImport.first['display_name'], equals('Imported Learner'));
    });
  });
}
