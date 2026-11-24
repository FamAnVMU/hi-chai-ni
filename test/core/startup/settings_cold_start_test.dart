import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/features/settings/presentation/providers/settings_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Settings Cold-Start & Persistence Tests', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('settings_cold_start_');
      dbPath = '${tempDir.path}/cold_settings.db';
    });

    tearDown(() async {
      if (AppDatabase.instance.isOpen) {
        await AppDatabase.instance.close();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('AppSettingsNotifier handles cold start gracefully and persists across ProviderContainers', () async {
      expect(AppDatabase.instance.isOpen, isFalse);

      // Simulate cold start before DB opens: creating ProviderContainer and reading appSettingsProvider does NOT freeze or throw StateError
      final preOpenContainer = ProviderContainer();
      final initialSettings = preOpenContainer.read(appSettingsProvider);
      expect(initialSettings.themeMode, ThemeMode.light);
      preOpenContainer.dispose();

      // Open SQLite DB and persist theme/font settings
      final db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );

      final container1 = ProviderContainer();
      await container1.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.dark);
      await container1.read(appSettingsProvider.notifier).setFontScale(1.15);
      container1.dispose();

      final savedTheme = await db.query(
        DatabaseConstants.tableAppSettings,
        where: 'key = ?',
        whereArgs: ['theme_mode'],
      );
      expect(savedTheme.first['value'], equals('dark'));

      // Reopen DB connection and create a brand-new ProviderContainer
      await AppDatabase.instance.close();
      await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      await container2.read(appSettingsProvider.notifier).reloadSettings();

      final loaded = container2.read(appSettingsProvider);
      expect(loaded.themeMode, ThemeMode.dark);
      expect(loaded.fontScale, closeTo(1.15, 0.001));
    });
  });
}
